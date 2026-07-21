local assert = assert

-- Drives `prompt.completion` directly with fake sources registered against a
-- disposable target, so these tests do not depend on any real connector or
-- filesystem scan. Every test registers its own target/source names (never
-- reused across tests) so ordering between test functions can't leak state.
local M = {}

local function scratch_buf()
  return vim.api.nvim_create_buf(false, true)
end

local function ctx_for(target, before_cursor, extra)
  local base = {
    bufnr = scratch_buf(),
    target = target,
    before_cursor = before_cursor,
    root = "/tmp",
    cwd = "/tmp",
  }
  return vim.tbl_extend("force", base, extra or {})
end

-- 1. A request issued after an in-flight one supersedes it: the stale
-- request's callback must never fire, even once its own (slower) source
-- eventually finishes.
function M.test_newest_request_wins()
  require("prompt").setup({})
  require("prompt.registry").register_target("race_newest", {
    triggers = { ["@"] = { sources = { "race_newest_src" } } },
  }, { override = true })
  require("prompt.sources").register("race_newest_src", {
    complete = function(ctx, cb)
      local timer = vim.uv.new_timer()
      timer:start(
        ctx._delay,
        0,
        vim.schedule_wrap(function()
          timer:stop()
          timer:close()
          cb({ { label = "item", insert_text = "item", kind = "file" } })
        end)
      )
      return function()
        timer:stop()
        pcall(timer.close, timer)
      end
    end,
  }, { override = true })

  local bufnr = scratch_buf()
  local called_a, called_b = false, false

  require("prompt.completion").complete(
    vim.tbl_extend("force", ctx_for("race_newest", "@q"), { bufnr = bufnr, _delay = 200 }),
    function()
      called_a = true
    end
  )
  require("prompt.completion").complete(
    vim.tbl_extend("force", ctx_for("race_newest", "@q"), { bufnr = bufnr, _delay = 20 }),
    function()
      called_b = true
    end
  )

  assert(
    vim.wait(1000, function()
      return called_b
    end, 10),
    "expected the newer (faster) request to finish"
  )
  -- Give A's 200ms timer plenty of time to have fired too, and confirm it
  -- never reaches the outer callback: `current_request[bufnr]` has already
  -- moved on to B, so A's `finish()` must see itself as stale and drop.
  vim.wait(500, function()
    return called_a
  end, 10)
  assert(not called_a, "stale request A must never invoke its callback")
end

-- 2. A source that never calls back must not block the aggregate result:
-- `completion.source_timeout_ms` forces it to contribute zero items.
function M.test_source_timeout()
  require("prompt").setup({ completion = { source_timeout_ms = 100 } })
  require("prompt.registry").register_target("race_timeout", {
    triggers = { ["@"] = { sources = { "race_timeout_src" } } },
  }, { override = true })
  require("prompt.sources").register("race_timeout_src", {
    complete = function(_, _)
      return nil -- never calls the callback
    end,
  }, { override = true })

  local done, result
  require("prompt.completion").complete(ctx_for("race_timeout", "@q"), function(r)
    done = true
    result = r
  end)

  assert(
    vim.wait(1000, function()
      return done
    end, 10),
    "expected the request to finish once the source timeout fires"
  )
  assert(#result == 0, "expected zero items from a source that never returns")
end

-- 3. A source that calls its callback twice must only be counted once.
function M.test_double_callback_counted_once()
  require("prompt").setup({})
  require("prompt.registry").register_target("race_double", {
    triggers = { ["@"] = { sources = { "race_double_src" } } },
  }, { override = true })
  require("prompt.sources").register("race_double_src", {
    complete = function(_, cb)
      cb({ { label = "first", insert_text = "first", kind = "file" } })
      cb({ { label = "second", insert_text = "second", kind = "file" } })
      return nil
    end,
  }, { override = true })

  local done, result
  require("prompt.completion").complete(ctx_for("race_double", "@fir"), function(r)
    done = true
    result = r
  end)

  assert(
    vim.wait(1000, function()
      return done
    end, 10),
    "expected completion to finish"
  )
  assert(
    #result == 1,
    "expected exactly one item; second callback must be ignored, got " .. #result
  )
  assert(result[1].label == "first", "expected the FIRST callback's items to win")
end

-- 4. A source whose `complete` function throws synchronously must not crash
-- the request; it contributes zero items and other sources still complete.
function M.test_throwing_source_yields_no_items()
  require("prompt").setup({})
  require("prompt.registry").register_target("race_throw", {
    triggers = { ["@"] = { sources = { "race_throw_src", "race_throw_ok" } } },
  }, { override = true })
  require("prompt.sources").register("race_throw_src", {
    complete = function(_, _)
      error("boom")
    end,
  }, { override = true })
  require("prompt.sources").register("race_throw_ok", {
    complete = function(_, cb)
      cb({ { label = "safe", insert_text = "safe", kind = "file" } })
      return nil
    end,
  }, { override = true })

  local done, result
  require("prompt.completion").complete(ctx_for("race_throw", "@saf"), function(r)
    done = true
    result = r
  end)

  assert(
    vim.wait(1000, function()
      return done
    end, 10),
    "expected completion to finish despite one source throwing"
  )
  assert(#result == 1 and result[1].label == "safe", "expected only the well-behaved source's item")
end

-- 5. Malformed items from a source. Items that are well-formed TABLES with
-- optional fields missing are defaulted gracefully (candidate.normalize
-- treats every field as optional). Documents a real gap found while writing
-- this test (reported, not fixed per WP-H scope): a source that hands back a
-- non-table entry (e.g. `true`) makes `candidate.normalize` (lua/prompt/
-- candidate.lua:5, `item.label or ...`) index a non-table value and error.
-- That error happens inside `finish()`, called synchronously from within the
-- per-source `done()` callback, which itself runs inside the aggregator's
-- `xpcall(function() return s.complete(ctx, done) end, ...)`. The xpcall
-- would swallow the error and log it, but `finish()` would never reach its
-- `vim.schedule(function() callback(ranked) end)` call, so the OUTER
-- completion callback would never fire and the request would hang silently.
-- candidate.normalize_all now skips non-table items, so the request instead
-- degrades to "malformed item dropped, rest kept" (see
-- test_non_table_item_is_dropped_not_hung below).
function M.test_malformed_table_items_are_defaulted()
  require("prompt").setup({})
  require("prompt.registry").register_target("race_malformed_ok", {
    triggers = { ["@"] = { sources = { "race_malformed_ok_src" } } },
  }, { override = true })
  require("prompt.sources").register("race_malformed_ok_src", {
    complete = function(_, cb)
      -- A table item missing every optional field but still a table: handled
      -- fine by candidate.normalize's `or` defaults.
      cb({ {} })
      return nil
    end,
  }, { override = true })

  local done, result
  -- Empty query (bare "@"): ranking's fuzzy match short-circuits to a score
  -- of 0 for "", so the defaulted (label="") item isn't filtered out by the
  -- ranker itself; a non-empty query would never match an empty label.
  require("prompt.completion").complete(ctx_for("race_malformed_ok", "@"), function(r)
    done = true
    result = r
  end)

  assert(
    vim.wait(1000, function()
      return done
    end, 10),
    "expected completion to finish for a bare-table malformed item"
  )
  assert(#result == 1, "expected the defaulted item to survive")
  assert(result[1].label == "", "expected label to default to empty string")
  assert(result[1].kind == "file", "expected kind to default to 'file'")
end

-- Regression for the former hang: a non-table item from a source must be
-- dropped by candidate.normalize_all, and the request must still complete
-- (degrade to "malformed item dropped, rest kept") instead of hanging.
function M.test_non_table_item_is_dropped_not_hung()
  require("prompt").setup({})
  require("prompt.registry").register_target("race_malformed_bad", {
    triggers = { ["@"] = { sources = { "race_malformed_bad_src" } } },
  }, { override = true })
  require("prompt.sources").register("race_malformed_bad_src", {
    complete = function(_, cb)
      -- one non-table item plus one valid item: the bad one is skipped, the
      -- good one survives.
      cb({ true, { label = "good", insert_text = "good", kind = "file" } })
      return nil
    end,
  }, { override = true })

  local done, result = false, nil
  require("prompt.completion").complete(ctx_for("race_malformed_bad", "@"), function(r)
    done = true
    result = r
  end)

  assert(
    vim.wait(1000, function()
      return done
    end, 10),
    "request must complete, not hang, when a source returns a non-table item"
  )
  assert(#result == 1, "the non-table item must be dropped and the valid one kept, got " .. #result)
  assert(result[1].label == "good", "the surviving item must be the valid one")
end

-- 6. The buffer going away mid-flight must not error and must not deliver a
-- result for it.
function M.test_buffer_deleted_mid_flight()
  require("prompt").setup({})
  require("prompt.registry").register_target("race_deleted", {
    triggers = { ["@"] = { sources = { "race_deleted_src" } } },
  }, { override = true })
  require("prompt.sources").register("race_deleted_src", {
    complete = function(_, cb)
      vim.defer_fn(function()
        cb({ { label = "late", insert_text = "late", kind = "file" } })
      end, 100)
      return nil
    end,
  }, { override = true })

  local bufnr = scratch_buf()
  local done = false
  local ok = pcall(function()
    require("prompt.completion").complete(
      ctx_for("race_deleted", "@l", { bufnr = bufnr }),
      function()
        done = true
      end
    )
  end)
  assert(ok, "complete() must not error when issuing the request")

  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.wait(300, function()
    return done
  end, 10)
  assert(not done, "a request for a deleted buffer must not deliver a result")
end

-- 7. The cancel function returned by `complete()` must always be callable
-- without error, including while a source's async work is still pending.
function M.test_cancel_is_callable()
  require("prompt").setup({})
  require("prompt.registry").register_target("race_cancel", {
    triggers = { ["@"] = { sources = { "race_cancel_src" } } },
  }, { override = true })
  require("prompt.sources").register("race_cancel_src", {
    complete = function(_, cb)
      local timer = vim.uv.new_timer()
      timer:start(
        500,
        0,
        vim.schedule_wrap(function()
          timer:stop()
          timer:close()
          cb({})
        end)
      )
      return function()
        timer:stop()
        pcall(timer.close, timer)
      end
    end,
  }, { override = true })

  local cancel = require("prompt.completion").complete(ctx_for("race_cancel", "@q"), function() end)
  assert(type(cancel) == "function", "complete() must return a cancel function")
  local ok = pcall(cancel)
  assert(ok, "cancel() must not error")
  -- Idempotent: calling it again must also be safe.
  local ok2 = pcall(cancel)
  assert(ok2, "cancel() must be safe to call twice")
end

return M
