const state={dashboardPeriod:'7d',tracksPeriod:'all'};
const $=s=>document.querySelector(s), $$=s=>[...document.querySelectorAll(s)];
const esc=v=>String(v??'').replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
const duration=s=>{s=Math.round(Number(s)||0);const h=Math.floor(s/3600),m=Math.floor((s%3600)/60);return h?`${h}時間 ${m}分`:`${m}分`};
const percent=v=>v==null?'—':`${Number(v).toFixed(1)}%`;
const kindLabel=k=>({playback_events:'再生イベント',library:'Library',playback_preferences:'再生傾向',unknown:'不明'}[k]||k);
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
async function loadTracks(){
  const q=encodeURIComponent($('#track-search').value),d=await api(`/api/tracks?period=${state.tracksPeriod}&search=${q}`);
  $('#tracks-body').innerHTML=d.tracks.length?d.tracks.map(x=>`<tr>
    <td><strong>${esc(x.title)}</strong><small>${esc(x.artist)}${x.album?` · ${esc(x.album)}`:''}${x.genre?` · ${esc(x.genre)}`:''}${x.inLibrary?'':' · 履歴のみ'}</small></td>
    <td>${preference(x.playbackPreference)}</td><td><span class="favorite">${x.favorite===1?'♥':'—'}</span></td><td>${x.hasFingerprint?'✓':'—'}</td>
    <td>${x.playCount}回</td><td>${duration(x.totalPlayTime)}</td><td>${percent(x.completionRate)}</td><td>${percent(x.skipRate)}</td>
    <td>${x.lastPlayedAt?new Date(x.lastPlayedAt).toLocaleString('ja-JP'):'—'}</td></tr>`).join(''):`<tr><td colspan="9">${empty()}</td></tr>`;
}
async function loadImports(){const d=await api('/api/imports');$('#imports-body').innerHTML=d.imports.length?d.imports.map(x=>`<tr><td>${new Date(x.importedAt).toLocaleString('ja-JP')}<small>${esc(x.sourceFilename)}</small></td><td>${esc(kindLabel(x.dataKind))}</td><td>${x.newCount}</td><td>${x.updatedCount}</td><td>${x.duplicateCount}</td><td>${x.errorCount}</td></tr>`).join(''):`<tr><td colspan="6">${empty('Import履歴はまだありません')}</td></tr>`}
async function upload(file){if(!file)return;const zone=$('#drop-zone'),result=$('#import-result');zone.querySelector('strong').textContent='Import中…';try{const form=new FormData();form.append('file',file);const d=await api('/api/import',{method:'POST',body:form});result.innerHTML=`<p class="subtitle">${esc(kindLabel(d.dataKind))}としてImportしました。</p><div class="result"><div><strong>${d.newCount}</strong><span>新規</span></div><div><strong>${d.updatedCount}</strong><span>更新</span></div><div><strong>${d.duplicateCount}</strong><span>重複</span></div><div><strong>${d.errorCount}</strong><span>エラー</span></div></div>${d.errors.length?`<p class="subtitle">${d.errors.map(esc).join('<br>')}</p>`:''}`;await Promise.all([loadImports(),loadDashboard()])}catch(e){result.innerHTML=`<p class="subtitle">Importできませんでした: ${esc(e.message)}</p>`}finally{zone.querySelector('strong').textContent='JSONをここへドロップ';$('#file-input').value=''}}
$$('.nav-item').forEach(b=>b.onclick=()=>{$$('.nav-item,.page').forEach(x=>x.classList.remove('active'));b.classList.add('active');$(`#${b.dataset.page}`).classList.add('active');if(b.dataset.page==='tracks')loadTracks();if(b.dataset.page==='import')loadImports()});
$$('.periods button').forEach(b=>b.onclick=()=>{const group=b.closest('.periods');group.querySelectorAll('button').forEach(x=>x.classList.remove('active'));b.classList.add('active');if(group.dataset.target==='dashboard'){state.dashboardPeriod=b.dataset.period;loadDashboard()}else{state.tracksPeriod=b.dataset.period;loadTracks()}});
let searchTimer;$('#track-search').oninput=()=>{clearTimeout(searchTimer);searchTimer=setTimeout(loadTracks,250)};
$('#file-input').onchange=e=>upload(e.target.files[0]);const zone=$('#drop-zone');['dragenter','dragover'].forEach(n=>zone.addEventListener(n,e=>{e.preventDefault();zone.classList.add('drag')}));['dragleave','drop'].forEach(n=>zone.addEventListener(n,e=>{e.preventDefault();zone.classList.remove('drag')}));zone.addEventListener('drop',e=>upload(e.dataTransfer.files[0]));
loadDashboard();
