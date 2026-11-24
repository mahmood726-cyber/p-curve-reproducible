# Builds the pre-registered corpus (PREREG.md section 4) -> corpus/inputs.json, corpus/configurations.json,
# corpus/dataset-ledger.csv. Deterministic: rebuilding must reproduce the archived files byte for byte.
# Usage (from the archive root): Rscript corpus/build_corpus.R [outdir]
args <- commandArgs(trailingOnly = TRUE)
outdir <- if (length(args)) args[1] else "corpus"
source("analysis/common.R")
suppressPackageStartupMessages({ library(metafor); library(jsonlite); library(puniform) })

fmt17 <- function(x) sprintf("%.17g", x)
inputs <- list(); ledger <- list()
add_input <- function(id, group, source, p, note = "") {
  inputs[[length(inputs) + 1]] <<- list(id = id, group = group, source = source,
                                        text = paste(fmt17(p), collapse = "\n"), n_values = length(p), note = note)
}

## A. puniform examples ---------------------------------------------------------------------------------
data("data.mccall93", package = "puniform")
d <- data.mccall93
z <- atanh(d$ri) * sqrt(d$ni - 3)
dir <- sign(sum(atanh(d$ri) * (d$ni - 3)))
keep <- is.finite(z) & sign(z) == dir
add_input("puniform::data.mccall93", "A", "puniform 0.2.8 data.mccall93 (ri, ni)", 2 * pnorm(-abs(z[keep])))
ledger[[length(ledger) + 1]] <- data.frame(dataset = "puniform::data.mccall93", recipe = "ZCOR(ri, ni)",
  rows = nrow(d), finite = sum(is.finite(z)), direction = dir, entered = sum(keep), significant = sum(2 * pnorm(-abs(z[keep])) < 0.05))

set.seed(123)                                   # exactly as in ?puniform
ni <- 100; sdi <- 1
mi <- rnorm(8, mean = 0.2, sd = sdi / sqrt(ni))
tobs <- mi / (sdi / sqrt(ni))
dir <- sign(sum(tobs)); keep <- sign(tobs) == dir
ptwo <- 2 * pt(-abs(tobs[keep]), df = ni - 1)
add_input("puniform::help-example-t99", "A", "?puniform example: set.seed(123), 8 one-sample means, ni = 100 (t, df = 99)", ptwo)
ledger[[length(ledger) + 1]] <- data.frame(dataset = "puniform::help-example-t99", recipe = "t-values, df = 99",
  rows = 8, finite = 8, direction = dir, entered = sum(keep), significant = sum(ptwo < 0.05))

## B. metadat datasets -----------------------------------------------------------------------------------
md <- function(name) { e <- new.env(); data(list = name, package = "metadat", envir = e); get(name, envir = e) }
recipes <- list(
  dat.assink2016 = function(x) list(yi = x$yi, vi = x$vi, recipe = "yi, vi"),
  dat.bangertdrowns2004 = function(x) list(yi = x$yi, vi = x$vi, recipe = "yi, vi"),
  dat.kalaian1996 = function(x) list(yi = x$yi, vi = x$vi, recipe = "yi, vi"),
  dat.knapp2017 = function(x) list(yi = x$yi, vi = x$vi, recipe = "yi, vi"),
  dat.konstantopoulos2011 = function(x) list(yi = x$yi, vi = x$vi, recipe = "yi, vi"),
  dat.lehmann2018 = function(x) list(yi = x$yi, vi = x$vi, recipe = "yi, vi"),
  dat.michael2013 = function(x) list(yi = x$yi, vi = x$vi, recipe = "yi, vi"),
  dat.raudenbush1985 = function(x) list(yi = x$yi, vi = x$vi, recipe = "yi, vi"),
  dat.tannersmith2016 = function(x) list(yi = x$yi, vi = x$vi, recipe = "yi, vi"),
  dat.bakdash2021 = function(x) list(yi = x$es.z, vi = x$vi.z, recipe = "es.z, vi.z"),
  dat.cohen1981 = function(x) { e <- escalc("ZCOR", ri = ri, ni = ni, data = x); list(yi = e$yi, vi = e$vi, recipe = "ZCOR(ri, ni)") },
  dat.craft2003 = function(x) { e <- escalc("ZCOR", ri = ri, ni = ni, data = x); list(yi = e$yi, vi = e$vi, recipe = "ZCOR(ri, ni)") },
  dat.crede2010 = function(x) { e <- escalc("ZCOR", ri = ri, ni = ni, data = x); list(yi = e$yi, vi = e$vi, recipe = "ZCOR(ri, ni)") },
  dat.mcdaniel1994 = function(x) { e <- escalc("ZCOR", ri = ri, ni = ni, data = x); list(yi = e$yi, vi = e$vi, recipe = "ZCOR(ri, ni)") },
  dat.molloy2014 = function(x) { e <- escalc("ZCOR", ri = ri, ni = ni, data = x); list(yi = e$yi, vi = e$vi, recipe = "ZCOR(ri, ni)") },
  dat.furukawa2003 = function(x) { e <- escalc("SMD", m1i = Me, sd1i = Se, n1i = Ne, m2i = Mc, sd2i = Sc, n2i = Nc, data = x)
                                   list(yi = e$yi, vi = e$vi, recipe = "SMD(e vs c)") },
  dat.bourassa1996 = function(x) { e <- escalc("OR", ai = lh.le, bi = lh.re, ci = rh.le, di = rh.re, data = x)
                                   list(yi = e$yi, vi = e$vi, recipe = "OR(lh.le, lh.re, rh.le, rh.re)") },
  dat.landenberger2005 = function(x) { e <- escalc("OR", ai = n.cbt.non, bi = n.cbt.rec, ci = n.ctrl.non, di = n.ctrl.rec, data = x)
                                       list(yi = e$yi, vi = e$vi, recipe = "OR(n.cbt.non, n.cbt.rec, n.ctrl.non, n.ctrl.rec)") }
)
for (nm in sort(c(names(recipes), "dat.aloe2013"))) {
  x <- md(nm)
  if (nm == "dat.aloe2013") {
    ok <- is.finite(x$tval) & is.finite(x$n) & is.finite(x$preds)
    dir <- sign(sum(x$tval[ok])); keep <- ok & sign(x$tval) == dir
    p <- 2 * pt(-abs(x$tval[keep]), df = x$n[keep] - x$preds[keep] - 1)
    recipe <- "t-values, df = n - preds - 1"; nfin <- sum(ok)
  } else {
    r <- recipes[[nm]](x); yi <- as.numeric(r$yi); vi <- as.numeric(r$vi)
    ok <- is.finite(yi) & is.finite(vi) & vi > 0
    dir <- sign(sum(yi[ok] / vi[ok]) / sum(1 / vi[ok]))
    keep <- ok & sign(yi) == dir
    p <- 2 * pnorm(-abs(yi[keep] / sqrt(vi[keep])))
    recipe <- r$recipe; nfin <- sum(ok)
  }
  add_input(paste0("metadat::", nm), "B", paste0("metadat 1.6-0 ", nm, " (", recipe, ")"), p)
  ledger[[length(ledger) + 1]] <- data.frame(dataset = paste0("metadat::", nm), recipe = recipe, rows = nrow(x),
    finite = nfin, direction = dir, entered = sum(keep), significant = sum(p > 0 & p < 0.05))
}

## C. Edge probes (literal text) -------------------------------------------------------------------------
default_demo <- c("0.001", "0.003", "0.002", "0.008", "0.012", "0.004", "0.006", "0.001", "0.017", "0.005", "0.009", "0.002")
edges <- list(
  E01_no_significant = c("0.2", "0.06", "0.5"),
  E02_one_study = c("0.01"),
  E03_two_studies = c("0.01", "0.02"),
  E04_p_exactly_05_among_others = c("0.05", "0.01", "0.02", "0.03"),
  E05_all_p_05 = c("0.05", "0.05", "0.05"),
  E06_tiny_p = c("1e-300", "1e-20", "1e-10", "0.01"),
  E07_just_below_05 = c("0.0499999", "0.049", "0.04999999999"),
  E08_identical = c("0.01", "0.01", "0.01"),
  E09_half_boundary = c("0.025", "0.0249999", "0.01", "0.002"),
  E10_malformed_tokens = c("0.01", "0.02abc", "0.03,0.04", ".02", "0.004"),
  E11_invalid_numbers = c("0", "-0.01", "1.5", "0.01", "0.02", "0.03"),
  E12_bin_edges = c(".01", ".02", ".03", ".04", ".049"),
  E13_subnormal = c("1e-320", "0.01", "0.02"),
  E14_left_skewed = c("0.041", "0.044", "0.046", "0.048", "0.049"),
  E15_default_demo = default_demo
)
for (nm in names(edges)) inputs[[length(inputs) + 1]] <- list(id = paste0("edge::", nm), group = "C",
  source = "edge probe (PREREG 4C)", text = paste(edges[[nm]], collapse = "\n"), n_values = length(edges[[nm]]), note = "")

## D. Stress grid ----------------------------------------------------------------------------------------
set.seed(20261021)
crit <- qnorm(0.975)
for (k in c(3, 4, 5, 8, 12, 20, 35, 60, 101, 150, 400)) for (sc in c("d0", "d0.5", "d1", "d1.5", "d2", "d3", "d4", "left")) for (rep in 1:5) {
  if (sc == "left") {
    p <- 0.05 * runif(k)^(1 / 3)
  } else {
    delta <- as.numeric(sub("^d", "", sc)); z <- numeric(0)
    while (length(z) < k) { draw <- rnorm(4 * k, delta, 1); z <- c(z, draw[draw > crit]) }
    p <- 2 * pnorm(-z[seq_len(k)])
  }
  add_input(sprintf("grid::k%03d_%s_r%d", k, sc, rep), "D", sprintf("stress grid k = %d, scenario %s, replicate %d", k, sc, rep), p)
}

## Configurations -----------------------------------------------------------------------------------------
configs <- list()
for (inp in inputs) {
  fams <- list(list(family = "z", df = NULL), list(family = "t", df = 10), list(family = "t", df = 30), list(family = "t", df = 100))
  if (inp$id == "puniform::help-example-t99") fams[[length(fams) + 1]] <- list(family = "t", df = 99)
  for (f in fams) configs[[length(configs) + 1]] <- list(
    id = paste0(inp$id, "::", if (f$family == "z") "z" else paste0("t", f$df)), input = inp$id, family = f$family,
    df = if (is.null(f$df)) NA else f$df)
}
dir.create(outdir, showWarnings = FALSE)
write_json_lf(inputs, file.path(outdir, "inputs.json"))
write_json_lf(configs, file.path(outdir, "configurations.json"))
led <- do.call(rbind, ledger)
write_csv_lf(led, file.path(outdir, "dataset-ledger.csv"))
cat(sprintf("CORPUS: inputs=%d (A=%d B=%d C=%d D=%d) configurations=%d\n", length(inputs),
  sum(sapply(inputs, `[[`, "group") == "A"), sum(sapply(inputs, `[[`, "group") == "B"),
  sum(sapply(inputs, `[[`, "group") == "C"), sum(sapply(inputs, `[[`, "group") == "D"), length(configs)))
print(led, row.names = FALSE)
