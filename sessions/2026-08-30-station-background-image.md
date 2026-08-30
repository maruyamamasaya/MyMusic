---
status: completed
date: 2026-08-30
---

# ステーションのローカル背景画像

## 作業

- ステーション入口カードのローカル背景画像を`MyMusic/Resources/HomeTileImages/station-background.*`から読み込めるようにした。
- `.jpg`、`.jpeg`、`.png`、`.heic`に対応し、未配置または読み込み失敗時は従来のグラデーションを維持する。
- カスタム画像には暗いグラデーションを重ね、ラベルと説明を白系の表示へ切り替える。
- ローカル画像をGit追跡対象外とし、配置方法と画像の目安を同フォルダのREADMEに記載した。

## 検証

- ステーション画像の安定したベース名を確認するXCTestを追加した。
- iPhone 17 / iOS 26.5 Simulator向けの全XCTestとDebug buildが成功した。
- `git diff`と`git status`で意図しない変更がないことを確認した。

## 制約・未検証

- 利用者が用意する実画像のトリミングと文字の視認性は、画像配置後にSimulatorまたは実機で確認が必要。
