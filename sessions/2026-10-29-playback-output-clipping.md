# 出力先表示のclip修正（2026-10-29）

- Context Guard MATCH、Git root一致。CURRENT／ARCHITECTURE、現在の表示と履歴を確認。既存の他作業は保持。
- 原因: topBarLeadingのtoolbar幅はtitle／右の2操作により圧縮され、ラベルの幅160pt指定でも実際の文字領域が著しく狭くclipされる。2行上限も長い名前の全文表示を妨げた。
- 既存iPhone 17e Simulator（EB3A49ED-6553-4D7E-B933-387951643EAB／iOS 26.5）でUIHostingControllerに実際のNowPlayingViewを表示し、長い名前の切れを画像で再現。
- 通常／作業用／HiResの出力先ラベルをtoolbarからnavigation bar直下のsafeAreaInsetへ移動。全幅・横24pt余白、機器名の行数制限なし、左寄せ常時表示。アート画面の既存paletteは維持。
- Service／Store／再生／保存の変更なし。
- PlaybackOutputLayoutTestsを追加。実際のNowPlayingViewと固定の長いBluetooth機器名を使用し、標準／accessibility2でSimulator上の描画画像を保存・添付。曲未選択のレイアウトfixtureであり、実際のBluetooth接続は検証しない。

## 検証

- 修正前testでclipを再現。修正後test成功。標準サイズのtitle描画が安定するまでの待機を調整して最終test成功（1テスト内で2サイズ）。
- 修正前後の画像を目視。最終標準／accessibility2とも機器名末尾「Room Speaker」まで表示、標準title「再生中」も表示。
- xcodebuild testは指定UDID・並列無効・worker1・同時destination1。build込みで成功。git diff --check成功。
- XCTestDevices開始前: UUID folderなし、合計12K。終了後もUUID folderなし、合計12K。test端末作成0・削除0、データ削除なし。Simulatorは既存のboot済み端末を利用。
- 実機未反映。実機のBluetooth／AirPlay／有線接続、作業用／HiResの実表示は未確認（共通ラベルと同じ配置変更を適用、build確認済み）。
