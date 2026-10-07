# 再生画面のいいねを赤に変更

- 要求はMyMusicにMATCH。Git rootを確認し、既存の未コミット変更を維持した。
- TrackFavoriteButtonに選択色の引数を追加し、NowPlayingViewだけ赤を指定。タップ時の円も同色とする。その他の呼び出しは従来のピンクを維持する。
- VisualWorldControllerのいいね済みハートも赤へ変更。解除時の色、Preference保存、再生操作は変更しない。アーキテクチャ変更なし。
- generic iPhone／埋め込みWatch Simulator Debug buildはBUILD SUCCEEDED。初回はsandboxによるcacheアクセス制限で失敗し、許可された環境で再実行して成功。
- git diff --check成功。表示色だけの変更につきXCTestは実行しない。test端末の作成・削除は0台。XCTestDevicesの容量は未計測。
- 実機表示は未検証。ユーザー指示どおりデプロイは行わない。
