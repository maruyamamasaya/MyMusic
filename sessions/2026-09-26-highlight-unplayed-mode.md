# ハイライト未再生モード

## 作業

- ハイライトの選曲モードへ「未再生」を追加した。
- 未再生モードは通常のHighlight適格条件を維持し、その中からPlayback Historyの再生回数が0の曲だけを候補にする。
- 現在再生中のHighlightはモード切替時に維持し、後続queueだけを未再生曲で再構築する既存の切替動作を維持した。
- 未再生曲が存在しない場合は再生済み曲へfallbackせず、候補なしとする。

## 検証

- `HighlightSelectionPolicyTests`へ未再生曲だけを残す場合と、全曲再生済みで空になる場合のテストを追加した。
- `PlaybackSelectionPolicyTests`の全Highlightモード統合確認を、未再生モードの候補集合に対応させた。
- `HighlightSelectionPolicyTests`、`PlaybackSelectionPolicyTests`、`PlaybackSelectionIntegrationTests`の計29件がiPhone 17e / iOS 26.5 Simulatorで成功した。並列テストは無効、workerは1台に制限した。
- generic iOS Simulator Debug buildが成功した。AppIntents framework未使用による既存のmetadata extraction warningだけを確認した。
- テスト前後とも`XCTestDevices`内にUUID folderはなく、合計容量は12KBだった。新規test端末の作成・削除は0件。終了確認時に別の`xcodebuild`とSimulator processが実行中だったため、既存Xcode dataの削除は行っていない。

## 未解決事項

- 実機で5項目Segmented Pickerの小画面・Dynamic Type表示は未確認。
