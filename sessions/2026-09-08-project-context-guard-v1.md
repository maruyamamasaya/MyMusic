# Project Context Guard v1

## 作業

- README、AGENTS、CURRENT、ARCHITECTURE、SOURCE_INDEX、主要 directory、manifest の有無、Git root と履歴を確認した。
- ルート `AGENTS.md` に、既存の iPhone アプリだけでなく Analyzer、Local / Static Web Analytics、Apple Watch まで含めた Project Context を追加した。
- 各要求を実行前に MATCH / UNCERTAIN / MISMATCH へ分類する軽量な Context Guard と、Git root 外・別 repository の変更を防ぐ Repository Boundaries を追加した。
- 一般技術名だけでは拒否せず、複数の project 固有 signal が揃った場合だけ MISMATCH とすることで誤検知を抑えた。

## 検証

- `git diff --check`
- `git diff -- AGENTS.md sessions/2026-09-08-project-context-guard-v1.md`
- `git status --short`

文書のみの変更であり、アプリ、Analyzer、Analytics の test / build は対象外と判断した。

## 未解決事項

- なし。v1 は外部 API、分類 CLI、AI 実行 wrapper を追加しない文書ベースの guard とする。
