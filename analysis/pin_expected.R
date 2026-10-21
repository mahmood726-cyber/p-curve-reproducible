# Writes expected/paper_values.json from the archived comparison summaries (run once, when the archive is built).
source("analysis/common.R")
suppressPackageStartupMessages(library(jsonlite))
pv <- list()
for (pg in c("original", "fixed")) {
  s <- fromJSON(file.path("results", paste0("comparison-", pg, "-summary.json")), simplifyVector = FALSE)
  pq <- list(); for (q in s$per_quantity) pq[[q$quantity]] <- list(checks = q$checks, passed = q$passed)
  pv[[pg]] <- list(checks = s$checks, passed = s$passed, per_quantity = pq)
}
pv$known_differences <- nrow(utils::read.csv("expected/known_differences.csv"))
write_json_lf(pv, "expected/paper_values.json")
cat(sprintf("PINNED: original %d/%d, fixed %d/%d, known differences %d\n", pv$original$passed, pv$original$checks,
            pv$fixed$passed, pv$fixed$checks, pv$known_differences))
