# R reference for every configuration (PREREG.md section 3).
# Usage (from the archive root): Rscript oracle/reference.R [outfile]
# Reads corpus/inputs.json + corpus/configurations.json; writes results/reference.json (default).
args <- commandArgs(trailingOnly = TRUE)
outfile <- if (length(args)) args[1] else "results/reference.json"
source("analysis/common.R")
suppressPackageStartupMessages({ library(jsonlite); library(puniform) })

inputs <- fromJSON("corpus/inputs.json", simplifyVector = FALSE)
configs <- fromJSON("corpus/configurations.json", simplifyVector = FALSE)
names(inputs) <- vapply(inputs, `[[`, "", "id")

## Input reading rule (PREREG 2): whitespace-separated tokens; a token is a number only if it is a plain decimal
## literal; 0 < p < 0.05 is used.
NUMRE <- "^[+-]?([0-9]+[.]?[0-9]*|[.][0-9]+)([eE][+-]?[0-9]+)?$"
read_p <- function(text) {
  tok <- strsplit(text, "[ \t\r\n]+")[[1]]; tok <- tok[nzchar(tok)]
  ok <- grepl(NUMRE, tok); x <- as.numeric(tok[ok])
  list(n_tokens = length(tok), n_invalid = sum(!ok), used = x[x > 0 & x < 0.05], n_numeric_excluded = sum(!(x > 0 & x < 0.05)))
}

pbound <- function(p) pmin(pmax(p, 2.2e-16), 1 - 2.2e-16)
stouffer <- function(pp) sum(qnorm(pp)) / sqrt(length(pp))

## p-uniform: package default and the tightened-bisection tier (PREREG 3, note 4)
bisect_default <- get("bisect", envir = asNamespace("puniform"))
bisect_tight <- bisect_default; formals(bisect_tight)$tol <- 1e-12
run_puniform <- function(z, tight) {
  f <- if (tight) bisect_tight else bisect_default
  utils::assignInNamespace("bisect", f, ns = "puniform")
  on.exit(utils::assignInNamespace("bisect", bisect_default, ns = "puniform"))
  r <- puniform(yi = z, vi = rep(1, length(z)), alpha = 0.05, side = "right", method = "P", plot = FALSE)
  list(est = r$est, ci_lb = r$ci.lb, ci_ub = r$ci.ub, L0 = r$L.0, pval0 = r$pval.0, ksig = r$ksig)
}
## derivative of the estimating function sum(q_i(d)) at d (vi = 1), used for the Tier-2 tolerance
zcv <- qnorm(0.025, lower.tail = FALSE)
hz <- function(x) exp(dnorm(x, log = TRUE) - pnorm(x, lower.tail = FALSE, log.p = TRUE))
dsumq <- function(z, d) {
  if (!is.finite(d)) return(NA_real_)
  q <- exp(pnorm(z - d, lower.tail = FALSE, log.p = TRUE) - pnorm(zcv - d, lower.tail = FALSE, log.p = TRUE))
  sum(q * (hz(z - d) - hz(zcv - d)))
}
num_or_na <- function(x) if (length(x) == 0 || is.null(x) || is.na(x)) NA_real_ else as.numeric(x)

reference_one <- function(text, family, df) {
  rd <- read_p(text); p <- rd$used; k <- length(p)
  out <- list(n_tokens = rd$n_tokens, n_invalid = rd$n_invalid, n_numeric_excluded = rd$n_numeric_excluded, k = k,
              p_used = p)
  if (k < 3) { out$refused <- TRUE; return(out) }
  out$refused <- FALSE
  ph <- p[p < 0.025]; kh <- length(ph); out$k_half <- kh
  ## Fisher (2014)
  out$fisher_chisq <- -2 * sum(log(p / 0.05)); out$fisher_df <- 2 * k
  out$fisher_p <- pchisq(out$fisher_chisq, 2 * k, lower.tail = FALSE)
  ## Stouffer right skew (app 4.x)
  ppr <- pbound(20 * p); out$pp_skew_full <- ppr
  out$skew_full_z <- stouffer(ppr); out$skew_full_p <- pnorm(out$skew_full_z)
  if (kh > 0) {
    pprh <- pbound(40 * ph); out$pp_skew_half <- pprh
    out$skew_half_z <- stouffer(pprh); out$skew_half_p <- pnorm(out$skew_half_z)
  } else { out$pp_skew_half <- numeric(0); out$skew_half_z <- NA_real_; out$skew_half_p <- NA_real_ }
  ## 33%-power flatness (app 4.x), two-sided rejection probability S under the alternative
  if (family == "z") {
    S2 <- function(x, m) pnorm(x - m, lower.tail = FALSE) + pnorm(-x - m)
    crit <- function(pc) qnorm(pc / 2, lower.tail = FALSE)
  } else {
    S2 <- function(x, m) pt(x, df, ncp = m, lower.tail = FALSE) + pt(-x, df, ncp = m)
    crit <- function(pc) qt(pc / 2, df, lower.tail = FALSE)
  }
  c05 <- crit(0.05); c025 <- crit(0.025)
  ncp <- uniroot(function(m) S2(c05, m) - 1 / 3, c(0, 10), tol = 1e-15, maxiter = 1000)$root
  out$ncp33 <- ncp
  obs <- crit(p)
  pp33 <- pbound(1 - S2(obs, ncp) / S2(c05, ncp)); out$pp_flat_full <- pp33
  out$flat_full_z <- stouffer(pp33); out$flat_full_p <- pnorm(out$flat_full_z)
  if (kh > 0) {
    pp33h <- pbound(1 - S2(crit(ph), ncp) / S2(c025, ncp)); out$pp_flat_half <- pp33h
    out$flat_half_z <- stouffer(pp33h); out$flat_half_p <- pnorm(out$flat_half_z)
  } else { out$pp_flat_half <- numeric(0); out$flat_half_z <- NA_real_; out$flat_half_p <- NA_real_ }
  ## plot (app 4.x)
  ps <- ceiling(p * 100) / 100
  out$plot_observed <- vapply(c(.01, .02, .03, .04, .05), function(b) sum(ps == b) / k * 100, 0)
  g <- vapply(c(.01, .02, .03, .04), function(pc) S2(crit(pc), ncp), 0)
  out$plot_expected33 <- 100 * c(3 * g[1], 3 * (g[2] - g[1]), 3 * (g[3] - g[2]), 3 * (g[4] - g[3]), 3 * (1 / 3 - g[4]))
  ## legacy export fields
  pl <- mean(p / 0.05 <= 0.5); out$prop_low <- pl
  out$z_flat <- (pl - 0.5) / sqrt(0.25 / k); out$p_flat <- 2 * pnorm(-abs(out$z_flat))
  ## p-uniform (z-units)
  z <- qnorm(p / 2, lower.tail = FALSE)
  t1 <- run_puniform(z, tight = TRUE); t2 <- run_puniform(z, tight = FALSE)
  out$pu_ksig <- t1$ksig
  for (nm in c("est", "ci_lb", "ci_ub", "L0", "pval0")) {
    out[[paste0("pu_", nm)]] <- num_or_na(t1[[nm]])
    out[[paste0("pu_default_", nm)]] <- num_or_na(t2[[nm]])
  }
  target <- c(est = k / 2, ci_lb = NA, ci_ub = NA)
  out$pu_dsumq_est <- dsumq(z, num_or_na(t1$est))
  out$pu_dsumq_ci_lb <- dsumq(z, num_or_na(t1$ci_lb))
  out$pu_dsumq_ci_ub <- dsumq(z, num_or_na(t1$ci_ub))
  out
}

t0 <- proc.time()[["elapsed"]]
res <- vector("list", length(configs))
for (i in seq_along(configs)) {
  cf <- configs[[i]]
  df <- if (is.null(cf$df)) NA else cf$df
  r <- reference_one(inputs[[cf$input]]$text, cf$family, df)
  res[[i]] <- c(list(id = cf$id, input = cf$input, family = cf$family, df = df), r)
}
dir.create(dirname(outfile), showWarnings = FALSE, recursive = TRUE)
write_json_lf(list(generated_by = "oracle/reference.R", R = R.version.string,
                   packages = list(puniform = as.character(packageVersion("puniform")),
                                   jsonlite = as.character(packageVersion("jsonlite"))),
                   configurations = res), outfile)
cat(sprintf("REFERENCE: configurations=%d refused=%d seconds=%.1f\n", length(res),
            sum(vapply(res, function(r) isTRUE(r$refused), TRUE)), proc.time()[["elapsed"]] - t0))
