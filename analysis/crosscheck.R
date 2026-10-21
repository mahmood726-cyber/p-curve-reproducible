# Non-gating cross-checks (PREREG section 7). Never used to pass the gate.
# Usage: Rscript analysis/crosscheck.R <reference.json> <dmetar pcurve2.R> <out-prefix>
# (1) dmetar pcurve() (port of p-curve app 4.052; sourced from the pinned commit) on z-family configurations:
#     its results are rounded to 3 decimals, so agreement within 5e-4 (+1e-9) is reported.
# (2) t family via the literal app 4.x form pf(t^2, 1, df, ncp = delta^2) vs the pt(ncp = delta) reference.
args <- commandArgs(trailingOnly = TRUE)
source("analysis/common.R")
suppressPackageStartupMessages({ library(jsonlite); library(stringr); library(poibin) })
ref <- fromJSON(args[1], simplifyVector = FALSE)$configurations
env <- new.env(); sys.source(args[2], envir = env)
v <- function(x) vapply(x, function(e) if (is.null(e)) NA_real_ else as.numeric(e), 0)
pdf(NULL)
rows <- list()
for (r in ref) {
  if (isTRUE(r$refused) || r$family != "z") next
  p <- v(r$p_used); z <- qnorm(p / 2, lower.tail = FALSE)
  res <- tryCatch(suppressWarnings(capture.output(o <- env$pcurve(data.frame(studlab = seq_along(z), TE = z, seTE = 1)))), error = function(e) NULL)
  if (is.null(res)) { rows[[length(rows) + 1]] <- data.frame(id = r$id, quantity = "dmetar_error", dmetar = NA, reference = NA, diff = NA); next }
  pr <- o$pcurveResults
  get <- c(skew_full_z = pr["Right-skewness test", "zFull"], skew_full_p = pr["Right-skewness test", "pFull"],
           skew_half_z = pr["Right-skewness test", "zHalf"], skew_half_p = pr["Right-skewness test", "pHalf"],
           flat_full_z = pr["Flatness test", "zFull"], flat_full_p = pr["Flatness test", "pFull"],
           flat_half_z = pr["Flatness test", "zHalf"], flat_half_p = pr["Flatness test", "pHalf"])
  for (q in names(get)) {
    R <- if (is.null(r[[q]])) NA_real_ else as.numeric(r[[q]])
    d <- suppressWarnings(as.numeric(get[[q]]))
    rows[[length(rows) + 1]] <- data.frame(id = r$id, quantity = q, dmetar = d, reference = R, diff = abs(d - R))
  }
}
dm <- do.call(rbind, rows)
dm$within_rounding <- !is.na(dm$diff) & dm$diff <= 5e-4 + 1e-9
write_csv_lf(dm, paste0(args[3], "-dmetar.csv"))
sm <- aggregate(cbind(n = 1, within = within_rounding) ~ quantity, data = transform(dm[!is.na(dm$diff), ], within_rounding = as.numeric(within_rounding)), FUN = sum)
sm$max_diff <- tapply(dm$diff, dm$quantity, max, na.rm = TRUE)[sm$quantity]
cat("dmetar (app 4.052 port) vs reference, z family, rounded to 3 decimals:\n"); print(sm, row.names = FALSE)
cat(sprintf("dmetar errors: %d\n", sum(dm$quantity == "dmetar_error")))

## (2) pf literal form for the t family
pf_rows <- list()
for (r in ref) {
  if (isTRUE(r$refused) || r$family != "t") next
  df <- r$df; p <- v(r$p_used); lam <- as.numeric(r$ncp33)^2
  tt <- qt(p / 2, df, lower.tail = FALSE); c05 <- qt(0.025, df, lower.tail = FALSE)
  pp33 <- pmin(pmax(3 * (pf(tt^2, 1, df, ncp = lam) - 2 / 3), 2.2e-16), 1 - 2.2e-16)   # app 4.x literal form
  zf <- sum(qnorm(pp33)) / sqrt(length(pp33))
  pf_rows[[length(pf_rows) + 1]] <- data.frame(id = r$id, flat_full_z_pf = zf, flat_full_z = as.numeric(r$flat_full_z),
                                               power_at_ncp_pf = 1 - pf(c05^2, 1, df, ncp = lam))
}
pfd <- do.call(rbind, pf_rows); pfd$diff <- abs(pfd$flat_full_z_pf - pfd$flat_full_z)
write_csv_lf(pfd, paste0(args[3], "-pf.csv"))
cat(sprintf("pf(ncp) literal form vs pt(ncp) reference, t family: %d configurations; flatness Z max |diff| %.3g (median %.3g); power at ncp33 via pf: %.12f to %.12f\n",
            nrow(pfd), max(pfd$diff), stats::median(pfd$diff), min(pfd$power_at_ncp_pf), max(pfd$power_at_ncp_pf)))
