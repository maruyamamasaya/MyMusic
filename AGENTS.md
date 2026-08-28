# MyMusic AI 開発ガイド

このファイルは、AI エージェントが MyMusic の作業を安全に再開するための入口です。現在の製品状態は [CURRENT.md](CURRENT.md)、実装構成は [ARCHITECTURE.md](ARCHITECTURE.md)、判断の理由は [`decisions/`](decisions/)、作業記録は [`sessions/`](sessions/) を正とします。

## 作業開始時

1. この `AGENTS.md` を読む。
2. `CURRENT.md` で現在の状態、優先事項、既知の制約を確認する。
3. `ARCHITECTURE.md` で責務、データフロー、永続化境界を確認する。
4. タスクに関係する ADR だけを `decisions/` から読む。
5. 関係する既存コード、テスト、詳細資料、Git 履歴を調査する。

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
