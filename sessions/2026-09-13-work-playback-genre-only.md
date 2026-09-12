# 作業用BGMのジャンル指定への統一

## 作業

- `Track.isEligibleForWorkPlayback`から20分以上という再生時間条件を削除し、分割・正規化済みgenreに「作業用BGM」が完全一致する場合だけ作業用と判定するようにした。
- 共通判定を利用する作業用catalog、通常shuffle、Highlight、Playlist互換性、最近追加、ホーム代表Artwork、ライブラリ整理候補の各経路を調査した。各利用側には個別の時間条件がなく、共通判定の変更が一貫して反映されることを確認した。
- 長尺曲が通常再生側へ戻り、作業用genre曲だけが専用catalogや通常再生除外の対象になるよう関連テストを更新した。
- 画面上の「作業用サイズ再生」を「作業用BGM再生」へ変更し、Home、作業用ライブラリ、作業用Playlistの説明から長さ条件を削除した。
- `README.md`、`CURRENT.md`、`ARCHITECTURE.md`を新しい分類条件へ更新した。保存形式やJSON契約の変更はない。

## 検証

- iPhone 17 / iOS 26.5 Simulatorを1台だけ使用し、関連するXCTest 17件を直列実行した。17件すべて成功し、同じtest action内のMyMusic／MyMusicWatch buildも成功した。
- テスト開始前の`XCTestDevices`はUUID folder 0件、合計12 KBだった。新しいtest端末は作成されなかった。
- 専用lint設定は存在しないため、lintは実行していない。

## 未解決事項

- 実音源metadataを使った手動確認は未実施。既存の作業用Playlistに入っている、genre未指定の長尺曲参照は削除されず、新しい互換性判定により一覧・再生対象から外れる。
