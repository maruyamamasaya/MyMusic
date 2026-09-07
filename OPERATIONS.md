# 運用

## ローカル開発

- iOS / Watch build and test use `MyMusic.xcodeproj` / `MyMusic`; standard validation is in [TESTING.md](TESTING.md).
- Start local Analytics with `./analytics/start.sh` on macOS or `./analytics/start.ps1` on Windows. It listens only on `127.0.0.1:8766`; setup and JSON contract details are in [analytics/README.md](analytics/README.md).
- Analyzer setup, formats, exports, and Semantic workflows are owned by [analyzer/README.md](analyzer/README.md) and [analyzer/SEMANTIC_README.md](analyzer/SEMANTIC_README.md).

## iPhone への導入（明示依頼時のみ）

1. Preserve the worktree and inspect `git status`.
2. Run `./scripts/check-iphone.sh`.
3. Only after it succeeds, run `./scripts/deploy-iphone.sh`.
4. Report project/scheme/product, Bundle Identifier, device name and UDID, plus Build / Install / Launch results.

既定端末名は完全一致の `Vspera` です。別端末名はユーザーが明示した場合だけ `DEVICE_NAME` に設定します。導入依頼は、アプリコード、署名、identifier、team、deployment target の変更を許可しません。

## データ安全性

iOS, Analyzer, and Analytics own separate persistence. Analytics changes return to the app only through explicit JSON export/import; do not add automatic sync. Storage ownership is in [ARCHITECTURE.md](ARCHITECTURE.md).
