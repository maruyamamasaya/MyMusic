# ベリーショート曲の自動選曲除外

## 作業

- 30秒未満を通常ランダム再生の候補外とする`Track.isEligibleForRegularRandomPlayback`を追加した。30秒ちょうどは候補に含める。
- `isEligibleForRegularPlayback`は変更せず、ベリーショート曲のライブラリ表示、検索、通常Playlist互換性、手動選択、順再生を維持した。
- 共通shuffle判定を使うQuick Play、Discovery、最近追加、Repeat、Selective／Genre Random、Favorite系、Mood Station、PlayerStoreの自動shuffle orderへ新条件を反映した。
- Highlightのsource trackを同じ共通条件で絞り、全モードからベリーショート曲を除外した。
- Album、Artist、通常Playlist、お気に入りの直接shuffle開始時も、最初の1曲を含めてベリーショート曲をqueueへ入れないようにした。
- ホームのランダム再生タイルでベリーショート曲のArtworkが代表に選ばれ、先頭へ再挿入される経路を除外した。
- README、CURRENT、ARCHITECTUREへ境界と適用範囲を記録した。永続化形式とJSON契約は変更していない。

## 検証

- iPhone 17 / iOS 26.5 Simulatorを1台だけ使い、関連XCTest 12件を直列実行した。12件すべて成功し、MyMusic／MyMusicWatchのDebug test buildも成功した。
- 29.999秒の通常曲が通常ランダム・Discovery・Highlight共通候補・最近追加・ホーム代表Artworkから除外され、30.0秒の通常曲が候補に残ることを確認した。
- テスト前後の`XCTestDevices`はUUID folder 0件、合計12 KBで、新規作成・削除したtest端末はいずれも0件だった。
- 専用lint設定は存在しないため、lintは実行していない。

## 未解決事項

- 実音源を使った手動UI確認は未実施。
- 作業用BGMの専用ランダム再生は通常再生とは別経路のため、30秒未満でも従来どおり候補に含む。
