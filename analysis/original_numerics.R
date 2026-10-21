# Compares the original page's pnorm, qnorm and non-central t CDF with R.
# Usage: Rscript analysis/original_numerics.R <values.json> <out.txt>
args <- commandArgs(trailingOnly = TRUE)
source("analysis/common.R")
v <- jsonlite::fromJSON(args[1])
e1 <- max(abs(v$pnorm - pnorm(v$x)))
e2 <- max(abs(v$qnorm - qnorm(v$p)))
e3 <- max(abs(v$nct$v - pt(v$nct$t, v$nct$df, v$nct$ncp)))
out <- c(sprintf("original pnorm vs R pnorm, x in [-8, 8] step 0.01: max abs error %.3g", e1),
         sprintf("original qnorm vs R qnorm, p in [1e-10, 0.5] (log grid): max abs error %.3g", e2),
         sprintf("original _pnct vs R pt(ncp = 1.5), t 0.5-6, df 10/30/100: max abs error %.3g", e3))
write_lf(out, args[2]); cat(out, sep = "\n")
