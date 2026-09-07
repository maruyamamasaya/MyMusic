# Local Analytics 規約

最初にルートの [AGENTS.md](../AGENTS.md) を読みます。このディレクトリは iOS persistence から分離された local FastAPI / SQLite viewer を所有します。

- local-only の `127.0.0.1` 境界と明示的な JSON import/export contract を維持し、app 所有データへの暗黙の write を追加しません。
- route wiring は `app/main.py`、query は `app/queries.py`、schema/import validation は `importer/`、browser behavior は `web/` に置きます。
- Track ID matching は保守的に維持します。exact identity を優先し、曖昧または identity 不足は unresolved のままにします。
- behavior、migration、import、query、UI 変更時は Python と関連する Node/browser test を追加・更新します。[TESTING.md](../TESTING.md) に従い、`.venv`、SQLite data、imports を追跡しません。
