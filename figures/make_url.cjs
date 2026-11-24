'use strict';
// Builds the file:// URL that opens the archived page with a corpus input restored through the page's own
// url-state module (hash = base64 of {"v":1,"data":<textarea text>}).
//   node figures/make_url.cjs <page-root> <corpus-dir> <input-id>
const fs = require('fs'); const path = require('path'); const { pathToFileURL } = require('url');
const [root, corpus, id] = process.argv.slice(2);
const inp = JSON.parse(fs.readFileSync(path.join(corpus, 'inputs.json'), 'utf8')).find(x => x.id === id);
if (!inp) throw new Error('no input ' + id);
const hash = Buffer.from(JSON.stringify({ v: 1, data: inp.text }), 'utf8').toString('base64');
process.stdout.write(pathToFileURL(path.resolve(root, 'p-curve', 'index.html')).href + '#' + hash);
