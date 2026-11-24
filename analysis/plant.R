# Planted defects (PREREG section 6): each must make the gate FAIL.
# Usage: Rscript analysis/plant.R <reference.json> <capture.json> <known.csv> <workdir>
args <- commandArgs(trailingOnly = TRUE)
source("analysis/common.R")
suppressPackageStartupMessages(library(jsonlite))
cap <- fromJSON(args[2], simplifyVector = FALSE)
work <- args[4]; dir.create(work, showWarnings = FALSE, recursive = TRUE)
rs <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
target <- which(vapply(cap$configurations, function(c) !is.null(c$export) && c$id == "metadat::dat.molloy2014::z", TRUE))
stopifnot(length(target) == 1)
plants <- list(
  P1_value_times_1_plus_1e8th = function(x) { e <- x$configurations[[target]]$export; e$pu_est <- e$pu_est * (1 + 1e-8)
                                             x$configurations[[target]]$export <- e; x },
  P2_drop_one_configuration = function(x) { x$configurations[[target]] <- NULL; x },
  P3_perstudy_pp_times_1_plus_1e8th = function(x) { e <- x$configurations[[target]]$export; e$pp_skew_full[[2]] <- e$pp_skew_full[[2]] * (1 + 1e-8)
                                                   x$configurations[[target]]$export <- e; x })
if (length(args) >= 5) sink(args[5], split = TRUE)
ok_all <- TRUE
for (nm in names(plants)) {
  f <- file.path(work, paste0(nm, ".json"))
  writeLines(toJSON(plants[[nm]](cap), auto_unbox = TRUE, digits = I(17), null = "null", na = "null"), f)
  out <- suppressWarnings(system2(rs, c("analysis/compare.R", args[1], f, file.path(work, nm), nm, args[3]), stdout = TRUE, stderr = TRUE))
  st <- attr(out, "status"); st <- if (is.null(st)) 0L else st
  gl <- grep("^GATE|checks pass", out, value = TRUE)
  cat(sprintf("%s: exit status %d -> %s | %s\n", nm, st, if (st != 0) "GATE FAILED as required" else "NOT DETECTED", paste(gl, collapse = " | ")))
  if (st == 0) ok_all <- FALSE
}
cat(if (ok_all) "PLANTS PASS: every planted defect made the gate fail\n" else "PLANTS FAIL: a planted defect was not detected\n")
quit(status = if (ok_all) 0 else 1)
