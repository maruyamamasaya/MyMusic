const state={dashboardPeriod:'7d',tracksPeriod:'all',sourceKind:'track_features'};
const $=s=>document.querySelector(s), $$=s=>[...document.querySelectorAll(s)];
const esc=v=>String(v??'').replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
const duration=s=>{s=Math.round(Number(s)||0);const h=Math.floor(s/3600),m=Math.floor((s%3600)/60);return h?`${h}時間 ${m}分`:`${m}分`};
const percent=v=>v==null?'—':`${Number(v).toFixed(1)}%`;
const kindLabel=k=>({playback_events:'再生イベント',library:'Library',playback_preferences:'再生傾向',track_features:'音楽特徴量',volume_normalization:'音量ノーマライズ',playlists:'プレイリスト',equalizer:'イコライザー',genre_presets:'ジャンルプリセット',unknown:'不明'}[k]||k);
async function api(url,options){const r=await fetch(url,options);if(!r.ok){let d;try{d=await r.json()}catch{d={}}throw new Error(d.detail||`HTTP ${r.status}`)}return r.json()}
function empty(text='データがありません'){return `<p class="empty">${text}</p>`}
async function loadDashboard(){
  const d=await api(`/api/dashboard?period=${state.dashboardPeriod}`),m=d.metrics;
  $('#metrics').innerHTML=[
    ['Library',`${Number(m.library_count).toLocaleString()}曲`],['再生回数',`${Number(m.play_count).toLocaleString()}回`],
    ['総再生時間',duration(m.total_play_time)],['Skip率',percent(m.skip_rate)],['完走率',percent(m.completion_rate)],
    ['お気に入り',`${Number(m.favorite_count).toLocaleString()}曲`],['Good / Badあり',`${Number(m.rated_count).toLocaleString()}曲`]
  ].map(x=>`<div class="metric"><span>${x[0]}</span><strong>${x[1]}</strong></div>`).join('');
  renderBars('#daily',d.daily);renderHours(d.hourly);renderRanks('#top-tracks',d.topTracks);
  renderRanks('#skipped-tracks',d.skippedTracks);renderRanks('#artists',d.artists,true);
  renderRanks('#preferences',d.preferenceDistribution,true);
}
function renderBars(sel,rows){if(!rows.length){$(sel).innerHTML=empty();return}const max=Math.max(...rows.map(x=>x.value),1);$(sel).innerHTML=rows.map(x=>`<div class="bar" style="--height:${Math.max(4,x.value/max*100)}%" data-tip="${esc(x.label)}: ${x.value}回"></div>`).join('')}
function renderHours(rows){const map=Object.fromEntries(rows.map(x=>[x.label,x.value])),max=Math.max(...Object.values(map),1);$('#hourly').innerHTML=Array.from({length:24},(_,h)=>`<div class="hour" style="--level:${(map[h]||0)/max}" title="${h}時: ${map[h]||0}回">${h}</div>`).join('')}
function renderRanks(sel,rows,labelOnly=false){$(sel).innerHTML=rows.length?rows.map((x,i)=>`<div class="rank-row"><span class="rank">${i+1}</span><div><strong>${esc(labelOnly?x.label:x.title)}</strong>${labelOnly?'':`<small>${esc(x.artist)}</small>`}</div><span>${x.value}${labelOnly?'曲':'回'}</span></div>`).join(''):empty()}
function preference(value){if(value==null)return '<span class="preference">未取込</span>';const cls=value>0?'good':value<0?'bad':'';return `<span class="preference ${cls}">${value>0?'+':''}${value}</span>`}
function preferenceEditor(x){if(x.playbackPreference==null)return preference(null);return `<select class="preference-editor" data-track-id="${esc(x.trackId)}" aria-label="${esc(x.title)}のGood / Bad">${Array.from({length:21},(_,i)=>i-10).map(v=>`<option value="${v}" ${v===x.playbackPreference?'selected':''}>${v>0?'+':''}${v}</option>`).join('')}</select>`}
function favoriteEditor(x){if(x.playbackPreference==null)return `<span class="favorite">${x.favorite===1?'♥':'—'}</span>`;return `<button class="favorite-editor ${x.favorite===1?'active':''}" data-track-id="${esc(x.trackId)}" data-favorite="${x.favorite===1}" aria-label="${esc(x.title)}のお気に入り">${x.favorite===1?'♥':'♡'}</button>`}
async function loadTracks(){
  const q=encodeURIComponent($('#track-search').value),d=await api(`/api/tracks?period=${state.tracksPeriod}&search=${q}`);
  $('#tracks-body').innerHTML=d.tracks.length?d.tracks.map(x=>`<tr>
    <td><strong>${esc(x.title)}</strong><small>${esc(x.artist)}${x.album?` · ${esc(x.album)}`:''}${x.genre?` · ${esc(x.genre)}`:''}${x.inLibrary?'':' · 履歴のみ'}</small></td>
    <td>${preferenceEditor(x)}</td><td>${favoriteEditor(x)}</td><td>${x.hasFingerprint?'✓':'—'}</td>
    <td>${x.playCount}回</td><td>${duration(x.totalPlayTime)}</td><td>${percent(x.completionRate)}</td><td>${percent(x.skipRate)}</td>
    <td>${x.lastPlayedAt?new Date(x.lastPlayedAt).toLocaleString('ja-JP'):'—'}</td></tr>`).join(''):`<tr><td colspan="9">${empty()}</td></tr>`;
  $$('.preference-editor').forEach(el=>el.onchange=()=>savePreference(el.dataset.trackId,Number(el.value),favoriteValue(el.dataset.trackId)));
  $$('.favorite-editor').forEach(el=>el.onclick=()=>savePreference(el.dataset.trackId,preferenceValue(el.dataset.trackId),el.dataset.favorite!=='true'));
}
function preferenceValue(trackId){return Number($(`.preference-editor[data-track-id="${CSS.escape(trackId)}"]`).value)}
function favoriteValue(trackId){return $(`.favorite-editor[data-track-id="${CSS.escape(trackId)}"]`).dataset.favorite==='true'}
async function savePreference(trackId,playbackPreference,favorite){try{await api(`/api/preferences/${encodeURIComponent(trackId)}`,{method:'PUT',headers:{'Content-Type':'application/json'},body:JSON.stringify({playbackPreference,favorite})});await Promise.all([loadTracks(),loadDashboard()])}catch(e){alert(`再生傾向を保存できませんでした: ${e.message}`);await loadTracks()}}
const value=(v,digits=2)=>v==null?'—':Number(v).toFixed(digits);
async function loadSources(){
  const d=await api(`/api/sources/${state.sourceKind}`),trackKind=['track_features','volume_normalization'].includes(state.sourceKind);
  $('#source-summary').innerHTML=[['データ種別',kindLabel(state.sourceKind)],['登録項目',`${d.count}件`],...(trackKind?[['Library紐付け',`${d.linkedCount} / ${d.count}曲`]]:[])].map(x=>`<div class="metric"><span>${x[0]}</span><strong>${x[1]}</strong></div>`).join('');
  const configs={track_features:{head:['曲','Library','Tempo','Energy','Vocal','解析Version'],row:x=>[`${esc(x.title)}<small>${esc(x.subtitle||'')}</small>`,x.linked?'✓':'未紐付け',value(x.data.features?.tempo,1),value(x.data.features?.energy),value(x.data.features?.vocal),x.data.analysisVersion]},volume_normalization:{head:['曲','Library','Integrated LUFS','True Peak','補正Gain','相対パス'],row:x=>[`${esc(x.title)}<small>${esc(x.subtitle||'')}</small>`,x.linked?'✓':'未紐付け',value(x.data.integratedLUFS,1),value(x.data.truePeakDBTP,1),value(x.data.normalizationGainDB,1),esc(x.data.relativePath)]},playlists:{head:['プレイリスト','種類','タグ','収録曲','Library紐付け','更新日時'],row:x=>[esc(x.title),esc(x.data.kind),esc((x.data.tags||[]).join(', ')||'—'),`${x.trackCount}曲`,`${x.linkedTrackCount} / ${x.trackCount}`,x.data.updatedAt?new Date(x.data.updatedAt).toLocaleString('ja-JP'):'—']},equalizer:{head:['設定 / プリセット','区分','有効','Preamp','Band Gain'],row:x=>[esc(x.title),esc(x.data.recordType),x.data.isEnabled==null?'—':(x.data.isEnabled?'ON':'OFF'),value(x.data.preamp,1),esc((x.data.gains||x.data.bands?.map(b=>b.gain)||[]).join(', '))]},genre_presets:{head:['プリセット','有効ジャンル数','ジャンル','未分類設定'],row:x=>[esc(x.title),(x.data.enabledGenreNames||[]).length,esc((x.data.enabledGenreNames||[]).join(', ')||'—'),x.data.includesUnassignedGenreSetting==null?'既定':(x.data.includesUnassignedGenreSetting?'含む':'含まない')]}};
  const c=configs[state.sourceKind];$('#sources-head').innerHTML=`<tr>${c.head.map(x=>`<th>${x}</th>`).join('')}</tr>`;$('#sources-body').innerHTML=d.items.length?d.items.map(x=>`<tr>${c.row(x).map(v=>`<td>${v}</td>`).join('')}</tr>`).join(''):`<tr><td colspan="${c.head.length}">${empty('このJSONはまだImportされていません')}</td></tr>`;
}
async function loadImports(){const d=await api('/api/imports');$('#imports-body').innerHTML=d.imports.length?d.imports.map(x=>`<tr><td>${new Date(x.importedAt).toLocaleString('ja-JP')}<small>${esc(x.sourceFilename)}</small></td><td>${esc(kindLabel(x.dataKind))}</td><td>${x.newCount}</td><td>${x.updatedCount}</td><td>${x.duplicateCount}</td><td>${x.errorCount}</td></tr>`).join(''):`<tr><td colspan="6">${empty('Import履歴はまだありません')}</td></tr>`}
async function upload(file){if(!file)return;const zone=$('#drop-zone'),result=$('#import-result');zone.querySelector('strong').textContent='Import中…';try{const form=new FormData();form.append('file',file);const d=await api('/api/import',{method:'POST',body:form});result.innerHTML=`<p class="subtitle">${esc(kindLabel(d.dataKind))}としてImportしました。</p><div class="result"><div><strong>${d.newCount}</strong><span>新規</span></div><div><strong>${d.updatedCount}</strong><span>更新</span></div><div><strong>${d.duplicateCount}</strong><span>重複</span></div><div><strong>${d.errorCount}</strong><span>エラー</span></div></div>${d.errors.length?`<p class="subtitle">${d.errors.map(esc).join('<br>')}</p>`:''}`;await Promise.all([loadImports(),loadDashboard()])}catch(e){result.innerHTML=`<p class="subtitle">Importできませんでした: ${esc(e.message)}</p>`}finally{zone.querySelector('strong').textContent='JSONをここへドロップ';$('#file-input').value=''}}
$$('.nav-item').forEach(b=>b.onclick=()=>{$$('.nav-item,.page').forEach(x=>x.classList.remove('active'));b.classList.add('active');$(`#${b.dataset.page}`).classList.add('active');if(b.dataset.page==='tracks')loadTracks();if(b.dataset.page==='sources')loadSources();if(b.dataset.page==='import')loadImports()});
$$('#source-tabs button').forEach(b=>b.onclick=()=>{$$('#source-tabs button').forEach(x=>x.classList.remove('active'));b.classList.add('active');state.sourceKind=b.dataset.kind;loadSources()});
$$('.periods button').forEach(b=>b.onclick=()=>{const group=b.closest('.periods');group.querySelectorAll('button').forEach(x=>x.classList.remove('active'));b.classList.add('active');if(group.dataset.target==='dashboard'){state.dashboardPeriod=b.dataset.period;loadDashboard()}else{state.tracksPeriod=b.dataset.period;loadTracks()}});
let searchTimer;$('#track-search').oninput=()=>{clearTimeout(searchTimer);searchTimer=setTimeout(loadTracks,250)};
$('#file-input').onchange=e=>upload(e.target.files[0]);const zone=$('#drop-zone');['dragenter','dragover'].forEach(n=>zone.addEventListener(n,e=>{e.preventDefault();zone.classList.add('drag')}));['dragleave','drop'].forEach(n=>zone.addEventListener(n,e=>{e.preventDefault();zone.classList.remove('drag')}));zone.addEventListener('drop',e=>upload(e.dataTransfer.files[0]));
loadDashboard();
