# 日常の音楽史カード Beta

- `MusicHistoryCardService`で現在Libraryに解決できるPlayback Eventを一度索引化し、12種の候補を生成。条件を満たすカードから最大8件を安定順に選び、主役Trackの重複を抑える。FeatureはLibrary内平均との差、Shuffle由来は記録された初回の自動再生経路を使用し、不明値からは推測しない。
- カード集計は読み込み時にMainActor外で行い、キャンセルされた更新の結果は表示に反映しない。
- 最新年のMusic HistoryトップにArtwork中心の「今日の音楽史」を追加。曲はPlayerStoreの手動再生に接続。既存の年Hero、ランキング、月、変化、カレンダー、Time Capsuleは維持。
- `xcodebuild -project MyMusic.xcodeproj -scheme MyMusic -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO build` 成功。標準の`-sdk iphonesimulator`指定はWatch AppIconのSDK不一致で停止したためdestination指定を使用。
- 既存iPhone 17e Simulator 1台、並列OFFで`MusicHistoryCardServiceTests` 10件成功。最初の実行で同率候補の期待値1件を修正し、最終実行は全成功。専用lintはなし。
- 集計の非同期化後に同じschemeのSimulator buildが成功。
- 未確認: 実機での見た目、VoiceOver、膨大な履歴での体感。カード用の新しい永続化はなし。
- XCTestDevicesの新規作成・削除は0件。開始時と終了時の残量は12KB。
