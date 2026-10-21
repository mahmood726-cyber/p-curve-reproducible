'use strict';
// Copies p-curve/index.html and every asset it references (script src, stylesheet href, the glossary fetched by
// tooltips.js) from an allmeta checkout into <dest>, keeping the relative layout, and writes
// <dest>/source-manifest.json with SHA-256 of every copied file.
//   node harness/snapshot.cjs <allmeta-dir> <dest> <commit-sha> <note>
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const [src, dest, commit, note = ''] = process.argv.slice(2);
const page = path.join(src, 'p-curve', 'index.html');
const html = fs.readFileSync(page, 'utf8');
const refs = new Set(['p-curve/index.html', 'LICENSE', 'hub/shared/glossary.json']);
for (const m of html.matchAll(/<(?:script[^>]*\ssrc|link[^>]*\shref)="([^"]+)"/g)) {
  const rel = path.relative(src, path.resolve(path.dirname(page), m[1])).split(path.sep).join('/');
  if (!rel.startsWith('..')) refs.add(rel);
}
const files = {};
for (const rel of [...refs].sort()) {
  const from = path.join(src, rel);
  if (!fs.existsSync(from)) { console.error('missing referenced file: ' + rel); process.exit(1); }
  const to = path.join(dest, rel);
  fs.mkdirSync(path.dirname(to), { recursive: true });
  fs.copyFileSync(from, to);
  files[rel] = crypto.createHash('sha256').update(fs.readFileSync(to)).digest('hex');
}
fs.writeFileSync(path.join(dest, 'source-manifest.json'), JSON.stringify({
  repository: 'https://github.com/mahmood726-cyber/allmeta', commit, note, files }, null, 1) + '\n');
console.log(`SNAPSHOT ${dest}: ${Object.keys(files).length} files from ${commit}`);
