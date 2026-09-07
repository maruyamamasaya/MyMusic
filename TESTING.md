# 検証

## 標準の検証入口

macOS ではリポジトリ直下から実行します。

```sh
bash scripts/verify.sh --fast
bash scripts/verify.sh
```

`--fast` は Xcode を使わず、production の Python unittest と Analytics control test を実行します。Full validation はこれに Analytics browser regression と iOS Simulator XCTest を追加します。ツールや依存関係がない状態は成功ではなく、環境準備が必要な失敗として扱います。Analyzer の PoC 評価 suite は依存関係が別で production regression ではないため、意図的に含めません。

専用 lint と CI workflow は現在設定されていません。

## 検証レベル

| Level | When | Required checks |
| --- | --- | --- |
| Fast | 実装中、Analyzer または Analytics の変更 | Production Analyzer unittest、Analytics unittest、Analytics controls test |
| Full | Swift、Watch、共有契約、永続化、構造変更の完了前 | Fast + Analytics browser regression + `xcodebuild test` |
| Device | リリース候補または明示的な導入依頼 | Full + 実機 iPhone/Watch の再生、lifecycle、接続、file access、データ安全性の確認 |

## 変更別の検証マップ

| 変更種別 | 必要な検証 |
| --- | --- |
| 文書・導線のみ | link 確認と `git diff`。command/script 変更時は Fast も実行 |
| Swift UI、Store、Service、Model | 対象 XCTest + 完了前に Full |
| WatchConnectivity または Watch UI | `WatchPlaybackMessageTests`、関連 Watch test、Full。リリース候補では実機確認 |
| 再生、永続化、import/export、identity | 対象 XCTest、Full、互換性と非破壊 migration の確認 |
| Analyzer | 関連する `analyzer/tests` + Fast |
| Analytics API、importer、SQL、Web UI | 関連する `analytics/tests` + Fast。操作・layout 変更時は browser regression |
| 境界をまたぐ JSON/schema | Analyzer、Analytics、関連 XCTest、Full |
| 構造・project 設定 | Full と対応する architecture / operations 文書の更新 |

## 個別コマンド

```sh
PYTHONPATH=analyzer python3 -m unittest discover -s analyzer/tests -v
(cd analytics && python3 -m unittest discover -s tests -v)
(cd analytics && node --test tests/controls.test.cjs)
(cd analytics && node tests/browser_ux.cjs)
xcodebuild -project MyMusic.xcodeproj -scheme MyMusic -sdk iphonesimulator \
  -configuration Debug CODE_SIGNING_ALLOWED=NO test
```

Xcode、Simulator、Node、Python 依存関係が使えない場合は、未検証範囲を正確に session へ残します。実機導入は verify ではなく [OPERATIONS.md](OPERATIONS.md) に従います。
