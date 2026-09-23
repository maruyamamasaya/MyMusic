# FLACハイレゾmetadata修正

## 調査

- 24bit／96kHzと16bit／44.1kHzのFLACを生成してApple APIのstream descriptionを確認した。
- codecとsample rateは取得できる一方、FLACの`mBitsPerChannel`は0だった。source bit depth flagsと`kAudioFilePropertySourceBitDepth`はそれぞれ24bit／16bitを正しく示した。
- 既存実装は同じflagsをALACにだけ適用していたため、FLACの`bitDepth`が`nil`となり、音源仕様によるHi-Res自動分類から漏れていた。
- `.flac`はlibrary scan対象であり、ジャンル項目「ハイレゾ」による明示分類は既存実装でも有効だった。

## 実装

- `MetadataService`でFLACにもsource bit depth flagsを適用し、16／20／24／32bitを復元するようにした。
- metadata revisionを2から3へ更新し、旧cacheで読込済みのFLACも次回scan時にmetadataを再取得するようにした。
- FLAC／ALAC／PCMのbit depth復元と、旧revision cacheの再取得を確認するXCTestを追加した。

## 検証

- `AudioResolutionClassificationTests` 4件成功。
- `TrackFirstSeenAtTests.testQuickScanReloadsMetadataFromAnOlderRevision` 1件成功。
- generic iOS Simulator Debug build成功。
- testは既存のiPhone 17e / iOS 26.5 Simulator 1台で並列実行せずに実施した。
- iPhone実機でのFLAC直接出力再生とUSB DAC出力レートは未確認。

## Xcodeストレージ

- XCTestDevicesは開始前後ともUUID folder 0件、合計12KBだった。
- この作業によるtest端末の作成・削除はなかった。
