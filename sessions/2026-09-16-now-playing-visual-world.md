# 再生中 Visual World Beta

- ユーザーとの議論で、現行の再生中画面を保持し「完了」をアート画面への切り替えに置き換える方針へ変更。アート画面側の切り替えは細く低輝度のアイコンにした。
- `Documentation/NowPlayingVisualWorld.md` に色、音との連動、操作、データフロー、アクセシビリティ、検証項目を設計した。
- アート画面を追加。テーマ背景とジャケット平均色による拡散光、Track Featuresに基づく動き、出力タップ由来の音量・左右バランス・ステレオ幅を使用。既存の再生／お気に入り／曲移動／seek／各操作をPlayerStoreへ接続した。音源、永続化、JSON、Watch通信は変更していない。
- `xcodebuild -project MyMusic.xcodeproj -scheme MyMusic -destination 'generic/platform=iOS Simulator' -configuration Debug -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build` は `BUILD SUCCEEDED`。最初のsandbox内buildはXcode cacheとSimulatorサービスにアクセスできず、次の一時package checkout指定ではネットワーク制限でZIPFoundationを取得できなかった。既存Xcode package cacheを使うbuildで確認した。
- 未解決: 実機で4テーマの光量、長押しと左右スワイプ、VoiceOver、Dynamic Type、長時間使用時の発熱を確認する。今回 `xcodebuild test` は実行していない。XCTestDevicesの新規作成・削除は0件。
