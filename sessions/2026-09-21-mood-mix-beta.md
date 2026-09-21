# Mood Mix Beta（2026-09-21）

- ホームのMIXへMood Mixを追加。Calm／Energy／Ambient／Electronicの選択画面を開き、いずれかをタップすると最大25曲の一時キューを直接再生する。
- `StationStore`の通常再生対象・特徴量ありの候補を利用し、`MoodStationService`のLibrary内percentile、有効範囲、0.72閾値、Overplay補正、Artist分散を共有する。対象がない項目は無効表示する。キューは永続化しない。
- 実データでの候補分布と画面操作、VoiceOver・Dynamic Typeは未確認。
- iOS Simulator向けDebug build成功。既存iPhone 17e SimulatorでMood Station関連の既存・追加XCTest 18件が成功（並列実行なし）。
- 選択画面の候補計算を読込後1回にした最終変更後もiOS Simulator向けDebug build成功。XCTestDevicesのUUIDフォルダは作成・削除とも0件、終了時の合計容量は12K。
