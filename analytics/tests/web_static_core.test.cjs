const test = require('node:test');
const assert = require('node:assert/strict');
const core = require('../web-static/core.js');

const event = (overrides={}) => ({ eventId:'e1', trackId:'t1', trackTitle:'Song', artist:'Artist', album:null, playedAt:'2026-09-02T12:00:00Z', playDuration:20, trackDuration:180, completed:false, skipped:true, playSource:'library', selectionType:'manual', platform:'iOS', schemaVersion:1, ...overrides });

test('adapts existing exports and aggregates without persistence', () => {
  const data=core.createData();
  core.merge(data,core.parseDocument({version:1,tracks:[{trackID:'t1',title:'Song',artist:'Artist',duration:180}]},'library.json'));
  core.merge(data,core.parseDocument({schemaVersion:1,exportedAt:'2026-09-02T00:00:00Z',events:[event()]},'events.json'));
  core.merge(data,core.parseDocument({schemaVersion:2,exportedAt:'2026-09-02T00:00:00Z',tracks:[{trackId:'t1',playbackPreference:2,favorite:true}]},'preferences.json'));
  const normalized=core.normalize(data), result=core.aggregate(normalized);
  assert.equal(normalized.tracks[0].preference.favorite,true);
  assert.equal(result.total.playCount,1); assert.equal(result.total.early,1); assert.equal(result.total.skipRate,1);
});

test('deduplicates playback events by eventId', () => {
  const data=core.createData(), document={schemaVersion:1,exportedAt:'2026-09-02T00:00:00Z',events:[event()]};
  core.merge(data,core.parseDocument(document,'a.json')); core.merge(data,core.parseDocument(document,'b.json'));
  assert.equal(data.playEvents.length,1);
});

test('rejects malformed JSON contracts with user-facing errors', () => {
  assert.throws(()=>core.parseDocument({schemaVersion:9,events:[]}),/未対応バージョン/);
  assert.throws(()=>core.parseDocument({version:1,tracks:[{title:'Missing ID'}]}),/trackID/);
  assert.throws(()=>core.parseDocument({hello:'world'}),/必須データ/);
});

test('filters dates on JST boundaries and excludes legacy detail metrics', () => {
  const data=core.createData();
  const doc={schemaVersion:1,exportedAt:'2026-09-02T00:00:00Z',events:[event({eventId:'old',playedAt:'2026-08-31T14:59:59Z'}),event({eventId:'new',playedAt:'2026-09-01T14:59:59Z'})]};
  core.merge(data,core.parseDocument(doc)); const normalized=core.normalize(data), all=core.aggregate(normalized), september=core.aggregate(normalized,'2026-09-01','2026-09-01');
  assert.equal(all.total.playCount,2); assert.equal(all.total.detailCount,1); assert.equal(all.total.early,1);
  assert.equal(september.total.playCount,1);
});

test('keeps the existing eight Analytics JSON contracts', () => {
  const documents = [
    {name:'volume.json',doc:{version:1,exportedAt:'2026-09-02T00:00:00Z',isEnabled:true,tracks:[]},kind:'volume'},
    {name:'playlists.json',doc:{version:1,playlists:[]},kind:'playlists'},
    {name:'equalizer.json',doc:{kind:'mymusic.equalizer',version:1,equalizer:{isEnabled:true},customPresets:[]},kind:'equalizer'},
    {name:'genres.json',doc:{kind:'mymusic.genre-display-presets',version:1,presets:[]},kind:'genrePresets'},
  ];
  const data=core.createData();
  for (const item of documents) {
    const parsed=core.parseDocument(item.doc,item.name);
    assert.equal(parsed.kind,item.kind);
    core.merge(data,parsed);
  }
  assert.equal(data.sources.length,4);
});
