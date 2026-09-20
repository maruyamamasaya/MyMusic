# Ignore local Xcode build output

- `.gitignore` にリポジトリ直下の `/build/` を追加した。Xcode の生成ファイル79件が未追跡として表示されていたため。
- 既存のソース・文書変更は保持した。生成済みの `build/` も削除していない。
- `git check-ignore` と `git status` で無視設定と変更範囲を確認した。コード変更はないためビルド・テストは実行していない。
