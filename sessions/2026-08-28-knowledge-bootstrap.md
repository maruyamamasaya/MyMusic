---
status: completed
date: 2026-08-28
---

# AI 継続開発ドキュメント基盤の導入

## 調査範囲

- root `AGENTS.md`、`README.md`、全 tracked Markdown / JSON schema / example。
- `Documentation/` の Track Feature Beta 1 / 3 と `analyzer/README.md`。
- repository tree、Xcode project / scheme / target 設定、Info.plist、scripts、`.gitignore`。
- App composition、主要 Model / Store / Service / View、永続化、再生、library import、特徴量 import、Analyzer と tests。
- TODO / FIXME、package / Python dependency、CI / `.github` / docs / documentation の有無。
- Git log と、baseline、Beta、特徴量、実機 deploy に関係する履歴。

コード変更は行っていない。

## 作成・統合

- `AGENTS.md` を、開始手順、実装原則、Definition of Done、実機 deploy を含む入口へ刷新。
- 現在有効な状態・制約・次の action を `CURRENT.md` に集約。
- 現行の layer、composition、data flow、persistence、build / test 境界を `ARCHITECTURE.md` に集約。
- 明示的な既存文書と履歴から確認できた3判断だけを ADR 化。
- この session を初回の作業記録とした。

## 維持した資料

- `README.md`: 利用者向け概要、完成基準版と各 Beta の詳しい機能説明として独立価値がある。
- `Documentation/TrackFeatureBeta1.md`: import schema / matching contract の詳細資料。
- `Documentation/TrackFeatureBeta3.md`: 表示規則、検証項目、当時の結果の詳細資料。
- schema / example: machine-readable contract と意図的 fixture。
- `analyzer/README.md`: setup、CLI、運用、解析式の詳細な runbook。

新しい共通文書からこれらを参照し、機械的な移動・削除・重複コピーは行っていない。明確な廃止候補は確認できなかった。

## 不明・確認不能だった事項

- Deployment Target 26.5 を選んだ理由。
- App Store release、versioning、release / distribution 手順。
- CI / lint 方針（現在は設定自体がない）。
- 最新機能全体の実機回帰結果。特徴量資料には未実施項目が明記されている。
- 将来機能の具体的な優先順位と期限。

推測で補完せず、現在の制約として `CURRENT.md` に必要な範囲を記録した。

## 今後の確認

- 各 task の開始時に AGENTS → CURRENT → ARCHITECTURE → 関係 ADR → 関係コード / 詳細資料の順で読む。
- 実装後は CURRENT / ARCHITECTURE の「現在」が変わったかを判定し、この session のコピーではなく最新状態だけを反映する。
- 長期的で根拠のある判断だけ ADR にし、日々の作業は短い session に残す。
