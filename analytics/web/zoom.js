(function (root) {
  'use strict';

  const levels = Object.freeze([75, 80, 90, 100, 110, 125, 150]);
  const storageKey = 'mymusic.analytics.zoomPercent';

  function normalize(value) {
    const numeric = Number(value);
    return levels.includes(numeric) ? numeric : 100;
  }

  function adjacent(current, direction) {
    const normalized = normalize(current);
    const index = levels.indexOf(normalized);
    return levels[Math.max(0, Math.min(levels.length - 1, index + direction))];
  }

  function shortcut(event) {
    if (!(event.ctrlKey || event.metaKey) || event.altKey) return null;
    if (event.key === '0') return 100;
    if (event.key === '+' || event.key === '=' || event.key === 'Add') return 'in';
    if (event.key === '-' || event.key === '_' || event.key === 'Subtract') return 'out';
    return null;
  }

  function initialize(documentObject, storage) {
    const select = documentObject.querySelector('#zoom-level');
    const zoomIn = documentObject.querySelector('#zoom-in');
    const zoomOut = documentObject.querySelector('#zoom-out');
    if (!select || !zoomIn || !zoomOut) return null;

    let current = 100;
    try { current = normalize(storage.getItem(storageKey)); } catch (_) {}

    function apply(value, persist = true) {
      current = normalize(value);
      documentObject.documentElement.style.zoom = `${current}%`;
      select.value = String(current);
      zoomOut.disabled = current === levels[0];
      zoomIn.disabled = current === levels[levels.length - 1];
      if (persist) {
        try { storage.setItem(storageKey, String(current)); } catch (_) {}
      }
      return current;
    }

    select.addEventListener('change', () => apply(select.value));
    zoomIn.addEventListener('click', () => apply(adjacent(current, 1)));
    zoomOut.addEventListener('click', () => apply(adjacent(current, -1)));
    documentObject.addEventListener('keydown', event => {
      const action = shortcut(event);
      if (action === null) return;
      event.preventDefault();
      apply(action === 'in' ? adjacent(current, 1) : action === 'out' ? adjacent(current, -1) : action);
    });
    apply(current, false);
    return {apply, get value() { return current; }};
  }

  const api = {levels, storageKey, normalize, adjacent, shortcut, initialize};
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  root.MyMusicZoom = api;
  if (root.document) root.addEventListener('DOMContentLoaded', () => initialize(root.document, root.localStorage));
})(typeof window !== 'undefined' ? window : globalThis);
