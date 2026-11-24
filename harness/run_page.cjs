'use strict';
// Runs the allmeta p-curve page's own scripts, in document order, on a linkedom document, and captures the
// page's export object and rendered tables for every configuration of the corpus.
//   node harness/run_page.cjs <page-root> <corpus-dir> <out.json> [label]
// <page-root> is a directory holding p-curve/index.html and the shared assets it loads (../hub/..., ../shared/...).
// Nothing in the page is modified: inline and external scripts are executed verbatim in one VM context.
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const { parseHTML } = require('linkedom');

// Optional [from] [to]: capture only configurations from..to-1 (0-based) for sharded runs (harness/merge.cjs joins them).
const [pageRoot, corpusDir, outFile, label = '', fromArg, toArg] = process.argv.slice(2);
if (!pageRoot || !corpusDir || !outFile) { console.error('usage: run_page.cjs <page-root> <corpus-dir> <out.json> [label]'); process.exit(2); }
const pagePath = path.join(pageRoot, 'p-curve', 'index.html');
const html = fs.readFileSync(pagePath, 'utf8');
const inputs = JSON.parse(fs.readFileSync(path.join(corpusDir, 'inputs.json'), 'utf8'));
const allConfigs = JSON.parse(fs.readFileSync(path.join(corpusDir, 'configurations.json'), 'utf8'));
const from = fromArg === undefined ? 0 : Number(fromArg), to = toArg === undefined ? allConfigs.length : Math.min(Number(toArg), allConfigs.length);
const configs = allConfigs.slice(from, to);
const byId = new Map(inputs.map(x => [x.id, x]));

function loadPage() {
  const { window, document } = parseHTML(html);
  const scriptErrors = [];
  const consoleErrors = [];
  const store = new Map();
  const storage = {
    getItem: k => (store.has(k) ? store.get(k) : null), setItem: (k, v) => store.set(k, String(v)),
    removeItem: k => store.delete(k), clear: () => store.clear(), key: i => [...store.keys()][i] || null,
    get length() { return store.size; },
  };
  const ctx = {
    window, document, navigator: { userAgent: 'node-linkedom', language: 'en-GB', clipboard: undefined },
    location: { href: 'file:///p-curve/index.html', hash: '', search: '', pathname: '/p-curve/index.html', origin: 'null' },
    history: { replaceState() {}, pushState() {} },
    localStorage: storage, sessionStorage: storage,
    console: { log() {}, info() {}, debug() {}, warn() {}, error: (...a) => consoleErrors.push(a.map(String).join(' ')) },
    setTimeout: (f) => { try { f(); } catch (e) { scriptErrors.push('timeout: ' + e.message); } return 0; },
    clearTimeout() {}, setInterval: () => 0, clearInterval() {},
    requestAnimationFrame: (f) => { try { f(0); } catch (e) { scriptErrors.push('raf: ' + e.message); } return 0; },
    matchMedia: () => ({ matches: false, addListener() {}, removeListener() {}, addEventListener() {}, removeEventListener() {} }),
    getComputedStyle: () => ({ getPropertyValue: () => '' }),
    fetch: () => Promise.reject(new Error('fetch disabled in harness')),
    URL: { createObjectURL: () => 'blob:harness', revokeObjectURL() {} },
    Blob: class { constructor(parts, opts) { this.parts = parts; this.type = opts && opts.type; } },
    Math, JSON, Number, String, Array, Object, Date, Error, TypeError, RangeError, Promise, Map, Set, RegExp,
    parseFloat, parseInt, isFinite, isNaN, encodeURIComponent, decodeURIComponent, Symbol, Infinity, NaN,
  };
  ctx.self = ctx; ctx.globalThis = ctx;
  // window properties seen by page code that uses window.X must be the same objects as the globals
  for (const k of ['localStorage', 'sessionStorage', 'location', 'history', 'navigator', 'matchMedia', 'getComputedStyle', 'fetch', 'requestAnimationFrame', 'setTimeout']) {
    try { window[k] = ctx[k]; } catch (e) { /* read-only in linkedom */ }
  }
  const context = vm.createContext(ctx);
  // make `window` inside the VM be the global object so `window.foo = ...` and bare `foo` agree
  vm.runInContext('window = this; Object.defineProperty(this, "document", { value: document, writable: false });', context);
  const scripts = [...document.querySelectorAll('script')];
  const loaded = [];
  for (const s of scripts) {
    const src = s.getAttribute('src');
    let code, name;
    if (src) {
      const file = path.resolve(path.dirname(pagePath), src);
      name = path.relative(pageRoot, file).split(path.sep).join('/');
      if (!fs.existsSync(file)) { scriptErrors.push('missing script ' + name); continue; }
      code = fs.readFileSync(file, 'utf8');
    } else { code = s.textContent; name = 'inline#' + loaded.length; }
    loaded.push(name);
    try { vm.runInContext(code, context, { filename: name }); }
    catch (e) { scriptErrors.push(name + ': ' + e.message); }
  }
  try { document.dispatchEvent(new window.Event('DOMContentLoaded')); } catch (e) { scriptErrors.push('DOMContentLoaded: ' + e.message); }
  return { window: context, document, scriptErrors, consoleErrors, loaded };
}

function cellText(el) { return el ? el.textContent.replace(/\s+/g, ' ').trim() : ''; }
function captureTables(document) {
  const rows = id => [...document.querySelectorAll('#' + id + ' tr')].map(tr => [...tr.querySelectorAll('td')].map(td => ({
    text: cellText(td), q: td.getAttribute('data-q') || null })));
  return { tests: rows('tests-body'), pu: rows('pu-body'), note: cellText(document.getElementById('input-note')) };
}

const page = loadPage();
const doc = page.document;
const out = { label, page: path.relative(process.cwd(), pagePath).split(path.sep).join('/'), node: process.version,
  scripts_loaded: page.loaded, script_errors: page.scriptErrors, shard: { from, to, of: allConfigs.length }, configurations: [] };
const t0 = Date.now();
// Checkpoint: each captured configuration is appended to <out>.partial.jsonl; a restarted run resumes after the
// last captured configuration (seconds already spent are carried over).
const partial = outFile + '.partial.jsonl';
let carried = 0;
if (fs.existsSync(partial)) {
  for (const line of fs.readFileSync(partial, 'utf8').split('\n')) {
    if (!line.trim()) continue;
    const rec = JSON.parse(line);
    if (rec.seconds_so_far !== undefined) { carried = rec.seconds_so_far; delete rec.seconds_so_far; }
    out.configurations.push(rec);
  }
  console.log(`  ${label}: resuming after ${out.configurations.length} checkpointed configurations`);
}
const done = new Set(out.configurations.map(c => c.id));
for (const cf of configs) {
  if (done.has(cf.id)) continue;
  const inp = byId.get(cf.input);
  const errBefore = page.scriptErrors.length + page.consoleErrors.length;
  doc.getElementById('src').value = inp.text;
  const sel = doc.getElementById('test');
  // linkedom's <select>.value is read-only and follows the selected <option>, as a user selection would
  for (const o of sel.querySelectorAll('option')) { if (o.getAttribute('value') === cf.family) o.setAttribute('selected', ''); else o.removeAttribute('selected'); }
  if (sel.value !== cf.family) throw new Error('could not select family ' + cf.family);
  const dfEl = doc.getElementById('df');
  dfEl.value = cf.family === 't' ? String(cf.df) : '100';
  let runError = null;
  try { doc.getElementById('btn-run').click(); } catch (e) { runError = e.message; }
  let res = null;
  try { res = page.window._almLastPcurve ? page.window._almLastPcurve() : null; } catch (e) { runError = (runError || '') + ' export: ' + e.message; }
  out.configurations.push({ id: cf.id, family: cf.family, df: cf.df, select_value: sel.value, run_error: runError,
    export: res === null || res === undefined ? null : JSON.parse(JSON.stringify(res)),
    tables: captureTables(doc),
    new_errors: page.scriptErrors.slice().concat(page.consoleErrors).slice(errBefore) });
  fs.appendFileSync(partial, JSON.stringify(Object.assign({}, out.configurations[out.configurations.length - 1],
    { seconds_so_far: carried + (Date.now() - t0) / 1000 })) + '\n');
  if (out.configurations.length % 100 === 0) console.log(`  ${label}: ${out.configurations.length}/${configs.length} (${((Date.now() - t0) / 1000).toFixed(0)} s)`);
}
out.seconds = carried + (Date.now() - t0) / 1000;
fs.writeFileSync(outFile, JSON.stringify(out, null, 1) + '\n');
if (fs.existsSync(partial)) fs.renameSync(partial, partial.replace(/\.partial\.jsonl$/, '.checkpoints.jsonl'));
console.log(`CAPTURE ${label}: configurations=${out.configurations.length} script_errors=${page.scriptErrors.length} seconds=${out.seconds}`);
if (page.scriptErrors.length) console.log('  script errors: ' + page.scriptErrors.slice(0, 5).join(' | '));
