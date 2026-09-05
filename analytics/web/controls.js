/* Search large local option sets without mounting thousands of option elements. */
const normalizeSearch = value => value.normalize('NFKC').toLocaleLowerCase('ja').trim();
function matchOptions(options, query, limit = 30) {
  const normalized = normalizeSearch(query);
  const words = normalized.split(/\s+/).filter(Boolean);
  const matches = options.map(value => ({value, normalized: normalizeSearch(value)}))
    .filter(option => words.every(word => option.normalized.includes(word)))
    .sort((a, b) => {
      const priority = option => option.normalized === normalized ? 0 : option.normalized.startsWith(normalized) ? 1 : 2;
      return priority(a) - priority(b);
    }).map(option => option.value);
  return { total: matches.length, items: matches.slice(0, limit) };
}
class SearchPicker {
  constructor(root, label, onSelect) {
    this.root = root;
    this.options = [];
    this.selected = '';
    this.active = -1;
    this.onSelect = onSelect;
    const id = root.id;
    root.innerHTML = `<label for="${id}-input">${label}</label><div class="picker-field"><input id="${id}-input" role="combobox" aria-autocomplete="list" aria-expanded="false" aria-controls="${id}-list" aria-describedby="${id}-hint" autocomplete="off" placeholder="${label}名で検索"><button type="button" class="picker-clear" aria-label="${label}の条件を解除" hidden>×</button></div><div class="picker-popup" hidden><p id="${id}-hint" class="picker-hint" role="status"></p><div id="${id}-list" role="listbox" aria-label="${label}の候補"></div></div>`;
    this.input = root.querySelector('input');
    this.popup = root.querySelector('.picker-popup');
    this.list = root.querySelector('[role=listbox]');
    this.hint = root.querySelector('.picker-hint');
    this.clear = root.querySelector('button');
    this.input.addEventListener('focus', () => { this.input.select(); this.open(); });
    this.input.addEventListener('input', () => this.open());
    this.input.addEventListener('keydown', event => {
      if (event.isComposing) return;
      if (event.key === 'Escape') { event.preventDefault(); this.close(); }
      if (['ArrowDown', 'ArrowUp'].includes(event.key)) {
        event.preventDefault();
        if (this.popup.hidden) this.open();
        this.active = this.active < 0 ? (event.key === 'ArrowDown' ? 0 : this.items.length - 1) : Math.max(0, Math.min(this.items.length - 1, this.active + (event.key === 'ArrowDown' ? 1 : -1)));
        this.highlight();
      }
      if (event.key === 'Enter' && !this.popup.hidden) {
        event.preventDefault();
        const choice = this.items[this.active] ?? (this.items.length === 1 ? this.items[0] : undefined);
        if (choice !== undefined) this.choose(choice);
      }
    });
    root.addEventListener('focusout', event => { if (!root.contains(event.relatedTarget)) this.close(); });
    this.list.addEventListener('pointerdown', event => event.preventDefault());
    this.list.addEventListener('click', event => {
      const option = event.target.closest('[role=option]');
      if (option) this.choose(this.items[Number(option.dataset.index)]);
    });
    this.clear.addEventListener('click', () => { this.choose(''); this.input.focus(); this.close(); });
  }
  setOptions(options) { this.options = options; }
  setValue(value) {
    this.selected = value;
    this.input.value = value;
    this.clear.hidden = !value;
    this.root.classList.toggle('has-value', Boolean(value));
  }
  choose(value) { this.setValue(value); this.close(); this.onSelect(value); }
  open() {
    const query = this.input.value === this.selected ? '' : this.input.value;
    const result = matchOptions(this.options, query);
    this.items = result.items;
    this.active = -1;
    this.list.replaceChildren(...this.items.map((value, index) => {
      const option = document.createElement('div');
      option.id = `${this.root.id}-option-${index}`;
      option.setAttribute('role', 'option');
      option.setAttribute('aria-selected', String(value === this.selected));
      option.dataset.index = index;
      option.textContent = value;
      return option;
    }));
    this.hint.textContent = result.total ? `${result.total.toLocaleString()}件${result.total > 30 ? ' · 先頭30件。文字を入力して絞り込み' : ' · ↑↓で移動、Enterで選択'}` : '一致する候補がありません。別の文字で検索してください。';
    this.popup.hidden = false;
    this.input.setAttribute('aria-expanded', 'true');
    this.input.removeAttribute('aria-activedescendant');
  }
  highlight() {
    [...this.list.children].forEach((option, index) => option.classList.toggle('highlighted', index === this.active));
    const option = this.list.children[this.active];
    if (option) { this.input.setAttribute('aria-activedescendant', option.id); option.scrollIntoView({block:'nearest'}); }
  }
  close() {
    this.popup.hidden = true;
    this.input.setAttribute('aria-expanded', 'false');
    this.input.removeAttribute('aria-activedescendant');
    this.input.value = this.selected;
  }
}
