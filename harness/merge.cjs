'use strict';
// Joins sharded captures into one capture file; requires contiguous, complete coverage of the corpus in order.
//   node harness/merge.cjs <out.json> <shard1.json> <shard2.json> ...
const fs = require('fs');
const [out, ...parts] = process.argv.slice(2);
const shards = parts.map(f => JSON.parse(fs.readFileSync(f, 'utf8'))).sort((a, b) => a.shard.from - b.shard.from);
let next = 0;
for (const s of shards) {
  if (s.shard.from !== next) throw new Error(`gap or overlap at ${next} (shard starts ${s.shard.from})`);
  if (s.configurations.length !== s.shard.to - s.shard.from) throw new Error('incomplete shard ' + s.shard.from);
  next = s.shard.to;
}
if (next !== shards[0].shard.of) throw new Error(`coverage ends at ${next} of ${shards[0].shard.of}`);
const m = Object.assign({}, shards[0], {
  shard: { from: 0, to: next, of: next, merged_from: shards.map(s => [s.shard.from, s.shard.to]) },
  script_errors: [].concat(...shards.map(s => s.script_errors)),
  seconds: shards.reduce((a, s) => a + s.seconds, 0),
  configurations: [].concat(...shards.map(s => s.configurations)) });
fs.writeFileSync(out, JSON.stringify(m, null, 1) + '\n');
console.log(`MERGED ${shards.length} shards -> ${out}: ${m.configurations.length} configurations, ${m.seconds.toFixed(0)} s total`);
