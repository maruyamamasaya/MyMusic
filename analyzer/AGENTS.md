# Analyzer 規約

最初にルートの [AGENTS.md](../AGENTS.md) を読みます。このディレクトリは Python audio analysis と versioned JSON export を所有します。setup と command は [README.md](README.md) を参照します。

- source music を rewrite、transcode、変更しません。identity と path validation は fail-closed とします。
- production DSP Analyzer（`mymusic_analyzer`）、Semantic v2（`mymusic_semantic`）、`poc/` を分離します。PoC dependency を production verification に追加しません。
- `Documentation/track-feature-schema-v1.json` との互換性を維持し、contract 変更時は全 producer / consumer test を確認します。
- 実装中は関連する production unittest、完了前は [TESTING.md](../TESTING.md) の Analyzer 検証を実行します。生成 cache、embedding、export は追跡しません。
