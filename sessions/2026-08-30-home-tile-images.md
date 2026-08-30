---
status: completed
date: 2026-08-30
---

# ホームタイルのローカル背景画像

## 作業

- ホームの「ライブラリ」5タイルと「アクティビティ」2タイルに、固定ベース名のローカル背景画像を設定できるようにした。
- `MyMusic/Resources/HomeTileImages/`を設定場所とし、画像ファイルはローカル運用のためGit追跡対象外にした。
- `.jpg`、`.jpeg`、`.png`、`.heic`を順に探索し、画像がない場合やdecodeできない場合は既存のdestination別グラデーションを表示する。
- カスタム画像には暗いreadability maskを重ね、タイトル、説明、SF Symbolは白で表示する。
- 同フォルダの`README.md`にファイル名一覧、対応拡張子、画像サイズの目安、元の配色へ戻す方法を記録した。

## 検証

- ライブラリ／アクティビティの全タイルが安定した画像ベース名へ対応し、他カテゴリには適用しないXCTestを追加した。
- iPhone 17 / iOS 26.5 Simulator向け`build-for-testing`が成功した。
- iPhone 17 / iOS 26.5 Simulatorの全XCTestが成功した。
- build productでfilesystem synchronized groupのresourceがbundleへ取り込まれることを確認した。loaderは階層保持とresource直下へのflattenの両方を探索する。

## 制約・未検証

- 利用者が用意した実画像でのトリミングと視認性は、画像ごとに実機またはSimulatorで確認が必要。
- 既存のAccentColor asset warningとSwift 6移行warningは今回の対象外。
