# Desktop build artifact ignore

## 作業

- Analytics Desktopの`dist/`、`release/`、`out/`をGit管理対象外にした。
- Windows / macOS installer、Portable実行ファイル、Electron系package metadataとcacheの生成物をignore対象へ追加した。
- ソース、依存定義、build script、packaging設定は追跡対象のまま維持した。
- 今後の配布成果物はGitHub Releasesへ添付する運用をAnalytics READMEへ明記した。

## 確認

- 変更前に追跡済みbuild成果物を検索し、該当なしを確認した。`git rm --cached`は実行していない。
- ローカルの`analytics/dist/`、`analytics/build/`、仮想環境、生成specは削除せず保持した。
- `git status --short --ignored`で生成物がignoreされ、通常statusへ表示されないことを確認した。
