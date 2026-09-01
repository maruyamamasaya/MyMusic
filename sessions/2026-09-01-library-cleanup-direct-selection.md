# ライブラリ整理候補の直接選択判定

## 作業

- 再生開始区分へ`user_advanced`を追加し、「次へ／前へ」で移動した先を、ユーザーが曲を直接選んだ`manual`と区別した。
- ライブラリ整理候補はearly skip累計3回以上に加え、直接選択eventが1件以上ある曲だけを対象にした。
- event分類導入前でeventを持たない履歴は、既存`manualPlayCount`を互換fallbackとして維持した。SQLite schemaと既存の`manual / automatic`集計は変更していない。
- 空状態の説明を「曲を直接選んだことがある」へ更新した。

## 検証

- iPhone 17 / iOS 26.5 Simulatorで`LibraryCleanupCandidateServiceTests`と`PlaybackHistoryBehaviorTests`の14件が成功した。
- `swiftc -parse`と`git diff --check`が成功した。

## 制約

- 既存eventの`manual`には過去の「次へ／前へ」由来が含まれ、履歴だけから完全には復元できない。今後記録するeventから厳密に分離される。
