# Comparison gate (PREREG.md section 5): page capture vs R reference.
# Usage: Rscript analysis/compare.R <reference.json> <capture.json> <out-prefix> [label]
# Writes <out-prefix>-quantities.csv, <out-prefix>-failures.csv and <out-prefix>-summary.json;
# prints "<label>: N/M checks pass". Exit status 0 iff every check passes.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) stop("usage: compare.R <reference.json> <capture.json> <out-prefix> [label]")
source("analysis/common.R")
suppressPackageStartupMessages(library(jsonlite))
label <- if (length(args) >= 4) args[4] else basename(args[2])
ref <- fromJSON(args[1], simplifyVector = FALSE)$configurations
cap <- fromJSON(args[2], simplifyVector = FALSE)
capc <- cap$configurations

TOL <- 1e-9
num <- function(x) if (is.null(x)) NA_real_ else as.numeric(x)
vec <- function(x) if (is.null(x)) NULL else vapply(x, num, 0)

stats <- new.env()        # quantity -> c(checks, passed, maxdiff)
fails <- list()
record <- function(q, ok, diff, id, detail) {
  s <- if (exists(q, envir = stats, inherits = FALSE)) get(q, envir = stats) else c(0, 0, 0, 0)
  s[1] <- s[1] + 1; s[2] <- s[2] + ok
  if (is.finite(diff)) s[3] <- max(s[3], diff)
  if (ok && is.finite(diff)) s[4] <- max(s[4], diff)
  assign(q, s, envir = stats)
  if (!ok && length(fails) < 100000) fails[[length(fails) + 1]] <<- data.frame(quantity = q, id = id, detail = detail, stringsAsFactors = FALSE)
}
# numeric scalar: both NA -> pass; one NA -> fail; else normalised difference
cmp_num <- function(q, page, R, id, tol = TOL, absolute = FALSE) {
  if (is.na(R) && (is.null(page) || is.na(page))) return(record(q, TRUE, 0, id, ""))
  if (is.na(R) || is.null(page) || is.na(page)) return(record(q, FALSE, Inf, id, sprintf("page=%s R=%s", format(page), format(R))))
  if (!is.finite(R) || !is.finite(page)) return(record(q, identical(page, R), if (identical(page, R)) 0 else Inf, id, sprintf("page=%s R=%s", format(page), format(R))))
  d <- if (absolute) abs(page - R) else abs(page - R) / max(1, abs(R))
  record(q, d <= tol, d, id, sprintf("page=%.17g R=%.17g diff=%.3g tol=%.3g", page, R, d, tol))
}
cmp_vec <- function(q, page, R, id) {
  R <- vec(R); page <- vec(page)
  if (length(R) == 0 && length(page) == 0) return(invisible())
  if (is.null(page) || length(page) != length(R)) {
    for (i in seq_along(R)) record(q, FALSE, Inf, id, sprintf("[%d] page vector missing or length %d vs %d", i, length(page), length(R)))
    return(invisible())
  }
  for (i in seq_along(R)) cmp_num(q, page[i], R[i], paste0(id, "[", i, "]"))
}
cmp_exact <- function(q, page, R, id) record(q, identical(as.numeric(num(page)), as.numeric(num(R))), 0, id, sprintf("page=%s R=%s", format(num(page)), format(num(R))))

# field names in the page export: the fixed page exports the reference names; the original page used older names.
alias <- c(ncp33 = "flat_ncp33", k_half = "flat_half_k", pu_est = "delta_puniform")
getf <- function(ex, nm) {
  if (!is.null(ex[[nm]])) return(ex[[nm]])
  if (!is.null(ex$pu_est) || !(nm %in% names(alias))) return(NULL)   # fixed page: no aliasing
  ex[[alias[[nm]]]]
}
getf_flat_z <- function(ex, nm) {      # original page: flat_*_stouffer_z (opposite sign convention, compared as reported)
  if (!is.null(ex[[nm]])) return(ex[[nm]])
  if (!is.null(ex$pu_est)) return(NULL)
  ex[[sub("_z$", "_stouffer_z", nm)]]
}

## Display: every displayed result must equal R to the shown precision (fixed page: data-q cells; original: labels)
disp_q <- c("k", "fisher_chisq", "fisher_p", "skew_full_z", "skew_full_p", "skew_half_z", "skew_half_p", "flat_full_z",
            "flat_full_p", "flat_half_z", "flat_half_p", "pu_est", "pu_ci_lb", "pu_ci_ub", "pu_L0", "pu_pval0")
label_map <- function(tables) {
  out <- list()
  for (row in tables$tests) {
    if (length(row) < 3) next
    lab <- row[[1]]$text
    for (j in 2:3) if (!is.null(row[[j]]$q)) out[[row[[j]]$q]] <- row[[j]]$text
    if (is.null(row[[2]]$q)) {
      key <- if (grepl("^Right-skew \\(full p-curve\\)", lab)) "fisher" else if (grepl("^Flatness \\(full", lab)) "flat_full" else if (grepl("^Flatness \\(half", lab)) "flat_half" else NA
      if (!is.na(key)) { out[[if (key == "fisher") "fisher_chisq" else paste0(key, "_z")]] <- row[[2]]$text; out[[paste0(key, "_p")]] <- row[[3]]$text }
    }
  }
  for (row in tables$pu) {
    if (length(row) < 2) next
    if (!is.null(row[[2]]$q)) { out[[row[[2]]$q]] <- row[[2]]$text; next }
    lab <- row[[1]]$text
    if (grepl("^Significant p-values used", lab)) out$k <- row[[2]]$text
    if (grepl("^p-uniform effect estimate", lab)) out$pu_est <- row[[2]]$text
  }
  out
}
parse_disp <- function(txt) {
  if (is.null(txt)) return(list(present = FALSE))
  t <- sub("^.*= ", "", txt)
  if (t %in% c("—", "-", "")) return(list(present = TRUE, na = TRUE))
  v <- suppressWarnings(as.numeric(t)); d <- if (grepl("\\.", t)) nchar(sub("^[^.]*\\.", "", t)) else 0
  list(present = TRUE, na = is.na(v), value = v, decimals = d)
}

ref_ids <- vapply(ref, `[[`, "", "id"); cap_ids <- vapply(capc, `[[`, "", "id")
for (x in setdiff(cap_ids, ref_ids)) record("configuration_set", FALSE, Inf, x, "extra configuration in page capture")
dups <- unique(cap_ids[duplicated(cap_ids)])
for (x in dups) record("configuration_set", FALSE, Inf, x, "duplicated configuration in page capture")
names(capc) <- cap_ids
for (r in ref) {
  id <- r$id
  c0 <- capc[[id]]
  if (is.null(c0) || id %in% dups) { record("configuration_set", FALSE, Inf, id, "configuration missing from page capture"); next }
  record("configuration_set", TRUE, 0, id, "")
  ex <- c0$export
  record("run_errors", is.null(c0$run_error) && length(c0$new_errors) == 0, 0, id, paste(c(c0$run_error, unlist(c0$new_errors)), collapse = " | "))
  disp <- label_map(c0$tables)
  if (isTRUE(r$refused)) {
    record("refusal_state", is.null(ex), 0, id, "page exported results for a refused input")
    stale <- names(disp)[vapply(names(disp), function(q) { d <- parse_disp(disp[[q]]); isTRUE(d$present) && !isTRUE(d$na) }, TRUE)]
    record("display_refusal", length(stale) == 0, 0, id, paste("numbers shown after refusal:", paste(stale, collapse = ",")))
    next
  }
  record("refusal_state", !is.null(ex), 0, id, "page refused or exported nothing")
  if (is.null(ex)) ex <- list()
  cmp_exact("k", getf(ex, "k"), r$k, id)
  cmp_exact("k_half", getf(ex, "k_half"), r$k_half, id)
  cmp_exact("n_invalid", getf(ex, "n_invalid"), r$n_invalid, id)
  cmp_vec("p_used", ex$p_values_used, r$p_used, id)
  for (q in c("fisher_chisq", "fisher_p", "skew_full_z", "skew_full_p", "skew_half_z", "skew_half_p", "ncp33",
              "flat_full_p", "flat_half_p", "prop_low", "z_flat", "p_flat"))
    cmp_num(q, num(getf(ex, q)), num(r[[q]]), id)
  for (q in c("flat_full_z", "flat_half_z")) cmp_num(q, num(getf_flat_z(ex, q)), num(r[[q]]), id)
  for (q in c("plot_observed", "plot_expected33", "pp_skew_full", "pp_skew_half", "pp_flat_full", "pp_flat_half"))
    cmp_vec(q, ex[[q]], r[[q]], id)
  # Amendment A1 (diagnostic, gating): the page's flatness Z must equal R's Stouffer combination of the page's OWN
  # pp33 values, i.e. any Z difference from the reference comes from the pp33 values alone.
  for (h in c("full", "half")) {
    ppp <- vec(ex[[paste0("pp_flat_", h)]]); zp <- num(getf_flat_z(ex, paste0("flat_", h, "_z")))
    zr <- if (length(ppp)) sum(qnorm(ppp)) / sqrt(length(ppp)) else NA_real_
    if (is.null(ppp) && !is.na(num(r[[paste0("flat_", h, "_z")]]))) zr <- -Inf     # page exports no pp33: fails
    cmp_num(paste0("flat_", h, "_z_from_page_pp"), zp, zr, id)
  }
  for (q in c("pu_est", "pu_ci_lb", "pu_ci_ub", "pu_L0", "pu_pval0")) cmp_num(q, num(getf(ex, q)), num(r[[q]]), id)
  # Tier 2: puniform 0.2.8 untouched (bisection tol 1e-4)
  pg <- list(est = getf(ex, "pu_est"), ci_lb = ex$pu_ci_lb, ci_ub = ex$pu_ci_ub, L0 = ex$pu_L0, pval0 = ex$pu_pval0)
  for (nm in names(pg)) {
    tol <- if (nm %in% c("L0", "pval0")) TOL else 1e-4 + 1e-4 / abs(num(r[[paste0("pu_dsumq_", nm)]])) + 1e-9
    if (!is.finite(tol)) tol <- 1e-4 + 1e-9
    cmp_num(paste0("pu_default_", nm), num(pg[[nm]]), num(r[[paste0("pu_default_", nm)]]), id, tol = tol, absolute = !(nm %in% c("L0", "pval0")))
  }
  for (q in disp_q) {
    R <- num(if (q == "k") r$k else r[[q]])
    d <- parse_disp(disp[[q]])
    if (is.na(R)) { record("display", !isTRUE(d$present) || isTRUE(d$na), 0, id, paste(q, "shown for NA:", disp[[q]])); next }
    ok <- isTRUE(d$present) && !isTRUE(d$na) && abs(d$value - R) <= 0.5 * 10^(-d$decimals) + 1e-9
    record("display", ok, 0, paste0(id, ":", q), sprintf("%s shown '%s' R=%.10g", q, if (is.null(disp[[q]])) "<absent>" else disp[[q]], R))
  }
}

qs <- sort(ls(stats))
tab <- do.call(rbind, lapply(qs, function(q) { s <- get(q, envir = stats); data.frame(quantity = q, checks = s[1], passed = s[2], max_difference = s[3], max_difference_passed = s[4]) }))
tol_of <- function(q) if (q %in% c("pu_default_est", "pu_default_ci_lb", "pu_default_ci_ub")) "1e-4 + 1e-4/|f'|" else if (q %in% c("k", "k_half", "n_invalid", "configuration_set", "refusal_state", "display_refusal", "run_errors")) "exact" else if (q == "display") "shown precision" else "1e-9"
tab$tolerance <- vapply(tab$quantity, tol_of, "")
write_csv_lf(tab, paste0(args[3], "-quantities.csv"))
fl <- if (length(fails)) do.call(rbind, fails) else data.frame(quantity = character(0), id = character(0), detail = character(0))
write_csv_lf(fl, paste0(args[3], "-failures.csv"))
N <- sum(tab$checks); P <- sum(tab$passed)
final <- sprintf("%s: %d/%d checks pass", label, P, N)
# Optional pinned set of known differences (PREREG amendment A1): the gate passes only if the failures are EXACTLY
# that set (any new failure, or a pinned one that no longer fails, makes it fail).
gate <- P == N; unexpected <- resolved <- character(0)
if (length(args) >= 5) {
  kn <- utils::read.csv(args[5], stringsAsFactors = FALSE)
  key <- function(d) paste(d$quantity, d$id, sep = " @ ")
  unexpected <- setdiff(key(fl), key(kn)); resolved <- setdiff(key(kn), key(fl))
  gate <- length(unexpected) == 0 && length(resolved) == 0
  final <- sprintf("%s (pre-registered rule; the %d differences are exactly the pinned ill-conditioned set: %s)", final, nrow(fl),
                   if (gate) "yes" else "NO")
}
max_pass_1e9 <- max(tab$max_difference_passed[tab$tolerance == "1e-9"])
cat(sprintf("Largest normalised difference among passing 1e-9 checks: %.3g\n", max_pass_1e9))
write_json_lf(list(label = label, checks = N, passed = P, configurations = length(ref), gate_pass = gate,
                   max_normalised_difference_passing_1e9 = max_pass_1e9,
                   unexpected_failures = utils::head(unexpected, 50), resolved_known = utils::head(resolved, 50),
                   per_quantity = tab, final_line = final), paste0(args[3], "-summary.json"))
print(tab, row.names = FALSE)
if (length(unexpected)) cat("UNEXPECTED failures (first 10):\n", paste(utils::head(unexpected, 10), collapse = "\n "), "\n")
if (length(resolved)) cat("Pinned differences that no longer fail (first 10):\n", paste(utils::head(resolved, 10), collapse = "\n "), "\n")
cat(final, "\n", sep = "")
cat(sprintf("GATE %s: %s\n", if (gate) "PASS" else "FAIL", label))
quit(status = if (gate) 0 else 1)
