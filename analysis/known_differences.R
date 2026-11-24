# PREREG amendment A1: characterise and pin the fixed page's differences from R under the pre-registered rule.
# Usage: Rscript analysis/known_differences.R <reference.json> <capture.json> <failures.csv> <out.csv>
# A difference may be pinned only if (i) it is a flatness Z or p, (ii) every per-study pp33 of that curve agrees
# with R to 1e-13 absolute (a few hundred units in the last place of 1), and (iii) the difference is no larger than
# the first-order propagation of those per-study pp33 differences through Z = sum(qnorm(pp33))/sqrt(k)
# (bound B = 2 * sum |dpp_i| / dnorm(qnorm(pp_i)) / sqrt(k); for p, dnorm(Z) * B). Otherwise this script stops.
args <- commandArgs(trailingOnly = TRUE)
source("analysis/common.R")
suppressPackageStartupMessages(library(jsonlite))
ref <- fromJSON(args[1], simplifyVector = FALSE)$configurations; names(ref) <- vapply(ref, `[[`, "", "id")
cap <- fromJSON(args[2], simplifyVector = FALSE)$configurations; names(cap) <- vapply(cap, `[[`, "", "id")
fl <- utils::read.csv(args[3], stringsAsFactors = FALSE)
v <- function(x) vapply(x, function(e) if (is.null(e)) NA_real_ else as.numeric(e), 0)
rows <- list()
for (i in seq_len(nrow(fl))) {
  q <- fl$quantity[i]; id <- fl$id[i]
  if (!grepl("^flat_(full|half)_(z|p)$", q)) stop("unexplained difference (not a flatness Z/p): ", q, " @ ", id)
  h <- sub("^flat_(full|half)_.*$", "\\1", q)
  ppR <- v(ref[[id]][[paste0("pp_flat_", h)]]); ppP <- v(cap[[id]]$export[[paste0("pp_flat_", h)]])
  dmax <- max(abs(ppR - ppP))
  B <- 2 * sum(abs(ppR - ppP) / dnorm(qnorm(ppR))) / sqrt(length(ppR))
  zR <- as.numeric(ref[[id]][[paste0("flat_", h, "_z")]]); zP <- as.numeric(cap[[id]]$export[[paste0("flat_", h, "_z")]])
  pR <- as.numeric(ref[[id]][[paste0("flat_", h, "_p")]]); pP <- as.numeric(cap[[id]]$export[[paste0("flat_", h, "_p")]])
  diff <- if (grepl("_z$", q)) abs(zP - zR) else abs(pP - pR)
  bound <- if (grepl("_z$", q)) B else dnorm(min(abs(zR), abs(zP))) * B
  if (!(dmax <= 1e-13 && diff <= bound)) stop(sprintf("unexplained difference %s @ %s: max pp diff %.3g, diff %.3g, bound %.3g", q, id, dmax, diff, bound))
  rows[[i]] <- data.frame(quantity = q, id = id, max_abs_pp33_difference = dmax,
                          min_pp33_distance_from_0_or_1 = min(pmin(ppR, 1 - ppR)), difference = diff, propagated_bound = bound,
                          stringsAsFactors = FALSE)
}
out <- do.call(rbind, rows)
write_csv_lf(out, args[4])
cat(sprintf("KNOWN DIFFERENCES: %d pinned (%d configurations); per-study pp33 agree to %.2g; every difference within its propagated bound (largest ratio %.2f)\n",
            nrow(out), length(unique(out$id)), max(out$max_abs_pp33_difference), max(out$difference / out$propagated_bound)))
