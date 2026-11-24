# One-command validation: Rscript validate.R   (run from the archive root)
#  1. refuses unless R 4.6.0 and puniform 0.2.8, metadat 1.6-0, metafor 5.2-1, jsonlite 2.0.0 are installed;
#  2. SHA-256 checks the complete file inventory (SOURCE_SHA256.json);
#  3. rebuilds the pre-registered corpus and requires it to be byte-identical to corpus/;
#  4. refits the R reference for all 1,905 configurations (no archived value is reused) and requires it to agree
#     with the archived results/reference.json within 1e-12 (same NA pattern);
#  5. compares the archived page captures (original page, fixed page) with the FRESH reference and requires the
#     per-quantity counts to equal expected/paper_values.json; the fixed page's differences must be exactly the
#     pinned set in expected/known_differences.csv;
#  6. plants three defects in the fixed-page capture and requires each to make the gate fail.
# Prints "N/M checks pass" lines; any failure exits nonzero. Set R_ENVIRON_USER to an empty file (NUL on Windows)
# and R_LIBS_USER (or P25_RLIB) to the library holding the exact versions. No network access is needed.
start <- proc.time()[["elapsed"]]
source("analysis/common.R")
source("analysis/versions.R")
cat(".libPaths():\n"); print(.libPaths()); cat(R.version.string, "\n")
actual <- installed_versions(); print(actual)
check_versions(actual); cat("Version check PASS\n")
suppressPackageStartupMessages(library(jsonlite))

## 2. inventory
pins <- fromJSON("SOURCE_SHA256.json", simplifyVector = FALSE)
skip <- "^(\\.git|\\.validate-work|\\.plant-work|\\.edge-profile|harness/node_modules)(/|$)|^results/shards/.*\\.(checkpoints|partial)\\.jsonl$|^figures/dump_dom\\.err$"
files <- list.files(".", recursive = TRUE, all.files = TRUE, no.. = TRUE)
files <- files[!grepl(skip, files) & files != "SOURCE_SHA256.json"]
if (!setequal(files, names(pins))) stop("Inventory mismatch: missing ", paste(head(setdiff(names(pins), files), 3), collapse = ", "),
                                        "; extra ", paste(head(setdiff(files, names(pins)), 3), collapse = ", "))
h <- tools::sha256sum(names(pins)); bad <- names(pins)[unname(h) != unlist(pins)]
if (length(bad)) stop("SHA-256 mismatch: ", paste(head(bad, 5), collapse = ", "))
cat(sprintf("SHA-256 inventory PASS: %d files\n", length(pins)))

work <- ".validate-work"
if (file.exists(work)) stop("Existing .validate-work refused (stale-result guard); move it aside first")
dir.create(work)
rs <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
run <- function(...) { st <- system2(rs, c(...)); if (!identical(as.integer(st), 0L)) stop("step failed: ", paste(c(...), collapse = " ")); invisible(TRUE) }

## 3. corpus rebuild
run("corpus/build_corpus.R", file.path(work, "corpus"))
for (f in c("inputs.json", "configurations.json", "dataset-ledger.csv"))
  if (unname(tools::sha256sum(file.path(work, "corpus", f))) != unname(tools::sha256sum(file.path("corpus", f))))
    stop("Rebuilt corpus differs: ", f)
cat("Corpus rebuild PASS: byte-identical (3 files)\n")

## 4. fresh reference
fresh <- file.path(work, "reference.json")
run("oracle/reference.R", fresh)
A <- fromJSON("results/reference.json", simplifyVector = FALSE)$configurations
B <- fromJSON(fresh, simplifyVector = FALSE)$configurations
if (length(A) != length(B)) stop("reference size differs")
flat <- function(x) { u <- unlist(lapply(x, function(e) if (is.null(e)) NA else e)); u }
worst <- 0
for (i in seq_along(A)) {
  for (nm in union(names(A[[i]]), names(B[[i]]))) {
    a <- A[[i]][[nm]]; b <- B[[i]][[nm]]
    if (is.character(a) || is.character(b)) { if (!identical(a, b)) stop("reference differs: ", A[[i]]$id, " ", nm); next }
    a <- suppressWarnings(as.numeric(flat(a))); b <- suppressWarnings(as.numeric(flat(b)))
    if (length(a) != length(b) || !identical(is.na(a), is.na(b))) stop("reference NA/length pattern differs: ", A[[i]]$id, " ", nm)
    ok <- !is.na(a); if (any(ok)) worst <- max(worst, abs(a[ok] - b[ok]) / pmax(1, abs(b[ok])))
  }
}
if (worst > 1e-12) stop(sprintf("fresh reference differs from archived by %.3g", worst))
cat(sprintf("Fresh R reference PASS: %d configurations, max normalised difference from archived %.3g\n", length(B), worst))

## 5. comparisons against the fresh reference
expected <- fromJSON("expected/paper_values.json", simplifyVector = FALSE)
lines <- character(0)
for (pg in c("original", "fixed")) {
  args <- c("analysis/compare.R", fresh, file.path("results", paste0("app-", pg, ".json")), file.path(work, paste0("comparison-", pg)), pg)
  if (pg == "fixed") args <- c(args, "expected/known_differences.csv")
  st <- system2(rs, args)
  s <- fromJSON(file.path(work, paste0("comparison-", pg, "-summary.json")), simplifyVector = FALSE)
  e <- expected[[pg]]
  if (pg == "fixed" && !identical(as.integer(st), 0L)) stop("fixed-page gate failed")
  if (s$checks != e$checks || s$passed != e$passed) stop(sprintf("%s: %d/%d differs from expected %d/%d", pg, s$passed, s$checks, e$passed, e$checks))
  q <- s$per_quantity; names(q) <- vapply(q, `[[`, "", "quantity")
  for (nm in names(e$per_quantity)) if (q[[nm]]$checks != e$per_quantity[[nm]]$checks || q[[nm]]$passed != e$per_quantity[[nm]]$passed)
    stop(sprintf("%s %s: %d/%d differs from expected", pg, nm, q[[nm]]$passed, q[[nm]]$checks))
  lines <- c(lines, paste0(s$final_line, " - matches expected/paper_values.json"))
}

## 6. planted defects
run("analysis/plant.R", fresh, "results/app-fixed.json", "expected/known_differences.csv", file.path(work, "plants"))

cat(sprintf("Runtime: %.1f seconds\n", proc.time()[["elapsed"]] - start))
cat(lines, sep = "\n"); cat("\n")
cat("VALIDATION PASS\n")
