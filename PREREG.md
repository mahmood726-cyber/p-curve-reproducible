# Pre-registration — paper 25: allmeta p-curve / p-uniform page vs R

Written 2026-10-21, before any comparison result existed. Only inventories had been run at this point
(metadat dataset names, `\concept` tags and column names: `work/metadat_inventory.csv`; package versions).
Any later change to this file is listed in the "Amendments" section at the end with its reason and time.

## 1. Object under test

- Page: allmeta `p-curve/index.html` (the single-file app, with the shared scripts it loads).
  - **Original**: allmeta `main` at `1cb3f849c` (release v1.8.0).
  - **Fixed**: the head of branch `f1000/p25-p-curve` (each defect fixed with a failing test first).
- Execution: Node.js (v24) runs the page's own scripts **in document order, exactly as the page loads them**
  (external `<script src>` files and inline scripts), on a linkedom 0.18.12 document. For each configuration the
  harness types the p-values into `#src`, selects the test family/df, clicks `#btn-run` and reads the page's export
  object (`window._almLastPcurve()`) and the rendered result tables. Nothing in the page is modified for testing.

## 2. Input convention (what the page is asked to do)

The page takes significant two-sided p-values (one per line). Entries `0 < p < 0.05` are used; others are excluded.
For p-uniform each used p is converted to z = Φ⁻¹(1 − p/2) and analysed as an effect of z with variance 1, i.e.
the reference is `puniform(yi = z, vi = 1, alpha = 0.05, side = "right", method = "P")` (critical value
Φ⁻¹(0.975)). Studies entered in the corpus are those in the predicted (positive) direction (Section 4).

## 3. Reference (R oracle)

R 4.6.0 (ucrt), lane-local library; versions are printed and checked fail-closed:
puniform 0.2.8, metadat 1.6-0, metafor 5.2-1 (escalc only, to form effect sizes), jsonlite 2.0.0.

| Quantity (page) | Reference |
|---|---|
| k (p < .05), k_half (p < .025) | counts |
| Right skew, Fisher (Simonsohn 2014): χ² = −2 Σ ln(p/0.05), df = 2k, p | base R `pchisq(lower.tail = FALSE)` |
| Right skew, Stouffer (app 4.x): full pp = 20p, half pp = 40p (p < .025); pp bounded to [2.2e-16, 1 − 2.2e-16]; Z = Σ Φ⁻¹(pp)/√k; p = Φ(Z) | base R reimplementation of the p-curve app 4.x formulas |
| 33%-power flatness (app 4.x): ncp giving 1/3 two-sided power at α = .05 (z: normal; t: non-central t at the common df); full pp33 = 1 − S(obs)/S(c.05), half pp33 = 1 − S(obs)/S(c.025) with S the two-sided rejection probability under the 33%-power ncp; bounded as above; Z = Σ Φ⁻¹(pp33)/√k; p = Φ(Z) | base R (`pnorm`, `pt(ncp=)`, `qt`, `uniroot(tol = 1e-15, maxiter = 1000)`) |
| Plot: observed % per bin (ceiling(100p)/100 ∈ {.01,…,.05}, app 4.x binning) and expected % under 33% power (app 4.x "green line": 3·[S(c.01)], 3·[S(c.02) − S(c.01)], …, 3·[1/3 − S(c.04)], ×100) | base R |
| p-uniform: estimate, 95% CI (lower, upper), test of no effect L.0 and one-tailed p | puniform 0.2.8 `puniform()` |
| Legacy export fields (binomial share of pp ≤ .5, z, two-sided p) | base R |

Notes fixed in advance:
1. Where the app 4.x code computes an upper tail as `1 − F(x)`, the reference uses the upper-tail function
   (identical in exact arithmetic, without cancellation), and uses the entered p directly.
2. The half-curve 33%-power pp-value is defined conditionally on p < .025 (Simonsohn, Simmons & Nelson 2015).
   The dmetar port of app 4.052 normalises it differently; that port is used only as a non-gating cross-check
   (Section 7), pinned to dmetar commit 89dbcac19e6e261225703f8a526b10ec6c49e21d.
3. The t family is the non-central t with the single common df entered by the user (app 4.x converts t to F(1, df);
   P(F(1,df,λ) > t²) equals the two-sided non-central t tail with δ = √λ). The reference uses `pt(ncp = δ)`
   (AS 243, errmax 1e-12) rather than `pf(ncp = λ)` (non-central beta, errmax 1e-9); the pf form is a reported,
   non-gating cross-check.
4. **p-uniform tiers.** puniform's bisection stops at tolerance 1e-4 (interval width or |f|).
   - Tier 1 (gating at 1e-9): puniform 0.2.8 with only the default `tol` of its internal `bisect()` changed from
     1e-4 to 1e-12 (via `assignInNamespace`; all other package code unchanged).
   - Tier 2 (gating, own tolerance): puniform 0.2.8 untouched. Tolerance per value: 1e-4 + 1e-4/|f′| + 1e-9, where
     f′ is the derivative of the package's estimating function (Σ q_i − target) at the reference value
     (computed analytically: dq_i/dδ = q_i [h(z_i − δ) − h(z_cv − δ)], h the normal hazard).
   - L.0 and its p-value involve no root: 1e-9 in both tiers.
   - NA (no root in the search interval) must be NA in the page ("—" displayed / null exported).

## 4. Corpus (fixed now)

A. **puniform package examples**: (i) `data.mccall93` (ri, ni → Fisher z, variance 1/(n − 3)); (ii) the
   `puniform()` help example data (set.seed(123); 8 one-sample means, ni = 100, sdi = 1, true mean 0.2) as t-values
   with df = 99, two-sided p = 2·pt(−|t|, 99).
B. **metadat psychology-related datasets**: every metadat 1.6-0 dataset tagged `psychology`, `education`,
   `criminology` or `social work` (26 datasets), except those whose effect measure has no null value
   (proportions, prevalence, reliability coefficients, raw means: dat.bonett2010, dat.debruin2009, dat.demir2022,
   dat.feng2019, dat.mccurdy2020) and arm-level network datasets (dat.hasselblad1998, dat.linde2016).
   That leaves 19 datasets. Per-study effect and variance:
   - yi, vi supplied: dat.assink2016, dat.bangertdrowns2004, dat.kalaian1996, dat.knapp2017,
     dat.konstantopoulos2011, dat.lehmann2018, dat.michael2013, dat.raudenbush1985, dat.tannersmith2016;
     dat.bakdash2021 (es.z, vi.z).
   - ri, ni: dat.cohen1981, dat.craft2003, dat.crede2010, dat.mcdaniel1994, dat.molloy2014 (escalc "ZCOR").
   - means/SDs: dat.furukawa2003 (escalc "SMD", group e vs c).
   - 2×2 counts: dat.bourassa1996 (escalc "OR", ai = lh.le, bi = lh.re, ci = rh.le, di = rh.re);
     dat.landenberger2005 (escalc "OR", ai = n.cbt.non, bi = n.cbt.rec, ci = n.ctrl.non, di = n.ctrl.rec).
   - t-values: dat.aloe2013 (two-sided p = 2·pt(−|tval|, n − preds − 1)).
   Two-sided p = 2Φ(−|yi/√vi|) unless stated. Predicted direction = sign of the fixed-effect estimate
   Σ(yi/vi)/Σ(1/vi) over rows with finite yi, vi (for aloe2013, the sign of Σ tval); only rows in that direction
   are entered. Rows with missing values are not entered. Every row is kept (no truncation); datasets with fewer
   than 3 significant entries become refusal checks.
C. **Edge probes** (exact input text fixed in `corpus/edge_probes.json` when the corpus is built; content fixed here):
   E1 no significant p; E2 one study; E3 two studies; E4 p exactly .05 among others; E5 all p = .05;
   E6 tiny p (1e-300, 1e-20, 1e-10, 0.01); E7 p just below .05 (0.0499999, 0.049, 0.04999999999);
   E8 identical p (0.01 ×3); E9 half-curve boundary (0.025, 0.0249999, 0.01, 0.002); E10 malformed tokens
   (`0.01 0.02abc 0.03,0.04 .02 0.004`: strict reading gives 0.01, .02, 0.004); E11 invalid numbers
   (0, −0.01, 1.5 with 0.01, 0.02, 0.03); E12 bin edges (.01, .02, .03, .04, .049); E13 subnormal
   p = 1e-320 with 0.01, 0.02; E14 strongly left-skewed (0.041, 0.044, 0.046, 0.048, 0.049);
   E15 the page's default demo data.
D. **Stress grid** (synthetic, seed 20261021): k ∈ {3, 4, 5, 8, 12, 20, 35, 60, 101, 150, 400} ×
   scenario ∈ {δ = 0, 0.5, 1, 1.5, 2, 3, 4 (z ~ N(δ, 1) kept when z > Φ⁻¹(.975); p = 2Φ(−z)), left-skew
   (p = 0.05·U^(1/3))} × 5 replicates = 440 sets; p written with 17 significant digits.
Families: every input is run as z; every input is also run as t with df ∈ {10, 30, 100}; the puniform t example
also with df = 99. All configurations are listed in `corpus/configurations.json`.

## 5. Comparison rule

- Numeric: |page − R| / max(1, |R|) ≤ 1e-9, except p-uniform Tier 2 (Section 3, note 4).
- Counts, refusal state (k < 3 → the page refuses and exports nothing), NA-vs-value, and the set of configuration
  IDs: exact. A configuration missing from the page results, or an extra one, is a failure.
- Per-study vectors (right-skew pp full/half, flatness pp33 full/half) are compared element-wise.
- Display: each displayed number must equal the page's own formatting of the exported value (exact text).
- Original vs fixed: both pages run on the same corpus. A quantity the original page does not compute or export
  counts as a failed check for the original.
- The page is not given the reference values; the comparison runs after capture, from saved files.

## 6. Planted defects (each must make the gate FAIL)

P1: one captured page value multiplied by (1 + 1e-8). P2: one configuration deleted from the captured results.
P3: one per-study pp value perturbed by 1e-8 relative. Recorded in `results/plant-*.log`.

## 7. Non-gating cross-checks (reported, never used to pass)

- dmetar `pcurve()` (port of app 4.052, sourced from the pinned commit) on z-family configurations: its output is
  rounded to 3 decimals, so agreement within 5e-4 is reported for right-skew full/half and flatness full; flatness
  half is reported as a known definitional difference.
- t family via `pf(ncp = λ)` (the literal app 4.x form) vs the `pt(ncp = δ)` reference: max difference reported.

## 8. Scope limits declared in advance

Not validated: p-uniform* (the page takes significant p-values only; p-uniform* needs all studies), p-uniform's
publication-bias test (needs non-significant studies and their signs), the binomial tests and power estimate of the
p-curve app, F/χ²/r input families, and effect sizes other than z-units. The page reports δ in z-units.

## Amendments

**A1 (2026-10-21 ~09:00, after the first comparison of the fixed page; post hoc, disclosed).** Under the rule of
Section 5 the fixed page passed 668,117 of 668,205 checks. All 88 differences are 33%-power flatness Z or p values
(87 in t-family configurations, 1 in edge probe E07 under z), in 41 configurations; every per-study pp33 value in
those configurations agrees with R to ≤ 1.7e-14 (absolute). The differences arise because pp33 = 1 − S(obs)/S(crit)
is formed by subtraction in both R and the page; when a pp33 lies very close to 0 or 1, Φ⁻¹(pp33) turns rounding
at the 1e-15 level into Z differences up to ~3e-5. The pre-registered rule is **not** changed and these 88 checks
remain counted as failures. Added, without changing any tolerance:
1. a gating diagnostic for every configuration: the page's flatness Z must equal R's Stouffer combination of the
   page's own pp33 values (1e-9) — so the page's combination step is verified independently of pp33 rounding;
2. `analysis/known_differences.R`, which accepts a difference only if it is a flatness Z/p, all per-study pp33 agree
   to 1e-13, and the difference is within the first-order propagation bound of those pp33 differences; the 88 are
   pinned in `expected/known_differences.csv`. The gate passes only if the failures are exactly that set.
Counts with the diagnostic: 671,887 of 671,975 checks pass; the 88 differences are exactly the pinned set.
**A2 (same time).** "Original vs fixed" is unchanged; the original page is captured with the same harness (its
t-family code takes ~10 h for the corpus).
