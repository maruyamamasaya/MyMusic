const {test} = require('node:test');
const assert = require('node:assert/strict');
const zoom = require('../web/zoom.js');

test('supports the seven documented zoom levels', () => {
  assert.deepEqual(zoom.levels, [75, 80, 90, 100, 110, 125, 150]);
  assert.equal(zoom.normalize('125'), 125);
  assert.equal(zoom.normalize('95'), 100);
});

test('steps between levels and clamps at each boundary', () => {
  assert.equal(zoom.adjacent(100, 1), 110);
  assert.equal(zoom.adjacent(100, -1), 90);
  assert.equal(zoom.adjacent(75, -1), 75);
  assert.equal(zoom.adjacent(150, 1), 150);
});

test('recognizes browser-style Ctrl and macOS Command shortcuts', () => {
  assert.equal(zoom.shortcut({ctrlKey:true,metaKey:false,altKey:false,key:'='}), 'in');
  assert.equal(zoom.shortcut({ctrlKey:false,metaKey:true,altKey:false,key:'-'}), 'out');
  assert.equal(zoom.shortcut({ctrlKey:true,metaKey:false,altKey:false,key:'0'}), 100);
  assert.equal(zoom.shortcut({ctrlKey:false,metaKey:false,altKey:false,key:'+'}), null);
  assert.equal(zoom.shortcut({ctrlKey:true,metaKey:false,altKey:true,key:'+'}), null);
});
