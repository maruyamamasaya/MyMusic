# Deep Dive Mix Beta（2026-09-21）

- ホームのMIXにDeep Diveを追加。タップ後にArtist／Albumを選び、続いて候補を選ぶと、その候補に属する低再生曲を一時キューで即再生する。
- `DeepDiveSelectionService`は既存の通常シャッフル適格性を満たす曲を受け取り、直近30日のPlayback History日別再生開始数が合計15回以上、かつ累計再生0〜1回の曲を持つArtist／Albumを候補にする。対象からタイルを開くたび最大8件をランダムに選ぶ。AlbumはタイトルとAlbum Artist（なければTrack Artist）で区別する。
- キューは最大25曲、累計0回を1回より優先し、同数内は既存MIXのPreference／Overplay重み付き日次順位を使う。候補・キューは保存しない。
- 実ライブラリでの候補分布、画面表示、VoiceOver・Dynamic Typeは未確認。
- iOS Simulator向けDebug build成功。既存iPhone 17e Simulatorで`DeepDiveSelectionServiceTests` 3件と`MixSelectionServiceTests` 5件が成功（合計8件、並列実行なし）。
- Simulatorへの手動installはCoreSimulatorService接続エラーで失敗したため、画面操作の目視確認は未実施。XCTestDevicesのUUIDフォルダは作成・削除とも0件、終了時の合計容量は12K。
