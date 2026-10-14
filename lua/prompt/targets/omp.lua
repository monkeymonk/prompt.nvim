return {
  name = "omp",
  display_name = "OMP",
  triggers = {
    ["@"] = { sources = { "files", "directories" } },
    ["/"] = { sources = { "omp_commands", "omp_skills", "omp_prompts" } },
  },
}
