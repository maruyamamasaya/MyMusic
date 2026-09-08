(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  else root.MyMusicAnalytics = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";
  const DETAIL_CUTOFF = "2026-09-01";
  const KNOWN_FEATURES = ["tempo","energy","calm","dark","aggressive","ambient","electronic","instrumental","vocal","piano","drumAndBass","integratedLUFS","truePeakDBTP","normalizationGainDB"];

  function fail(message) { throw new Error(message); }
  function array(value, name) { if (!Array.isArray(value)) fail(`${name} が見つからないか、配列ではありません。`); return value; }
  function version(value, expected, name) { if (value !== expected) fail(`${name} の未対応バージョンです（${String(value)}）。`); }
  function date(value, name) { const parsed = new Date(value); if (typeof value !== "string" || Number.isNaN(parsed.valueOf())) fail(`${name} の日時が不正です。`); return parsed; }
  function number(value, name) { if (typeof value !== "number" || !Number.isFinite(value) || value < 0) fail(`${name} は0以上の数値である必要があります。`); return value; }
  function text(value, name) { if (typeof value !== "string" || !value.trim()) fail(`${name} が不足しています。`); return value; }

  function createData() { return { tracks:[], playEvents:[], features:[], preferences:[], volume:[], playlists:[], equalizer:[], genrePresets:[], sources:[] }; }
  function detect(doc) {
    if (!doc || typeof doc !== "object" || Array.isArray(doc)) fail("JSONのルートはオブジェクトである必要があります。");
    if ("events" in doc) return "playEvents";
    if (doc.kind === "mymusic.equalizer") return "equalizer";
    if (doc.kind === "mymusic.genre-display-presets") return "genrePresets";
    if ("playlists" in doc) return "playlists";
    if ("isEnabled" in doc && "tracks" in doc) return "volume";
    if ("tracks" in doc && "schemaVersion" in doc) return "preferences";
    if ("tracks" in doc && ("exportedAt" in doc || doc.tracks.some(item => item && ("features" in item || "sourceIdentity" in item)))) return "features";
    if ("tracks" in doc) return "tracks";
    fail("対応するMyMusic分析データではありません。必須データが不足しています。");
  }
  function parseDocument(doc, filename="JSON") {
    const kind = detect(doc), result = { kind, items:[] };
    if (kind === "playEvents") {
      version(doc.schemaVersion, 1, "Playback Events");
      date(doc.exportedAt,"exportedAt");
      result.items = array(doc.events,"events").map((e,i) => {
        const p=`events[${i}]`; version(e.schemaVersion,1,p); text(e.eventId,`${p}.eventId`); text(e.trackId,`${p}.trackId`); date(e.playedAt,`${p}.playedAt`); number(e.playDuration,`${p}.playDuration`); number(e.trackDuration,`${p}.trackDuration`);
        if (typeof e.completed!=="boolean" || typeof e.skipped!=="boolean" || (e.completed&&e.skipped)) fail(`${p} の完走・Skip値が不正です。`);
        return {...e, playedAt:new Date(e.playedAt)};
      });
    } else if (kind === "tracks") {
      version(doc.version,1,"Library"); result.items=array(doc.tracks,"tracks").map((t,i)=>{ text(t.trackID,`tracks[${i}].trackID`); text(t.title,`tracks[${i}].title`); text(t.artist,`tracks[${i}].artist`); number(t.duration,`tracks[${i}].duration`); return {...t}; });
    } else if (kind === "preferences") {
      if (![1,2].includes(doc.schemaVersion)) fail(`Playback Preferences の未対応schemaVersionです（${String(doc.schemaVersion)}）。`);
      date(doc.exportedAt,"exportedAt");
      result.items=array(doc.tracks,"tracks").map((p,i)=>{ text(p.trackId,`tracks[${i}].trackId`); if(!Number.isInteger(p.playbackPreference)||p.playbackPreference < -10||p.playbackPreference>10) fail(`tracks[${i}].playbackPreference が不正です。`); return {...p}; });
    } else if (kind === "features") {
      version(doc.version,1,"Track Features"); date(doc.exportedAt,"exportedAt"); result.items=array(doc.tracks,"tracks").map((f,i)=>{ text(f.trackID,`tracks[${i}].trackID`); if(!f.features||typeof f.features!=="object"||Array.isArray(f.features)) fail(`tracks[${i}].features が不正です。`); return {...f}; });
    } else if (["volume","playlists"].includes(kind)) { version(doc.version,1,kind); result.items=array(kind==="playlists"?doc.playlists:doc.tracks,kind); }
    else if (kind === "equalizer") { version(doc.version,1,"Equalizer"); result.items=[doc.equalizer,...array(doc.customPresets||[],"customPresets")].filter(Boolean); }
    else if (kind === "genrePresets") { version(doc.version,1,"Genre Display Presets"); result.items=array(doc.presets,"presets"); }
    result.source = { filename, kind, count:result.items.length };
    return result;
  }
  function merge(target, parsed) {
    const key = parsed.kind;
    if (["tracks","features","preferences"].includes(key)) {
      const idKey = key === "preferences" ? "trackId" : "trackID";
      const map = new Map(target[key].map(x=>[x[idKey],x])); parsed.items.forEach(x=>map.set(x[idKey],x)); target[key]=[...map.values()];
    } else if (key === "playEvents") {
      const map=new Map(target.playEvents.map(x=>[x.eventId,x])); parsed.items.forEach(x=>map.set(x.eventId,x)); target.playEvents=[...map.values()];
    } else target[key]=parsed.items;
    target.sources = target.sources.filter(s=>s.filename!==parsed.source.filename); target.sources.push(parsed.source); return target;
  }
  function normalize(data) {
    const prefs=new Map(data.preferences.map(p=>[p.trackId,p])); const feats=new Map();
    data.features.forEach(f=>{ const old=feats.get(f.trackID); if(!old || (f.analysisVersion||0)>=(old.analysisVersion||0)) feats.set(f.trackID,f); });
    const tracks=new Map(data.tracks.map(t=>[t.trackID,{...t, preference:prefs.get(t.trackID)||null, features:feats.get(t.trackID)?.features||null}]));
    data.playEvents.forEach(e=>{ if(!tracks.has(e.trackId)) tracks.set(e.trackId,{trackID:e.trackId,title:e.trackTitle,artist:e.artist,album:e.album,duration:e.trackDuration,preference:prefs.get(e.trackId)||null,features:feats.get(e.trackId)?.features||null}); });
    return {...data, tracks:[...tracks.values()], trackMap:tracks};
  }
  function rangeEvents(data,start,end) { const lo=start?new Date(`${start}T00:00:00+09:00`):null, hi=end?new Date(`${end}T23:59:59.999+09:00`):null; return data.playEvents.filter(e=>(!lo||e.playedAt>=lo)&&(!hi||e.playedAt<=hi)); }
  function aggregate(data,start,end) {
    const events=rangeEvents(data,start,end), cutoff=new Date(`${DETAIL_CUTOFF}T00:00:00+09:00`), details=events.filter(e=>e.playedAt>=cutoff), byTrack=new Map();
    events.forEach(e=>{ const row=byTrack.get(e.trackId)||{playCount:0,playTime:0,detailCount:0,completed:0,skipped:0,early:0,lastPlayedAt:null}; row.playCount++; if(e.playedAt>=cutoff){row.playTime+=e.playDuration;row.detailCount++;row.completed+=e.completed?1:0;row.skipped+=e.skipped?1:0;row.early+=e.skipped&&e.playDuration<=30?1:0;} if(!row.lastPlayedAt||e.playedAt>row.lastPlayedAt)row.lastPlayedAt=e.playedAt;byTrack.set(e.trackId,row); });
    const metric=(r)=>({...r,completionRate:r.detailCount?r.completed/r.detailCount:null,skipRate:r.detailCount?r.skipped/r.detailCount:null,earlySkipRate:r.detailCount?r.early/r.detailCount:null});
    const total=metric({playCount:events.length,playTime:details.reduce((s,e)=>s+e.playDuration,0),detailCount:details.length,completed:details.filter(e=>e.completed).length,skipped:details.filter(e=>e.skipped).length,early:details.filter(e=>e.skipped&&e.playDuration<=30).length});
    const tracks=data.tracks.map(t=>({...t,...metric(byTrack.get(t.trackID)||{playCount:0,playTime:0,detailCount:0,completed:0,skipped:0,early:0,lastPlayedAt:null})}));
    return {events,details,total,tracks};
  }
  function featureStats(agg) { const rows=[], trackMap=new Map(agg.tracks.map(t=>[t.trackID,t])); KNOWN_FEATURES.forEach(name=>{ const buckets=[0,0,0,0,0].map(()=>({events:0,completed:0,skipped:0,tracks:new Set()})); agg.events.forEach(e=>{ const v=trackMap.get(e.trackId)?.features?.[name]; if(typeof v!=="number"||!Number.isFinite(v)||v<0||v>1)return; const b=buckets[Math.min(4,Math.floor(v*5))]; b.events++;b.completed+=e.completed?1:0;b.skipped+=e.skipped?1:0;b.tracks.add(e.trackId); }); if(buckets.some(b=>b.events)) rows.push({name,buckets:buckets.map((b,i)=>({band:`${i*20}–${(i+1)*20}%`,events:b.events,tracks:b.tracks.size,completionRate:b.events?b.completed/b.events:null,skipRate:b.events?b.skipped/b.events:null}))}); }); return rows; }
  return { DETAIL_CUTOFF, KNOWN_FEATURES, createData, detect, parseDocument, merge, normalize, rangeEvents, aggregate, featureStats };
});
