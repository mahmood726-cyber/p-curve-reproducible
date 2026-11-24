# p-curve and p-uniform in the browser: validation against R and puniform

Validated page: the allmeta `p-curve` app — **original** at commit `1cb3f8409c7af75ed41f7e1811f9c502f900fc79`
(release v1.8.0; `app/original/`) and **corrected** at commit `4ea528778afc58e98c6aad5ce416995b79e46af0` on branch
`f1000/p25-p-curve` (`app/fixed/`; not merged upstream at archive build time). Upstream:
https://github.com/mahmood726-cyber/allmeta. Release: allmeta v1.10.0, https://github.com/mahmood726-cyber/allmeta/releases/tag/v1.10.0;
DOI 10.5281/zenodo.24515927. Each `app/*/source-manifest.json` records the SHA-256 of every page asset.

## Scope

**Scope 1 — p-curve** (Simonsohn, Nelson & Simmons 2014; 2015; p-curve app 4.x formulas), for two-sided p-values with
0 < p < .05: Fisher's right-skew test (2014); Stouffer right-skew tests on the full (pp = 20p) and half (pp = 40p,
p < .025) curves; the 33%-power flatness tests (full and half, z or non-central t with one common df), with the
non-centrality and every per-study pp-value; the plot data (observed % per bin with app 4.x binning, expected %
under 33% power). Reference: base R 4.6.0 (`oracle/reference.R`).
**Scope 2 — p-uniform** (van Assen, van Aert & Wicherts 2015): estimate, 95% CI (Irwin–Hall) and test of no effect
for `puniform(yi = z, vi = 1, alpha = .05, side = "right", method = "P")` with z = Φ⁻¹(1 − p/2). Reference: **puniform
0.2.8**, (a) with its internal bisection tolerance tightened from 1e-4 to 1e-12 via `assignInNamespace` (no other
change), compared at 1e-9; (b) unmodified, compared within its own bisection error 1e-4 + 1e-4/|f′|.
Also: counts, refusals (k < 3), unread entries, displayed values, legacy export fields.

**Not validated / not offered** (README and paper limits): p-uniform*, p-uniform's publication-bias test, the p-curve
app's binomial tests and power estimate, F/χ²/r input families, effects other than z-units, dependent results.

## Pre-registration and corpus

`PREREG.md` was written before any comparison (amendment A1 is disclosed there). Corpus (`corpus/build_corpus.R`,
deterministic): the two puniform examples (`data.mccall93`; the `?puniform` t example), 19 metadat 1.6-0 datasets
tagged psychology/education/criminology/social work (`corpus/dataset-ledger.csv`), 15 edge probes and 440 synthetic
stress sets (seed 20261021): **476 inputs**, each as z and as t with df 10/30/100 (+ df 99 for the t example):
**1,905 configurations**, 20 of which must be refused.

## Results

| Page | Checks passing | Notes |
|---|---|---|
| Original (1cb3f84) | 158,791/671,975 | quantities the original does not compute count as failures |
| Corrected (4ea5287) | **671,887/671,975** | the 88 differences are exactly the pinned set `expected/known_differences.csv` |

Tolerance: |page − R|/max(1, |R|) ≤ 1e-9; exact for counts, refusals, configuration set; displayed values within
half a unit of the shown decimal. Largest normalised difference among passing 1e-9 checks: 9.4e-10 (flatness);
outside the flatness statistics 4.0e-13. p-uniform vs tightened puniform: ≤ 4.0e-13.

**The 88 differences (amendment A1).** All are 33%-power flatness Z or p values (41 configurations; 87 t-family, 1 z).
Per-study pp33 values agree with R to ≤ 1.7e-14, but some lie close to 0 or 1, where Φ⁻¹ magnifies rounding of
pp33 = 1 − S(obs)/S(crit), which R and the page both form by subtraction (R's `?TDist`: the non-central t upper tail
"suffers from cancellation"). `analysis/known_differences.R` accepts a difference only if it is a flatness Z/p, the
per-study pp33 agree to 1e-13 and the difference is within the first-order propagation bound; every pinned
difference is at most 0.50 of its bound. The page's Z equals R's Stouffer combination of the page's own pp33 values in
all 3,770 checks (≤ 1.6e-15). These checks remain counted as failures.

**Faults found and fixed** (allmeta commits ac5a4c5 failing test, cf6b92e fix, 4ea5287 UI):
1. Normal CDF/quantile were Abramowitz–Stegun approximations (max errors vs R 7.0e-8 and 4.4e-4); non-central t was
   a Simpson rule (6.4e-8 on the grid in `results/original-numerics.txt`) — now ports of R's algorithms (Cody; AS 241;
   AS 243 with incomplete-beta central t).
2. p-uniform used one-sided z = Φ⁻¹(1 − p) with critical value 1.645 and a damped iteration stopping at 1e-4 — now
   puniform's algorithm with two-sided input (critical value 1.96).
3. Flatness Z had the opposite sign to the p-curve app; pp bound 1e-12 instead of 2.2e-16.
4. `parseFloat` prefix parsing (`0.02abc` → 0.02, `0.03,0.04` → 0.03) — now strict, unread entries listed.
5. Hard-coded expected 33%-power curve — now computed (app 4.x).
6. Stale p-uniform table and plot after a refusal.
Added: Stouffer right-skew tests, p-uniform CI and test of no effect.

**Planted defects** (`analysis/plant.R`): a page value × (1 + 1e-8), one configuration removed, one per-study pp × (1 + 1e-8):
each makes the gate fail.

**Non-gating cross-checks** (`analysis/crosscheck.R`, `analysis/crosscheck_summary.R`; `results/crosscheck-*.csv`,
`results/crosscheck-summary.txt`). (1) dmetar `pcurve()` (port of app 4.052, results rounded to 3 decimals) on the
436 non-refused z configurations: it stopped with an error in 35 (k 3–20); in 425 configurations all 2,550 right-skew
and full-curve flatness values agreed within rounding; of 21 values in 11 configurations that did not, 18 are in
configurations containing p < 2.2e-16 (which app 4.x, computing p as 1 − pchisq, cannot represent) and 3 exceed the
rounding by ≤ 3e-5. Half-curve flatness agreed in only 99 of 872 values: the dmetar port divides by 3·P(p < .025)
where the conditional definition divides by P(p < .025). (2) The literal app 4.x form `3·(pf(t², 1, df, ncp) − 2/3)`
differed from the `pt(ncp)` reference by a median 5.3e-8 in flatness Z (max 3.2) over 1,414 t configurations; R's
non-central F uses the non-central beta with errmax 1e-9.

## Reproduce

Requirements: R 4.6.0 with exactly puniform 0.2.8, metadat 1.6-0, metafor 5.2-1, jsonlite 2.0.0 (stringr 1.6.0 and
poibin 1.6 only for the optional cross-check). Set `R_ENVIRON_USER` to an empty file (`NUL` on Windows) and
`R_LIBS_USER` (or `P25_RLIB`) to the library holding those versions. From the archive root:

```text
Rscript validate.R
```

It prints `.libPaths()` and the versions and refuses any difference; checks the SHA-256 inventory
(`SOURCE_SHA256.json`); rebuilds the corpus byte-identically; refits the R reference for all 1,905 configurations
(no archived value reused) and requires agreement with `results/reference.json` within 1e-12; compares the archived
page captures with the fresh reference, requiring the counts in `expected/paper_values.json` and, for the corrected
page, exactly the pinned differences; and runs the planted defects. A pre-existing `.validate-work/` is refused.

Re-capturing the page (optional, Node.js 24): `cd harness && npm ci`, then from the root
`node harness/run_page.cjs app/fixed corpus <out.json> fixed` (about 2 minutes; the original page took 46,532 s of
capture time in two checkpointed shards, `[from] [to]` arguments, joined by `harness/merge.cjs`, because of its
numerical integration). The harness runs the page's scripts in document order on a linkedom
0.18.12 document (not redistributed). Figure: `figures/capture.ps1` (Edge headless), `figures/totif.py`,
`figures/dump_dom.ps1` + `figures/check_figure.cjs` (`figures/fig1_check.log`, planted `fig1_check-plant.log`).

## Limits

- Page outputs were captured in Node.js on a simulated document; only Figure 1 was rendered in a browser (Microsoft
  Edge 155, headless). Other browsers are untested. `validate.R` re-runs R, not the page.
- The p-curve app 4.06 R source was not available to the lane (no web access); its formulas were implemented from
  the publications and the dmetar port of app 4.052 (pinned commit 89dbcac, `oracle/dmetar-89dbcac/`). The half-curve
  33%-power pp is defined conditionally on p < .025; the dmetar port normalises it differently (see cross-check).
- Inputs are p-values only; corpus p-values for metadat data were derived from effect sizes and variances (z tests),
  so they are a numerical corpus, not reanalyses. Dependent effects in some datasets are treated as independent.
- Only R 4.6.0 with the listed versions was used; other versions are refused.

## Layout

`PREREG.md`; `corpus/` (builder, inputs, configurations, ledger); `oracle/` (R reference; pinned dmetar source);
`app/original`, `app/fixed` (page snapshots, manifests, allmeta licence); `harness/` (Node runner, snapshot tool);
`results/` (reference, captures, comparisons, cross-checks, logs); `expected/` (pinned counts and differences);
`analysis/` (comparison, plants, tables, verifier, versions); `figures/` (capture scripts, Figure 1, checks).
MIT applies to the archive tooling (`LICENSE`).
