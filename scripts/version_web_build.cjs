const fs = require('node:fs');
const crypto = require('node:crypto');
const path = require('node:path');
const root = path.resolve(__dirname, '..', 'docs');
const pack = fs.readFileSync(path.join(root, 'index.pck'));
const version = crypto.createHash('sha256').update(pack).digest('hex').slice(0, 12);
const filename = `game-${version}.pck`;
fs.writeFileSync(path.join(root, filename), pack);
const htmlPath = path.join(root, 'index.html');
let html = fs.readFileSync(htmlPath, 'utf8');
html = html.replace(/const GODOT_CONFIG = (.*);/, (_, json) => {
  const config = JSON.parse(json);
  config.mainPack = filename;
  config.fileSizes = { [filename]: pack.length, 'index.wasm': config.fileSizes['index.wasm'] };
  return `const GODOT_CONFIG = ${JSON.stringify(config)};`;
});
html = html.replace(/src="index.js(?:\?[^\"]*)?"/, `src="index.js?v=${version}"`);
fs.writeFileSync(htmlPath, html);
console.log(`Versioned web build: ${filename}`);
