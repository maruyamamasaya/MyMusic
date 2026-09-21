# 作業用BGMの通常ライブラリからの分離

## 作業

- ジャンル項目に「作業用BGM」が完全一致する曲を、通常ライブラリのTrack / Album / Artist集合から除外した。
- 作業用catalogは全曲から独立して構築し、通常側のジャンル表示設定やプリセットに左右されないようにした。
- 作業用プレイリストの追加、詳細、件数、ホーム表示と再生は、通常ライブラリではなく作業用catalogから曲を解決するようにした。
- 「作業用BGM」を通常側のジャンル表示設定から除外した。音源、履歴、Preference、Playlistの保存形式は変更していない。

## 検証

- `LibraryGenreFilterTests`を更新し、通常の曲・アルバム・アーティストからの除外、作業用catalogへの保持、通常ジャンル設定からの独立を検証対象にした。
- iPhone 17e / iOS 26.5 Simulatorで`LibraryGenreFilterTests` 2件が成功した。並列テストは無効、workerは1に固定した。
- generic iOS向けDebug buildは成功した。Simulator向けscheme／target buildは既存の`MyMusicWatch/Assets.xcassets`のAppIconエラーで失敗したが、同じ変更を含む対象テストのbuildと実行は成功した。
- XCTestDevicesはテスト前後とも新規UUID folderなし、合計12 KBで、作成・削除したtest端末は0件だった。

## 未解決事項

- 実音源を使った通常一覧、通常検索、作業用一覧、作業用プレイリストの手動UI確認は未実施。
