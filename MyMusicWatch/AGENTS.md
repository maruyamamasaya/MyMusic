# Watch アプリケーション規約

最初にルートの [AGENTS.md](../AGENTS.md) を読みます。この target は iPhone player の remote surface であり、二つ目の music player ではありません。

- iPhone の `PlayerStore` だけを playback state の正本とします。Watch 固有の audio、queue、再生永続化、分岐した preference state を追加しません。
- `MyMusic/WatchConnectivity/WatchPlaybackMessage.swift` は versioned な共有 wire contract です。field や command を変更する前に iPhone と Watch の references を検索します。
- transport と lifecycle は `WatchSessionManager`、presentation は Watch view、iPhone の command dispatch は `WatchConnectivityService` に置きます。
- 小画面の accessibility と system-owned companion volume behavior を保ちます。Watch 変更時は contract test を追加・更新し、Full validation を実行します。
