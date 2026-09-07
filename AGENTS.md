# MyMusic: AI 作業ガイド

## 正本ドキュメント

MyMusic は iPhone 向け個人用ローカル音楽プレイヤーです。音源の不要な再エンコード、トランスコード、ビットレート／サンプルレート変更は行いません。

| 情報 | 正本 |
| --- | --- |
| AI 共通ルール | このファイル |
| 現在地・優先度・未解決事項 | [CURRENT.md](CURRENT.md) |
| 構造・保存境界 | [ARCHITECTURE.md](ARCHITECTURE.md) |
| コード探索の入口 | [SOURCE_INDEX.md](SOURCE_INDEX.md) |
| 検証方法 | [TESTING.md](TESTING.md) |
| 起動・実機導入・運用 | [OPERATIONS.md](OPERATIONS.md) |
| 重要判断 | [decisions/](decisions/) |
| 作業結果 | [sessions/](sessions/) |

`SOURCE_INDEX.md` はこのリポジトリの CODEMAP に相当する正本です。README は利用者向けであり、AI 規約の複製先にしません。

## 検索優先の作業

大量のコードや資料を順読しない。必要な情報だけを次の順で得ます。

```text
Request → AGENTS → CURRENT → 必要な設計資料 / SOURCE_INDEX
→ semantic search → exact / symbol search → 対象コード
→ 最も近い AGENTS → references → 関連テスト → 変更 → 検証
```

- 概念しか分からないときは利用可能なら semantic / repository search を優先する。
- 名前が分かったら symbol / references search、文字列なら `rg` / `git grep` を使う。
- 変更前に definition、references、tests、configuration、永続化または外部データ依存を確認する。
- 影響が不明な場合だけ呼び出し元・先を追加で読み、無関係なコードを広く読み込まない。
- 子ディレクトリを変更する前に最も近い `AGENTS.md` を読む。

## 共通変更規約

- 既存実装・テスト・必要な ADR を調べ、最小変更にする。大規模 rename、再設計、依存追加はこの目的だけでは行わない。
- セキュリティ、ファイルアクセス、権限、署名を弱めない。Bundle Identifier、Signing、Development Team、Deployment Target、App Icon は明示依頼なしに変更しない。
- 生成物、`DerivedData/`、`xcuserdata/`、キャッシュ、大容量データを追跡しない。`project.pbxproj` の不要な変更を避ける。
- ライブラリ、検索、再生、お気に入り、プレイリスト、データ管理を回帰させない。Streaming、Navidrome / OpenSubsonic、オフラインダウンロード、クロスフェード、ReplayGain は明示依頼まで対象外。

## 検証と文書更新

- 実装中は [TESTING.md](TESTING.md) の Fast validation、完了前は該当する Full validation を実行する。標準入口は `bash scripts/verify.sh`（`--fast` で軽量検証）。
- `git diff` と `git status` で意図しない変更・生成物を確認する。
- `CURRENT.md` は現在地、`ARCHITECTURE.md` は構造・データフロー、`SOURCE_INDEX.md` は主要入口・配置、`TESTING.md` は検証方法、`OPERATIONS.md` は運用手順が変わったときだけ更新する。
- 重要かつ将来の理解に必要な判断だけ ADR にし、各作業の終わりに `sessions/YYYY-MM-DD-<topic>.md` を簡潔に追加する。

## 実機導入（明示依頼時のみ）

[OPERATIONS.md](OPERATIONS.md) の手順に従う。既定端末名は完全一致の `Vspera`。未コミット変更を破棄せず、通常の開発・Simulator 検証では実機導入を行わない。
