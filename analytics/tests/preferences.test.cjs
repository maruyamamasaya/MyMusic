const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

test('Good and Bad controls adjust one step and clamp to the shared range', () => {
  const source = fs.readFileSync(`${__dirname}/../web/app.js`, 'utf8');
  assert.ok(source.includes('data-adjust="-1"'));
  assert.ok(source.includes('data-adjust="1"'));
  assert.ok(source.includes('Math.max(-10,Math.min(10'));
  assert.ok(source.includes("aria-label=\"Badを1増やす\""));
  assert.ok(source.includes("aria-label=\"Goodを1増やす\""));
  assert.ok(!source.includes('<select class="preference-editor"'));
});
