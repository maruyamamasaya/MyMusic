const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const source = fs.readFileSync(`${__dirname}/../web/controls.js`, 'utf8');
const match = vm.runInNewContext(`${source}\nmatchOptions`);
test('large sets search every item while limiting rendered options',()=>{
  const options=Array.from({length:2000},(_,i)=>`Artist ${i}`);
  assert.equal(match(options,'').items.length,30);
  assert.equal(match(options,'').total,2000);
  assert.equal(match(options,'1999').items[0],'Artist 1999');
});
test('NFKC, case-insensitive and multiple word matches preserve the original value',()=>{
  assert.equal(match(['ＺＥＬＤＡ & ピアノ'],'zelda ピアノ').items[0],'ＺＥＬＤＡ & ピアノ');
  assert.equal(match(['ZEＬDA'],'no match').total,0);
});
test('exact artist and prefix matches precede collaborations',()=>{
  const result=match(['AZKi × 星街すいせい','星街すいせい × guest','星街すいせい'],'星街すいせい');
  assert.equal(result.items[0],'星街すいせい');
  assert.equal(result.items[1],'星街すいせい × guest');
});
test('punctuation is literal and empty inputs remain bounded',()=>{
  assert.equal(match(['100%_Artist','100 Artist'],'%_').total,1);
  assert.equal(match([],'').total,0);
});
