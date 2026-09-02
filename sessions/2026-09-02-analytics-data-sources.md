# Analytics Data Sources

## 作業

- Track Features、Volume Normalization、Playlists、Equalizer、Genre Display PresetsのImportを追加した。
- Data Sources画面で種類別に閲覧し、曲単位データのLibrary照合状況を表示する。
- EQとジャンルプリセットは曲へ結合せず、設定スナップショットとして保持する。

## 検証

- 5形式の判別・保存・更新・API・Library照合をPython unittestへ追加し、全14件が成功した。
- JavaScript構文とPython compileallが成功した。
- Uvicornを検証用port 8877で起動し、画面とData Sources APIのHTTP 200を確認した。ブラウザ自動化CLIは環境に存在しなかったため、HTTP応答とJavaScript構文で代替確認した。

## 制約

- AnalyticsからiOSへ書き戻さない。
- Track IDが異なる曲のFingerprintによる自動統合は行わない。
