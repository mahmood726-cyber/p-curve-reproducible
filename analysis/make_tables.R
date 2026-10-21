# Builds the paper's tables from the comparison outputs.
# Usage: Rscript analysis/make_tables.R <comparison-original-quantities.csv> <comparison-fixed-quantities.csv> <outdir>
args <- commandArgs(trailingOnly = TRUE)
source("analysis/common.R")
o <- utils::read.csv(args[1], stringsAsFactors = FALSE); f <- utils::read.csv(args[2], stringsAsFactors = FALSE)
lab <- c(configuration_set = "Configuration set (present, unique)", run_errors = "Script errors", refusal_state = "Refusal state (k < 3)",
  display_refusal = "No stale results after refusal", k = "k (p < .05)", k_half = "k (p < .025)", n_invalid = "Unread entries",
  p_used = "p-values used", fisher_chisq = "Fisher chi-squared", fisher_p = "Fisher p",
  skew_full_z = "Stouffer right skew, full Z", skew_full_p = "Stouffer right skew, full p",
  skew_half_z = "Stouffer right skew, half Z", skew_half_p = "Stouffer right skew, half p",
  pp_skew_full = "Right-skew pp, full (per study)", pp_skew_half = "Right-skew pp, half (per study)",
  ncp33 = "33%-power non-centrality", flat_full_z = "Flatness, full Z", flat_full_p = "Flatness, full p",
  flat_half_z = "Flatness, half Z", flat_half_p = "Flatness, half p",
  pp_flat_full = "Flatness pp33, full (per study)", pp_flat_half = "Flatness pp33, half (per study)",
  flat_full_z_from_page_pp = "Flatness full Z from page pp33 (A1)", flat_half_z_from_page_pp = "Flatness half Z from page pp33 (A1)",
  plot_observed = "Plot: observed %", plot_expected33 = "Plot: expected % (33% power)",
  pu_est = "p-uniform estimate", pu_ci_lb = "p-uniform CI lower", pu_ci_ub = "p-uniform CI upper",
  pu_L0 = "p-uniform L.0", pu_pval0 = "p-uniform p (no effect)",
  pu_default_est = "Estimate vs unmodified puniform", pu_default_ci_lb = "CI lower vs unmodified puniform",
  pu_default_ci_ub = "CI upper vs unmodified puniform", pu_default_L0 = "L.0 vs unmodified puniform",
  pu_default_pval0 = "p (no effect) vs unmodified puniform",
  prop_low = "Legacy: share pp <= .5", z_flat = "Legacy: binomial z", p_flat = "Legacy: binomial p",
  display = "Displayed values")
qs <- names(lab)
stopifnot(setequal(qs, f$quantity), all(o$quantity %in% qs))
row <- function(q) {
  a <- o[o$quantity == q, ]; b <- f[f$quantity == q, ]
  tol <- switch(b$tolerance, "exact" = "0", "1e-9" = "1e-9", "")
  data.frame(quantity = lab[[q]], checks_before = if (nrow(a)) a$checks else 0, passed_before = if (nrow(a)) a$passed else 0,
             checks_after = b$checks, passed_after = b$passed,
             max_difference_before = if (nrow(a) && is.finite(a$max_difference) && b$tolerance == "1e-9") signif(a$max_difference, 3) else "",
             max_difference_after = if (b$tolerance == "1e-9") signif(b$max_difference, 3) else "", tolerance = tol)
}
t1 <- do.call(rbind, lapply(qs, row))
tot <- data.frame(quantity = "TOTAL", checks_before = sum(t1$checks_before), passed_before = sum(t1$passed_before),
                  checks_after = sum(t1$checks_after), passed_after = sum(t1$passed_after),
                  max_difference_before = "", max_difference_after = "", tolerance = "")
t1 <- rbind(t1, tot)
dir.create(args[3], showWarnings = FALSE)
write_csv_lf(t1, file.path(args[3], "table1.csv"))
led <- utils::read.csv("corpus/dataset-ledger.csv", stringsAsFactors = FALSE)
t2 <- data.frame(dataset = sub("^(metadat|puniform)::", "", led$dataset), source = sub("::.*$", "", led$dataset),
                 effect = led$recipe, rows = led$rows, predicted_direction = led$entered, significant = led$significant)
write_csv_lf(t2, file.path(args[3], "table2.csv"))
cat(sprintf("TABLES: table1 %d quantities, before %d/%d, after %d/%d; table2 %d datasets\n", nrow(t1) - 1,
            tot$passed_before, tot$checks_before, tot$passed_after, tot$checks_after, nrow(t2)))
