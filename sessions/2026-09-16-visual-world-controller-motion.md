# Visual World Beta 2 — 誤操作防止と動き

## 変更

- 背景のタップ、連続タップ、左右スワイプはコントローラー表示だけに変更。再生、曲送り、お気に入りは明示ボタンで実行する。長押しは0.85秒・移動許容18ptとし、揺れと触覚を伴って詳細を開く。長押しseekを廃止し、Sliderを維持。gestureをexclusiveにした。
- `VisualWorldController`を分離し、通常の前／再生／次と、スクロールできる詳細操作を提供する。従来の通常画面も維持。
- Lusion KAOS／Particle Love、Active Theory The Fieldの制作記事を調べ、音と形、粒子の奥行き、少ない情報表示を参考にした。リンクを設計書へ記載。素材・コードの流用はない。
- `VisualWorldScene`でテーマ別に光の帯、遠近感のある幾何学、軌道と粒子を描く。`VisualWorldDynamics`が音量のattack／release、短期と長期の差によるアクセント、ステレオ幅・左右の平滑化、復帰時に飛ばない描画時計を所有する。ビート／周波数検出ではない。
- `VisualWorldPaletteService` actorで24×24の縮小画像を色相群へ集計し、平均色による濁りを避けた。32件までのmemory cache。既存音声tap、再生エンジン、ファイル、JSON、Watch契約への変更はない。
- CURRENT、ARCHITECTURE、Themes、Visual World設計書を更新。

## 検証

- iOS Simulator generic destinationで署名なしbuild成功。途中のkeyframe closureに出たactor isolation warningはBoolを値captureする形に修正。AppIntents metadataの既存warningのみ。
- `VisualWorldDynamicsTests`の3件（音のattack／減衰、pause／resume、不正値）を実ソースに対するmacOS XCTest standalone harnessで実行、3件成功。通常のiOS test targetにも同じテストを追加した。iOS全体のxcodebuild testは未実行。
- 同じCanvasコードをmacOS SwiftUI ImageRendererで4テーマ描画し、画像を確認。40frameのGIFも生成した。出力は`/tmp/mymusic-visual-v2/`。固定の紫／シアンと模擬音量によるプレビューで、実際の曲との同期を示すものではない。
- 起動済みのiPhone 17 Pro Simulator（F26F773A-A316-4610-9228-84217FEEB82A）へbuildをinstallして起動確認。Libraryに音源が未登録のため、実再生のコントローラー操作は未検証。実機の長押し感度、触覚、長時間の描画負荷、VoiceOver／Dynamic Typeの手動確認は残る。
- XCTestDevicesは開始前にUUID directoryなし・合計12KB。新規test端末の作成／削除0件。既存Simulator1台を使用。DerivedData等は削除していない。
