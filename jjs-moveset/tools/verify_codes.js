#!/usr/bin/env node
// Independent check of character codes using Node's bundled zstd (not the
// Python toolchain): base64 -> zstd -> JSON array -> every DATA string parses,
// every node has a K_NAME, branch maps are objects.
//   node tools/verify_codes.js dist/*.txt
const fs = require('fs');
const zlib = require('zlib');
let failed = 0;
for (const f of process.argv.slice(2)) {
  try {
    const raw = zlib.zstdDecompressSync(Buffer.from(fs.readFileSync(f, 'utf8').trim(), 'base64'));
    const doc = JSON.parse(raw.toString('utf8'));
    if (!Array.isArray(doc) || !doc.length) throw new Error('not a non-empty array');
    let nodes = 0;
    for (const e of doc) {
      if (typeof e.K_NAME !== 'string' || typeof e.DATA !== 'string') throw new Error('bad entry');
      const d = JSON.parse(e.DATA);
      const lines = [d.Line, ...Object.values(d.Branch || {}).map(b => b.Line)];
      for (const line of lines) {
        if (!Array.isArray(line)) throw new Error(`${e.NAME}: Line is not an array`);
        for (const n of line) {
          if (!n || typeof n.K_NAME !== 'string') throw new Error(`${e.NAME}: node without K_NAME`);
          nodes++;
        }
      }
    }
    console.log(`ok   ${f}: ${doc.length} entries, ${nodes} nodes`);
  } catch (err) {
    failed++;
    console.log(`FAIL ${f}: ${err.message}`);
  }
}
process.exit(failed ? 1 : 0);
