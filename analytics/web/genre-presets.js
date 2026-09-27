(function (global) {
  'use strict';

  const UNASSIGNED = 'maruyama.MyMusic.genre.unassigned';
  const FIXED = new Set(['作業用BGM', 'ハイレゾ']);
  const normalizeText = value => String(value ?? '').trim().normalize('NFKD')
    .replace(/\p{M}/gu, '').toLocaleLowerCase('en-US');
  const includesUnassigned = preset =>
    preset.includesUnassignedGenreSetting !== true
      || preset.enabledGenreNames.includes(UNASSIGNED);
  const moveItem = (items, from, to) => {
    const result = [...items];
    if (from < 0 || to < 0 || from >= result.length || to >= result.length) return result;
    const [item] = result.splice(from, 1); result.splice(to, 0, item); return result;
  };
  const mergeCandidateGenres = (libraryGenres, enabledGenres) => [...new Set([
    ...libraryGenres, ...enabledGenres,
  ].map(value => String(value).trim()).filter(value =>
    value && value !== UNASSIGNED && !FIXED.has(value)
  ))].sort((left, right) => left.localeCompare(right, 'ja', {sensitivity: 'base'}));
  const escapeHTML = value => String(value ?? '').replace(/[&<>'"]/g, character => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;',
  }[character]));

  function create(root = document) {
    const element = selector => root.querySelector(selector);
    const state = {
      presets: [], libraryGenres: [], editing: null, selection: new Set(),
      preservedFixed: new Set(), candidates: [], busy: false, initialized: false,
    };
    const message = element('#preset-message');
    const list = element('#preset-list');
    const dialog = element('#preset-editor');

    async function request(url, options) {
      const response = await fetch(url, options);
      if (!response.ok) {
        let body = {}; try { body = await response.json(); } catch (_) {}
        throw new Error(body.detail || `HTTP ${response.status}`);
      }
      return response.json();
    }
    function setMessage(text = '', error = false) {
      message.textContent = text; message.classList.toggle('error', error);
    }
    function setBusy(value) {
      state.busy = value;
      root.querySelectorAll('#genre-presets button,#genre-presets input').forEach(control => {
        control.disabled = value || control.hasAttribute('data-position-disabled');
      });
      element('#genre-presets').setAttribute('aria-busy', String(value));
    }
    function render() {
      if (!state.presets.length) {
        list.innerHTML = '<article class="panel empty">プリセットはまだありません。新規作成するか、iPhoneから書き出したJSONを読み込んでください。</article>';
        return;
      }
      list.innerHTML = state.presets.map((preset, index) => {
        const visibleGenres = preset.enabledGenreNames.filter(value =>
          value !== UNASSIGNED && !FIXED.has(value)
        );
        return `<article class="preset-card" data-id="${escapeHTML(preset.id)}">
          <div class="preset-card-main"><div class="preset-card-heading"><h2>${escapeHTML(preset.name)}</h2><span class="preset-card-count">${visibleGenres.length}ジャンル</span></div>
          <p class="preset-card-genres">${visibleGenres.length ? visibleGenres.map(escapeHTML).join('、') : '通常ジャンルなし'}</p>
          <p class="preset-card-unassigned">ジャンル未設定: ${includesUnassigned(preset) ? '表示' : '非表示'}${preset.includesUnassignedGenreSetting == null ? '（旧形式の既定）' : ''}</p></div>
          <div class="preset-card-actions"><button type="button" data-action="up" aria-label="${escapeHTML(preset.name)}を上へ移動" ${index === 0 ? 'disabled data-position-disabled' : ''}>↑ 上へ</button><button type="button" data-action="down" aria-label="${escapeHTML(preset.name)}を下へ移動" ${index === state.presets.length - 1 ? 'disabled data-position-disabled' : ''}>↓ 下へ</button><button type="button" data-action="edit" aria-label="${escapeHTML(preset.name)}を編集">編集</button><button type="button" class="danger" data-action="delete" aria-label="${escapeHTML(preset.name)}を削除">削除</button></div>
        </article>`;
      }).join('');
    }
    async function load() {
      setBusy(true); setMessage('読み込み中…');
      try {
        const [presetData, genreData] = await Promise.all([
          request('/api/genre-presets'), request('/api/genre-presets/genres'),
        ]);
        state.presets = presetData.presets; state.libraryGenres = genreData.genres;
        render(); setMessage(`${state.presets.length}件のプリセットを表示しています。`);
      } catch (error) {
        setMessage(`表示を更新できませんでした: ${error.message}`, true);
      } finally { setBusy(false); }
    }
    function renderGenreOptions() {
      const query = normalizeText(element('#preset-search').value);
      const visible = state.candidates.filter(value => normalizeText(value).includes(query));
      element('#preset-genre-options').innerHTML = visible.length ? visible.map(value =>
        `<label class="preset-genre-option"><input type="checkbox" value="${escapeHTML(value)}" ${state.selection.has(value) ? 'checked' : ''}><span title="${escapeHTML(value)}">${escapeHTML(value)}</span></label>`
      ).join('') : '<p class="empty">一致するジャンルがありません。</p>';
      element('#preset-selection-count').textContent = `${state.selection.size}件を選択中`;
    }
    function openEditor(preset = null) {
      dialog.hidden = false;
      state.editing = preset;
      const enabled = preset?.enabledGenreNames || [];
      state.preservedFixed = new Set(enabled.filter(value => FIXED.has(value)));
      state.selection = new Set(enabled.filter(value =>
        value !== UNASSIGNED && !FIXED.has(value)
      ));
      state.candidates = mergeCandidateGenres(state.libraryGenres, enabled);
      element('#preset-editor-title').textContent = preset ? 'プリセットを編集' : 'プリセットを作成';
      element('#preset-name').value = preset?.name || '';
      element('#preset-search').value = '';
      element('#preset-unassigned').checked = preset ? includesUnassigned(preset) : true;
      element('#preset-form-error').textContent = '';
      renderGenreOptions(); element('#preset-name').focus();
    }
    async function save(event) {
      event.preventDefault();
      const name = element('#preset-name').value.trim();
      if (!name) { element('#preset-form-error').textContent = 'プリセット名を入力してください。'; return; }
      const genres = [...state.selection, ...state.preservedFixed];
      if (element('#preset-unassigned').checked) genres.push(UNASSIGNED);
      const payload = {name, enabledGenreNames: genres, includesUnassignedGenreSetting: true};
      setBusy(true); element('#preset-form-error').textContent = '';
      try {
        const url = state.editing
          ? `/api/genre-presets/${encodeURIComponent(state.editing.id)}`
          : '/api/genre-presets';
        await request(url, {method: state.editing ? 'PUT' : 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(payload)});
        dialog.hidden = true; await load(); setMessage(`「${name}」を保存しました。`);
      } catch (error) {
        element('#preset-form-error').textContent = `保存できませんでした: ${error.message}`;
      } finally { setBusy(false); }
    }
    async function reorder(id, direction) {
      const from = state.presets.findIndex(preset => preset.id === id);
      const ordered = moveItem(state.presets, from, from + direction);
      setBusy(true);
      try {
        const data = await request('/api/genre-presets/order', {method: 'PUT', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({ids: ordered.map(preset => preset.id)})});
        state.presets = data.presets; render(); setMessage('表示順を保存しました。');
      } catch (error) { setMessage(`並べ替えできませんでした: ${error.message}`, true); }
      finally { setBusy(false); }
    }
    async function remove(preset) {
      if (!confirm(`「${preset.name}」を削除しますか？`)) return;
      setBusy(true);
      try {
        await request(`/api/genre-presets/${encodeURIComponent(preset.id)}`, {method: 'DELETE'});
        await load(); setMessage(`「${preset.name}」を削除しました。`);
      } catch (error) { setMessage(`削除できませんでした: ${error.message}`, true); }
      finally { setBusy(false); }
    }
    async function importFile(file) {
      if (!file) return;
      setBusy(true); setMessage('ジャンルプリセットを読み込んでいます…');
      try {
        const form = new FormData(); form.append('file', file);
        const result = await request('/api/import', {method: 'POST', body: form});
        if (result.dataKind !== 'genre_presets' || result.errorCount) {
          throw new Error(result.errors?.join(' / ') || 'ジャンルプリセットJSONではありません。');
        }
        await load();
        setMessage(`読み込み完了: 追加${result.newCount}件・更新${result.updatedCount}件・重複${result.duplicateCount}件`);
      } catch (error) { setMessage(`読み込めませんでした: ${error.message}`, true); }
      finally { element('#preset-import').value = ''; setBusy(false); }
    }
    function initialize() {
      if (state.initialized) return; state.initialized = true;
      element('#preset-create').addEventListener('click', () => openEditor());
      element('#preset-import').addEventListener('change', event => importFile(event.target.files[0]));
      element('#preset-cancel').addEventListener('click', () => { dialog.hidden = true; });
      element('#preset-cancel-x').addEventListener('click', () => { dialog.hidden = true; });
      element('#preset-form').addEventListener('submit', save);
      element('#preset-search').addEventListener('input', renderGenreOptions);
      element('#preset-select-all').addEventListener('click', () => { state.selection = new Set(state.candidates); renderGenreOptions(); });
      element('#preset-clear-all').addEventListener('click', () => { state.selection.clear(); renderGenreOptions(); });
      element('#preset-genre-options').addEventListener('change', event => {
        if (!event.target.matches('input[type=checkbox]')) return;
        if (event.target.checked) state.selection.add(event.target.value); else state.selection.delete(event.target.value);
        renderGenreOptions();
      });
      list.addEventListener('click', event => {
        const button = event.target.closest('button[data-action]'); if (!button || state.busy) return;
        const id = button.closest('[data-id]').dataset.id;
        const preset = state.presets.find(item => item.id === id); if (!preset) return;
        if (button.dataset.action === 'edit') openEditor(preset);
        if (button.dataset.action === 'delete') remove(preset);
        if (button.dataset.action === 'up') reorder(id, -1);
        if (button.dataset.action === 'down') reorder(id, 1);
      });
    }
    initialize();
    return {load, importFile, state};
  }

  const api = {create, includesUnassigned, mergeCandidateGenres, moveItem, normalizeText, UNASSIGNED};
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  global.GenrePresetUI = api;
}(typeof window !== 'undefined' ? window : globalThis));
