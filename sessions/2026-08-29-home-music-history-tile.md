# ホーム「音楽史」タイル

日付: 2026-08-29

## 作業

- ホームの「アクティビティ」に「音楽史」タイルを追加した。
- 既存のアクティビティタイルと同じサイズ・構成を使い、暖色系グラデーションと`calendar.badge.clock`を設定した。
- タイルから、設定画面でも使用している既存の`MusicHistoryView`へ遷移するようにした。
- アクティビティのタイル構成を確認するUnit Testを追加した。

## 検証

- iPhone 17 / iOS 26.5 Simulator: 追加testを含むXCTest成功。
- Debug Simulator build: `BUILD SUCCEEDED`。
- `git diff --check`: 成功。
- 既存のSwift 6移行警告とAsset Catalog警告は残るが、今回の変更による新規warningは確認されなかった。

## 文書判断

- Store / Service、データフロー、永続化は変更していないため、`ARCHITECTURE.md`とADRは更新していない。
