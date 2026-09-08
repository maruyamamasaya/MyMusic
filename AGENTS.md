# MyMusic AI 開発ガイド

このファイルは、AI エージェントが MyMusic の作業を安全に再開するための入口です。現在の製品状態は [CURRENT.md](CURRENT.md)、実装構成は [ARCHITECTURE.md](ARCHITECTURE.md)、判断の理由は [`decisions/`](decisions/)、作業記録は [`sessions/`](sessions/) を正とします。

## Project Context

- **Project Name:** MyMusic
- **Purpose:** 手元の音源を不要に変換せず、探す、整理する、再生することを中心にした、個人利用向けの iPhone ローカル音楽プレイヤー。
- **Primary Stack:** Swift、SwiftUI、Observation、AVFoundation を中心とする iPhone / Apple Watch アプリ。補助領域として、Mac 上で音源特徴量を生成する Python CLI Analyzer、書き出した JSON を分析する Python / FastAPI / SQLite の Local Web Analytics と JavaScript の Static Web Analyticsを含む。
- **Main Domains:** Files / iCloud Drive からの音楽ライブラリ管理、metadata と Track Identity、ローカル音源再生と queue、検索、お気に入り、プレイリスト、再生履歴と選曲、Highlight / Mood Station、音響特徴量と音量補正、データ import / export と backup、Apple Watch リモコン、ローカル分析。
- **Expected Work:** 上記のアプリ機能、品質、テスト、Apple プラットフォーム連携、Analyzer / Analytics、既存 JSON 契約、関連文書や開発スクリプトの保守、および MyMusic の目的に沿う新機能の段階的な追加。これは固定的な機能ホワイトリストではない。
- **Clearly Unrelated Examples:** 別製品名を前提とする EC サイトや業務 SaaS の画面、MyMusic に存在しない別サービス固有の Next.js route や DB table、別ゲーム固有の scene / character / game logic、別リポジトリ固有の class・file・directory を複数指定する変更。`Python`、`JavaScript`、`API`、`SQLite`、`Docker`、`Swift` などの一般語が一つ現れるだけでは無関係と判断しない。

## Project Context Guard

すべてのユーザー要求について、実装、ファイル操作、依存追加、またはコマンド実行を始める前に、要求と上記 Project Context の整合性を次の3段階で判定します。この確認は作業開始時の必須ゲートですが、正当な新機能を既存機能の列挙だけで拒否するものではありません。

### MATCH

MyMusic、その構成要素、または目的に沿う保守・機能追加と明確に関連する要求です。通常の調査・実装・検証へ進みます。

### UNCERTAIN

MyMusic で実現できる可能性はあるものの、新技術、新領域、大きな構成変更、または不足した文脈のため即断できない要求です。拒否せず、まずこのリポジトリ内の文書、コード、履歴を read-only で追加確認し、その根拠から MATCH または MISMATCH を再判定します。必要なら実装前にユーザーへ確認します。迷う場合は MISMATCH ではなく UNCERTAIN とします。

### MISMATCH

別プロジェクト名、別製品固有の機能・class・file・directory、明確に異なる platform など、複数の矛盾した signal から別プロジェクト向けだと高い確信で判断できる要求です。単一の keyword や一般技術名だけでは MISMATCH にしません。

MISMATCH の場合は直ちに停止し、ファイル変更、新規ファイル作成、package 追加、DB 変更、destructive command、commit、push を行いません。回答には次だけを簡潔に示します。

- **Current Project:** MyMusic
- **Reason:** MISMATCH と判断した理由
- **Conflicting Prompt Elements:** prompt 内の具体的な不一致要素
- **No files were modified.**

## Repository Boundaries

- 作業開始時に `git rev-parse --show-toplevel` で現在の Git root を確認し、想定する `/workspace/MyMusic`（環境が異なる場合は、この `AGENTS.md` を含む MyMusic repository root）と一致することを確認します。
- 原則として現在の Git root 内だけを読み書きし、隣接 directory や別 repository を勝手に変更しません。明示的なユーザー依頼がある場合だけ、対象と境界を再確認して例外とします。
- Git root が想定と一致しない、または対象 file が境界外を指す場合は変更を止め、誤った repository で続行しません。
- MISMATCH 判定後は、Git root 確認を含む追加 command も実行しません。

## 作業開始時

1. この `AGENTS.md` と Project Context を読む。
2. 要求を Context Guard で MATCH / UNCERTAIN / MISMATCH に判定する。
3. MATCH、または UNCERTAIN の read-only 追加調査を行う場合だけ、Git root と Repository Boundaries を確認する。
4. `CURRENT.md` で現在の状態、優先事項、既知の制約を確認する。
5. `ARCHITECTURE.md` で責務、データフロー、永続化境界を確認する。
6. タスクに関係する ADR だけを `decisions/` から読む。
7. 関係する既存コード、テスト、詳細資料、Git 履歴を調査する。

すべての資料を無条件に読む必要はありません。コードと文書が矛盾する場合、コードを現在状態の重要な一次情報として確認しますが、それが意図された仕様だとは推測しません。不明点は不明と記録してください。

## 基本方針

- MyMusic は iPhone 向けの個人用ローカル音楽プレイヤーです。音源を不要に再エンコード、トランスコード、ビットレート低下、サンプルレート変更しません。
- Swift、SwiftUI、Apple 標準フレームワークを優先し、明確な利益を説明できない外部依存を追加しません。
- View → Store → Service → Model / Apple Framework の責務分離を守ります。View にビジネスロジックや AVFoundation 操作を置かず、再生処理は `AudioPlayerService` に隔離します。
- Store は Observation を可能な限り使用し、Model は UI ロジックを持ちません。適切なら `Identifiable`、`Hashable`、`Codable` を採用します。
- iPhone、Light/Dark Mode、Dynamic Type、片手操作を前提に、SwiftUI と SF Symbols を使った簡潔で余白のある UI にします。過剰な固定寸法や Apple 固有資産・ブランドの模倣を避けます。
- 一ファイル一責務を優先し、複雑な View は `MyMusic/Views/Components/` 等へ分割します。

## 実装時

- 推測だけで変更せず、既存実装と履歴を調査してから最小の変更を行います。
- 既存アーキテクチャ、データ互換性、完成基準版との整合性を確認します。
- 無関係な変更、不要な再設計、重複する Model / Service を混ぜません。
- セキュリティ、ファイルアクセス、権限、署名を安易に弱めません。
- エラーを隠すだけの暫定修正を恒久対応として扱いません。コンパイルエラーは原因を特定して修正します。
- ライブラリ、検索、再生、お気に入り、プレイリスト、データ管理の既存フローを回帰させません。
- 新機能は一つずつ小さな Beta として実装・検証・文書化し、安定後にのみ基準版へ昇格します。
- Streaming、Navidrome / OpenSubsonic、オフラインダウンロード、クロスフェード、ReplayGain 等は明示的に依頼されるまで実装しません。

## Git と Xcode

- 明示的な依頼なしに Bundle Identifier、Signing、Development Team、Deployment Target、App Icon 設定を変更しません。
- `.DS_Store`、`xcuserdata/`、`DerivedData/`、解析出力、キャッシュ、大容量の生成物をコミットしません。追跡解除時もローカル生成物は保持します。
- `MyMusic.xcodeproj/project.pbxproj` の不要な変更を避け、Xcode File System Synchronized Groups を尊重します。
- ソース、設定、schema、小さな意図的 fixture は追跡対象です。

## 検証と Definition of Done

開発タスクの終了前に、実際の変更に該当する項目を原則実施します。

1. 必要な Unit / Integration Test を実行し、妥当なロジックには有意なテストを追加する。
2. プロジェクトに存在する lint を実行する（現在、専用 lint 設定は確認されていない）。
3. プロジェクトに存在する typecheck を実行する（Swift は Xcode build、Analyzer は Python test/import で確認する）。
4. Swift の意味ある変更では既存 project / scheme を build し、`BUILD SUCCEEDED` を目指す。
5. `git diff` と `git status` で意図しない変更・生成物がないことを確認する。
6. 文書更新の要否を判断する。
7. 現在状態が変わった場合は `CURRENT.md` を更新する。
8. 構造・データフローが変わった場合は `ARCHITECTURE.md` を更新する。
9. 長期的に重要で根拠のある設計判断が生じた場合だけ ADR を追加する。
10. `sessions/YYYY-MM-DD-<topic>.md` に作業、検証、不明点、未解決事項を簡潔に記録する。
11. 未解決事項を `CURRENT.md` または session に記録する。

存在しないコマンドや無関係な検証を形だけで実行しません。標準コマンドは次の通りです。

```sh
xcodebuild -project MyMusic.xcodeproj -scheme MyMusic \
  -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build

PYTHONPATH=analyzer python -m unittest discover -s analyzer/tests -v
```

Xcode を利用できない環境では、その制約と未検証範囲を明記します。

## iPhone 実機デプロイ（明示依頼時のみ）

通常の開発・Simulator 検証には適用しません。「Vspera へデプロイ」など物理端末への導入を明示された場合のみ、次の順で行います。

1. 作業ツリーを変更せず `git status` を確認する。
2. `./scripts/check-iphone.sh` を実行する。
3. check 成功後だけ `./scripts/deploy-iphone.sh` を実行する。
4. project / workspace、scheme、product、Bundle Identifier、端末名と UDID、Build / Install / Launch の結果を報告する。

既定端末名は完全一致の `Vspera` です。別名はユーザーが明示した場合のみ `DEVICE_NAME` で指定します。デプロイだけの依頼は、アプリ、UI、署名、識別子、Team、Deployment Target の変更を許可しません。未コミット変更を破棄せず、そのまま build します。失敗時は原因を先に報告し、安全で小さなスクリプト修正を超える変更の前に停止します。

## 作業終了時の報告

追加・変更ファイル、アーキテクチャ変更、テスト / build 結果、重要な制約を簡潔に報告してください。
