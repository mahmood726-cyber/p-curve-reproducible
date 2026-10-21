# Summarise the non-gating cross-checks: which configurations exceed dmetar's rounding, and why.
# Usage: Rscript analysis/crosscheck_summary.R <reference.json> <crosscheck-prefix>
args <- commandArgs(trailingOnly = TRUE)
source("analysis/common.R")
suppressPackageStartupMessages(library(jsonlite))
ref <- fromJSON(args[1], simplifyVector = FALSE)$configurations; names(ref) <- vapply(ref, `[[`, "", "id")
sink(paste0(args[2], "-summary.txt"), split = TRUE)
dm <- utils::read.csv(paste0(args[2], "-dmetar.csv"), stringsAsFactors = FALSE)
minp <- function(id) min(vapply(ref[[id]]$p_used, as.numeric, 0))
err <- unique(dm$id[dm$quantity == "dmetar_error"])
cat(sprintf("dmetar errors: %d configurations; k range %s; min p range %s\n", length(err),
            paste(range(vapply(err, function(i) ref[[i]]$k, 0)), collapse = "-"), paste(signif(range(vapply(err, minp, 0)), 3), collapse = " to ")))
full <- dm[dm$quantity %in% c("skew_full_z", "skew_full_p", "skew_half_z", "skew_half_p", "flat_full_z", "flat_full_p") & !dm$within_rounding & dm$quantity != "dmetar_error", ]
ids <- unique(full$id)
cat(sprintf("full-curve and right-skew quantities beyond 3-decimal rounding: %d values in %d configurations; smallest p in those configurations: max %.3g\n",
            nrow(full), length(ids), if (length(ids)) max(vapply(ids, minp, 0)) else NA))
if (length(ids)) cat(sprintf("  of these, %d contain a p-value below 2.2e-16 (which the app 4.x code, computing p as 1 - pchisq, cannot represent): %s\n",
                             sum(vapply(ids, minp, 0) < 2.2e-16), paste(ids[vapply(ids, minp, 0) >= 2.2e-16], collapse = ", ")))
rest <- full[!(full$id %in% ids[vapply(ids, minp, 0) < 2.2e-16]), ]
if (nrow(rest)) cat(sprintf("  the remaining %d values exceed half a unit of the 3rd decimal (5e-4) by at most %.2g\n", nrow(rest), max(rest$diff) - 5e-4))
ok <- dm[dm$quantity %in% c("skew_full_z", "skew_full_p", "skew_half_z", "skew_half_p", "flat_full_z", "flat_full_p") & !(dm$id %in% ids) & !is.na(dm$diff), ]
cat(sprintf("in the other %d configurations all %d right-skew and full-flatness values agree within rounding\n", length(unique(ok$id)), nrow(ok)))
h <- dm[dm$quantity %in% c("flat_half_z", "flat_half_p") & !is.na(dm$diff), ]
cat(sprintf("half-curve flatness: %d of %d values within rounding (definitional difference: dmetar divides by 3*P(p<.025) instead of P(p<.025))\n", sum(h$within_rounding), nrow(h)))
pf <- utils::read.csv(paste0(args[2], "-pf.csv"), stringsAsFactors = FALSE)
big <- pf[pf$diff > 1e-6, ]
cat(sprintf("pf literal form: %d of %d t configurations differ by more than 1e-6 (max %.3g); their smallest p: max %.3g; median diff %.3g\n",
            nrow(big), nrow(pf), max(pf$diff), if (nrow(big)) max(vapply(big$id, minp, 0)) else NA, stats::median(pf$diff)))
