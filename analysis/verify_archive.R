# Archive verifier: Rscript analysis/verify_archive.R
# Checks the page snapshots against their manifests, release allmeta release and DOI in the metadata, the presence of every
# file the README promises, and that the pinned counts agree with the archived comparison summaries.
source("analysis/common.R")
suppressPackageStartupMessages(library(jsonlite))
fail <- character(0); ok <- 0
chk <- function(cond, msg) { if (isTRUE(cond)) ok <<- ok + 1 else fail <<- c(fail, msg) }
for (pg in c("original", "fixed")) {
  m <- fromJSON(file.path("app", pg, "source-manifest.json"), simplifyVector = FALSE)
  for (f in names(m$files)) chk(identical(unname(tools::sha256sum(file.path("app", pg, f))), m$files[[f]]), paste("hash", pg, f))
  chk(nchar(m$commit) == 40, paste("full commit sha in manifest", pg))
}
chk(grepl("v1.10.0", paste(readLines("CITATION.cff"), collapse = "\n")) && grepl("10.5281/zenodo.24515927", paste(readLines("CITATION.cff"), collapse = "\n")), "CITATION.cff allmeta release and DOI")
z <- paste(readLines(".zenodo.json"), collapse = "\n")
chk(grepl("v1.10.0", z) && grepl("10.5281/zenodo.24515927", z), ".zenodo.json allmeta release and DOI")
chk(!is.null(fromJSON(".zenodo.json")), ".zenodo.json parses")
need <- c("README.md", "PREREG.md", "LICENSE", "validate.R", "corpus/build_corpus.R", "corpus/inputs.json", "corpus/configurations.json",
          "oracle/reference.R", "results/reference.json", "results/app-original.json", "results/app-fixed.json",
          "expected/paper_values.json", "expected/known_differences.csv", "analysis/compare.R", "analysis/plant.R",
          "figures/Figure1.tif", "figures/fig1_check.log", "figures/fig1_check-plant.log", "results/plant.log",
          "results/table1.csv", "results/table2.csv", "results/original-numerics.txt", "results/crosscheck-summary.txt")
for (f in need) chk(file.exists(f), paste("missing", f))
pv <- fromJSON("expected/paper_values.json", simplifyVector = FALSE)
for (pg in c("original", "fixed")) {
  s <- fromJSON(file.path("results", paste0("comparison-", pg, "-summary.json")), simplifyVector = FALSE)
  chk(s$checks == pv[[pg]]$checks && s$passed == pv[[pg]]$passed, paste("archived summary vs paper_values", pg))
}
chk(grepl("PASS", readLines("figures/fig1_check.log")[1]) && grepl("FAIL", readLines("figures/fig1_check-plant.log")[1]), "figure check logs")
cat(sprintf("verify_archive: %d checks, %d failed\n", ok + length(fail), length(fail)))
if (length(fail)) { cat(paste(" -", fail), sep = "\n"); cat("ARCHIVE FAIL\n"); quit(status = 1) }
cat("ARCHIVE PASS\n")
