# 音楽特徴量 Beta 3 — 表示

## 操作

1. MacのAnalyzerで少数曲からJSONを生成する。実行方法は[Analyzer README](../analyzer/README.md)を参照。
2. Files等へ転送し、MyMusicの「設定 → 音楽特徴量 → 特徴量JSONを読み込む」からImportする。
3. 通常の「再生中」ではアートワークをタップして裏面の「オーディオ情報」を開く。「作業用再生中」ではアートワークをタップして曲送り操作を表示し、その中の「オーディオ情報」を選ぶ。
4. オーディオ情報内のBadgeをタップすると「音楽特徴」詳細を開く。分類スコア、Energy、Tempo、照合元のDebug情報を確認できる。通常の表面や曲情報の下にはBadgeを出さない。

## Badge

- 標準分類10項目のみを対象とし、スコア **0.68以上**、降順、最大3個。
- 同点は下表の順で固定する。Energy、Tempo、additionalは分類Badgeにしない。
- 条件に達する分類がない／Tempoのみの曲は、弱い分類を推測せず「音楽特徴」という詳細ボタンだけを表示する。
- 特徴量自体がない曲では何も表示しない。通常画面に数値、Debug情報、「未解析」は出さない。
- 大きい文字で横幅に収まらない場合は縦配置へ切り替える。オーディオ情報の裏面は縦スクロールでき、アートワークの正方形領域内に収める。
- オーディオ情報／戻るボタンとBadgeは別々の操作対象とし、Badgeをタップした際はアートワークへ戻さず詳細を開く。

| 内部名 | 表示 |
| --- | --- |
| piano | ピアノ |
| ambient | アンビエント |
| electronic | エレクトロ |
| drumAndBass | DnB |
| aggressive | 力強い |
| calm | 穏やか |
| bright | 明るい |
| dark | ダーク |
| vocal | ボーカル |
| instrumental | インスト |

詳細ではスコアを整数%表示し、TempoはBPMで表示する。値がない項目は省略する。
スコアはBeta解析値であり、分類の確率や正解率ではない。
Debug情報はanalysisVersion、relativePath、fileSize（正確なbytes）、duration（秒）、contentHash有無、解析日時、Import日時。

## 管理画面・永続化

- Library総曲数、紐付け済み曲数、未解析／未紐付け曲数、保存中のanalysisVersion一覧、最終Import日時を表示。
- 直近Importの総数・照合成功・未照合・曖昧・新規・更新・Skippedを保存して表示。
- Skippedは旧analysisVersionによる未更新。照合成功件数の内数。
- 未照合・曖昧の相対パス例は各先頭20件まで保存。詳細リンクから参照できる。誤マッチ修正機能はない。
- 既存の専用永続化ファイルへ任意のlastImportReportを追加。旧ファイル（reportなし）も読み込める。
- 削除は特徴量と直近Importレポートのみ。Libraryが空でも残存特徴量を削除可能。
- MacとのImport schemaVersion=1、Matching条件、Analyzerは変更していない。loudnessの独自フィールド追加もない。

## 即時反映・分離

再生画面と詳細画面は@ObservableのTrackFeatureStoreを参照する。
feature(for:)はTrack.IDによる辞書アクセス（平均O(1)）。Badge選定はその曲の固定10項目だけ。
保存成功後に索引を置換してObservationへ通知するため、Import・再Import・削除を再起動なしで反映する。
詳細を表示中も同じ索引を読み取る。音源の再読込、iPhoneでの音響解析、ハッシュ計算はない。

PlayerStore、AudioPlayerService、Queue、Shuffle、Now Playing制御、AudioSession、Background playback、
再生完了判定、PlaybackHistory、Selection Engineは変更しない。
再生関連差分は表示Viewのみ。Store参照は共通のオーディオ情報Viewに置き、再生操作は変更しない。

## 検証

自動テストの対象:

- 正常／不正JSON、schema不正、一致／未照合／曖昧
- Badgeの閾値・順序・上限・同点順・不正スコア除外
- Import → Matching → Store → Badge値の一連の読み取り
- Import・再Import・削除によるObservation通知
- 再Importの重複防止、旧VersionのSkipとレポート
- 実ファイルの永続化と再読込、旧永続化形式の互換性
- 未照合・曖昧のサンプル数上限
- コンパクト幅／大きいDynamic TypeでのBadgeレンダリング

実ライブラリ／実機で確認する項目:

1. まず10〜100曲で、パス・サイズ・長さと実際の曲が一致すること。
2. 再生中の曲を含むJSONをImport／再Importし、Badge・詳細・管理件数が更新されること。
3. 特徴量なし／全分類が閾値未満／長い曲名／大きい文字で、操作を妨げないこと。
4. 聴感と分類スコアの妥当性。特に派生スコア・DnBの過大判定。
5. 通常／作業用の再生・一時停止・曲送り・曲戻し・Shuffle・Queueが従来通りであること。
6. 実機のバックグラウンド、Lock Screen／Control Center／AirPods制御。Simulatorや表示単体テストだけでは保証できない。
7. 特徴量削除後も曲・Playlist・再生履歴・評価・お気に入りが保持されること。

実機へのインストールはこのフェーズの作業には含めない。

## 検証結果（2026-08-27）

- iPhone 17 / iOS 26.5 Simulator: XCTest 19件成功。
- Badgeの320pt幅・Light Mode、Accessibility 3・Dark Modeのレンダリング画像を目視確認済み。
- アートワーク裏のオーディオ情報とBadgeを360pt正方形のUIHostingControllerで描画し、画像を目視確認済み。
- Simulator Debug（arm64 / x86_64）: BUILD SUCCEEDED。
- 再生Store、AudioPlayerService、NowPlayingService、PlaybackHistoryの差分なし。
- 既存コードのSwift concurrency、AccentColor、AppIntents関連warningは残存。今回の特徴量追加コードにコンパイルエラーなし。
- 実際の再生・一時停止・曲送り・曲戻し・Shuffle・Queueの操作、実音源による聴感、実機Background／Lock Screen／AirPodsは未実施。上記実機チェックリストで確認する。

## このフェーズの変更ファイル

追加:

- MyMusic/Utilities/TrackFeaturePresentation.swift
- MyMusic/Views/Components/TrackFeatureBadgeView.swift
- MyMusic/Views/Player/TrackFeatureDetailView.swift
- MyMusic/Views/Player/AudioInformationView.swift（既存表示を抽出・共通化）
- MyMusicTests/TrackFeatureDisplayIntegrationTests.swift
- Documentation/TrackFeatureBeta3.md

既存フェーズから更新:

- MyMusic/Views/Player/NowPlayingView.swift
- MyMusic/Views/Player/WorkSizeNowPlayingView.swift
- MyMusic/Views/Settings/TrackFeatureSettingsView.swift
- MyMusic/Models/TrackFeature.swift
- MyMusic/Stores/TrackFeatureStore.swift
- MyMusic/Services/TrackFeatureImportService.swift
- MyMusic/Services/TrackFeaturePersistenceService.swift
- MyMusicTests/TrackFeatureTests.swift

Xcode project、App注入、Settings導線はフェーズ1の実装をそのまま利用。今回の変更対象外。
