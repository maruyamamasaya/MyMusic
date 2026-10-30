# 出力先を再生中タイトル領域へ（2026-10-29）

- Context Guard MATCH、Git root一致。CURRENT／ARCHITECTUREと現状を確認。
- アートワーク位置を変更しないユーザー指定により、前回のsafeAreaInsetを通常／作業用／HiResから撤去し元のcontent位置へ復元。
- toolbar principalへPlaybackOutputLabelを配置し、従来の再生中title領域を使用。200pt幅、接続方式9pt＋機器名10pt・最大2行・minimumScaleFactor 0.7。ボタン／popoverなし。未取得時は元title。通常のアート画面は既存palette優先を維持。
- SwiftUI Labelはtoolbarでiconだけになるため、接続方式は明示的なImage＋Textで常時表示。
- Service／Store／再生／永続化変更なし。既存の他作業は保持。

## 検証

- 指定iPhone 17e（EB3A49ED-6553-4D7E-B933-387951643EAB）でPlaybackOutputLayoutTests実行成功。並列無効、worker1、同時destination1。
- UIHostingControllerで実際のNowPlayingViewに固定の長いBluetooth名を設定し、標準／accessibility2の描画画像を目視確認。機器名末尾Room Speaker・Bluetooth文字が表示され、Artwork上端が変更前の位置へ戻ることを確認。
- 最初の描画でLabelの接続方式文字の自動省略を発見し、明示的なHStackへ修正後に再test成功。build込みで成功、git diff --check成功。
- XCTestDevices開始前／終了後ともUUID folderなし・合計12K。test端末作成0・削除0、データ削除なし。
- 実機未反映。非常に長い機器名は2行・縮小限界で省略され得る。小さな表示はユーザー指定に基づく固定文字サイズで、VoiceOverは全文を読む。作業用／HiResは同じ表示部品とprincipal配置を適用しbuild確認、実表示は未確認。
