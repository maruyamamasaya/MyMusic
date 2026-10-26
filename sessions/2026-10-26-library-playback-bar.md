# ライブラリ一覧の操作行

- 要求はMyMusicのUI変更としてMATCH。Git rootを確認。既存のAGENTS.md変更と2026-10-23-simulator-policy.mdは保持。
- SongsView／AlbumsView／ArtistsView／GenresViewへ共通LibraryPlaybackBarを追加。ランダム再生を左、既存表示Menuを右へ同じ1行で配置。ジャンルには検索と件数を追加し、検索結果0件の案内も表示。
- 検索／絞り込み後の全曲を対象に、既存の通常ランダム再生条件を適用してTrack IDを重複排除。先頭もランダムに選び、PlayerStoreのshuffleを使用。準備中・対象0曲ではボタンを無効化。
- 横幅不足／大きな文字は操作行の横スクロールで対応。再生ボタンは44ptの高さを確保。
- CURRENT.md／ARCHITECTURE.mdを更新。Store／Service／保存形式／project設定は変更なし。
- 検証: 指定UDID EB3A49ED-6553-4D7E-B933-387951643EAB（既存iPhone 17e / iOS 26.5）向けDebug build成功（iPhone／埋め込みWatch）。最終のタップ領域・空検索結果表示調整後も同コマンドでBUILD SUCCEEDED。git diff --check成功。
- 実画面・VoiceOver・Dynamic Typeの操作確認は未実施。XCTestは未実行。test端末の作成0／削除0、XCTestDevicesは操作なし。
