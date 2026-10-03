# HomeStereoコンテキストガード導入文書

- ユーザー依頼: 別GitのMacアプリに導入するコンテキストガードをMarkdownで作成する。
- 方針: 両者は独立した対等なプレイヤー。製品方針ではMyMusicを中心とし、HomeStereoはデスクトップの検索・分析・統合的な設定を担う。Macの再生音響・スピーカー設定は独自の責務として、MyMusicとの連携とは独立して発展させる。データ正本や衝突解決の優先順位は製品方針から推測しない。
- 作成: `Documentation/HomeStereoContextGuard.md`。MATCH／UNCERTAIN／MISMATCH、repository境界、version付き交換データによる疎結合、Analyzer／Analyticsとの区別を記載した。
- 根拠: MyMusicのCURRENT.md／ARCHITECTURE.mdにあるLibrary relativePathとHomeStereo Playback Events Import、およびADR-0003のAnalyzer境界を確認した。
- 検証: Git root一致、追加文書のdiff／statusと空白エラーを確認。文書のみのためbuild／testは実行しない。test端末の作成・削除は各0台。
- 未確認: HomeStereo repositoryは調査・変更しておらず、文書は未適用。HomeStereoの実装構成と連携送信仕様は導入時に確認する。Favorite／Preference／Playlistの競合解決は今回決定していない。
- 既存の未コミット変更は保持。アプリ状態・architectureの変更はなく、CURRENT.md／ARCHITECTURE.mdは今回変更しない。
