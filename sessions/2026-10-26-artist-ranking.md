# MyMusicアーティストランキング Beta

- Context Guard: MATCH。MyMusic Git root一致。HomeStereoはユーザー指定の参照調査のみで変更なし。両側データ交換契約はrevision 5、cmpで本文一致。新規データ交換は行わない。
- HomeStereo docs/artist-ranking.mdとArtistRanking.swift、ArtistRankingView.swiftを参照。ホーム→アクティビティ→ランキングを追加し、インスト／ボーカル、総合／回数／時間、最大100位を実装。
- 1位は王冠付き全幅カード、2位cyan、3位bronze、4〜10位purple、下位blue。iPhoneではadaptive gridで通常2列、大きいDynamic Typeでは1列へ縮小。Artwork、値、比較bar、詳細の4項目加点tileを表示。
- 部門はジャンルのOR／未分類、両部門重複を許可し、初期未設定。設定は端末内保存、キャンセルでは変更しない。消えた選択ジャンルも保持。破損データの自動上書きなし。
- HomeStereoと同じ全登録曲数の平方根補正と40/10/30/20の正規化。MyMusicの累計回数・詳細event時間・現在評価を使用。旧累計時間から詳細event時間を推定しないため、旧履歴では表示時間が少ない場合がある。両アプリでデータが異なると順位も異なる。
- 計算はbackground task、キャンセルとgenerationで古い結果を破棄。部門・方式切替は保存済みの3リストを使用。既存形式と外部依存の追加なし。
- 詳細から部門内曲の全曲／指定曲開始が可能。MyMusicに既存の追加用queue APIがないため、HomeStereoのキュー追加操作は今回含めない。HomeStereoのMac用列数・sheet寸法はiPhone向けへ調整。
- ArtistRankingTestsへ部門重複・未設定・15評価・全登録曲分母・通常曲限定・旧時間非推定・負評価・100位上限・同点自然順・4項目の配点を追加。
- ユーザー方針によりbuild・test・Simulator・実機deploy未実施。git diff --checkのみ実施。新規Swiftの型検証、画面描画、保存復元と実操作、実データ性能は未検証。
- テスト端末作成・削除0台。XCTestDevices調査／変更なし。
