'use strict';
// Figure check: every result cell (data-q) in the DOM rendered by Edge for Figure 1 must equal the R reference
// to the displayed precision (same rule as the display checks), and the plot bar labels must equal R's observed %.
//   node figures/check_figure.cjs <dom.html> <reference.json> <config-id> [--plant]
const fs = require('fs');
const [domFile, refFile, id, plant] = process.argv.slice(2);
let dom = fs.readFileSync(domFile, 'utf8');
const ref = JSON.parse(fs.readFileSync(refFile, 'utf8')).configurations.find(c => c.id === id);
if (plant) dom = dom.replace(/(<td data-q="pu_est">)([^<]*)/, (m, a, b) => a + (Number(b) + 0.001).toFixed(3));
let pass = 0, fail = 0;
const cells = [...dom.matchAll(/<td data-q="([A-Za-z_0-9]+)">([^<]*)<\/td>/g)];
for (const [, q, txt] of cells) {
  const t = txt.replace(/^.*= /, '').trim();
  const R = ref[q];
  let ok;
  if (R === null || R === undefined) ok = (t === '—');
  else { const d = t.includes('.') ? t.split('.')[1].length : 0; ok = Math.abs(Number(t) - R) <= 0.5 * 10 ** -d + 1e-9; }
  if (ok) pass++; else { fail++; console.log(`FAIL ${q}: shown '${t}' R=${R}`); }
}
const bars = [...dom.matchAll(/<text[^>]*>(\d+)%<\/text>/g)].map(m => Number(m[1]));
const want = ref.plot_observed.filter(v => v > 0).map(v => Number(v.toFixed(0)));
if (JSON.stringify(bars) === JSON.stringify(want)) pass++; else { fail++; console.log(`FAIL plot labels ${bars} vs R ${want}`); }
const minCells = 16;
if (cells.length < minCells) { fail++; console.log(`FAIL only ${cells.length} result cells found`); }
const line = `FIGURE CHECKS ${fail ? 'FAIL' : 'PASS'}: ${pass}/${pass + fail} (${id}${plant ? ', planted defect' : ''})`;
console.log(line);
fs.writeFileSync(domFile.replace(/_dom\.html$/, plant ? '_check-plant.log' : '_check.log'), line + '\n');
process.exit(fail ? 1 : 0);
