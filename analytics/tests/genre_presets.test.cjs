const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {
  includesUnassigned, mergeCandidateGenres, moveItem, normalizeText, UNASSIGNED,
} = require('../web/genre-presets.js');

test('name matching ignores case, width and diacritics', () => {
  assert.equal(normalizeText(' ＦóＣＵＳ '), normalizeText('focus'));
});

test('legacy omitted unassigned setting keeps the iPhone legacy behavior', () => {
  assert.equal(includesUnassigned({enabledGenreNames: [], includesUnassignedGenreSetting: null}), true);
  assert.equal(includesUnassigned({enabledGenreNames: [], includesUnassignedGenreSetting: false}), true);
  assert.equal(includesUnassigned({enabledGenreNames: [], includesUnassignedGenreSetting: true}), false);
  assert.equal(includesUnassigned({enabledGenreNames: [UNASSIGNED], includesUnassignedGenreSetting: true}), true);
});

test('editor candidates retain unavailable genres and exclude fixed classifications', () => {
  assert.deepEqual(
    mergeCandidateGenres(['Rock', '作業用BGM', 'ハイレゾ'], ['Missing', UNASSIGNED, 'Rock']),
    ['Missing', 'Rock'],
  );
});

test('reorder helper moves one item without dropping others', () => {
  assert.deepEqual(moveItem(['a', 'b', 'c'], 2, 0), ['c', 'a', 'b']);
  assert.deepEqual(moveItem(['a', 'b'], -1, 0), ['a', 'b']);
});

test('major operations use protected APIs and render inline failures', () => {
  const source = fs.readFileSync(`${__dirname}/../web/genre-presets.js`, 'utf8');
  for (const fragment of [
    "request('/api/genre-presets')",
    "request('/api/genre-presets/genres')",
    "request('/api/genre-presets/order'",
    "request('/api/import'",
    '保存できませんでした:',
    '削除できませんでした:',
    '読み込めませんでした:',
    '並べ替えできませんでした:',
  ]) assert.ok(source.includes(fragment), fragment);
});
