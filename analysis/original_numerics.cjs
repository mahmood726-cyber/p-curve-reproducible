'use strict';
// Evaluates the ORIGINAL page's own pnorm, qnorm and non-central t CDF (_pnct) on fixed grids and writes the values;
// analysis/original_numerics.R compares them with R.   node analysis/original_numerics.cjs <out.json>
const fs = require('fs'); const vm = require('vm');
const html = fs.readFileSync('app/original/p-curve/index.html', 'utf8').replace(/\r\n/g, '\n');
const code = html.match(/<script>\s*(function pnorm[\s\S]*?)<\/script>/)[1];
const fns = ['pnorm', 'qnorm', '_lngamma', '_pnct'].map(n => code.match(new RegExp('function ' + n + '\\([\\s\\S]*?\\n    }\\n'))[0]).join('\n');
const ctx = vm.createContext({ Math }); vm.runInContext(fns, ctx);
const x = []; for (let v = -8; v <= 8.0001; v += 0.01) x.push(Math.round(v * 100) / 100);
const p = []; for (let e = -10; e <= -0.30103; e += 0.01) p.push(10 ** e);
const nct = []; for (const df of [10, 30, 100]) for (let t = 0.5; t <= 6.0001; t += 0.25) nct.push({ t, df, ncp: 1.5, v: ctx._pnct(t, df, 1.5) });
fs.writeFileSync(process.argv[2], JSON.stringify({ x, pnorm: x.map(ctx.pnorm), p, qnorm: p.map(ctx.qnorm), nct }) + '\n');
console.log(`ORIGINAL NUMERICS: ${x.length} pnorm, ${p.length} qnorm, ${nct.length} non-central t values`);
