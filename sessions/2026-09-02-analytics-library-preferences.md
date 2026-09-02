# Analytics Library / Playback Preferences

## 作業

- Analytics ImporterでPlayback Events、Library、Playback Preferencesの3契約をroot fieldから自動判別するよう拡張した。
- `library_tracks`と`playback_preferences`を追加し、Track IDでupsertする。Import履歴へdata kindと更新件数を追加し、既存v0 DBは起動時に列を追加する。
- Library snapshotの再Importでは、完全に検証できたsnapshotから外れた曲を非表示化し、Raw rowは削除せず保持する。
- DashboardへLibrary曲数、お気に入り数、Good／Bad登録数・分布を追加した。
- Tracksを未再生曲を含むLibrary基準へ拡張し、Good／Bad、お気に入り、Genre等のmetadataと期間別再生統計を表示する。

## 検証

- JSON自動判別、Library／Preferences保存、重複、更新、不正評価値、3データのTrack ID結合、未再生曲、Library snapshot差分、v0 DB migration、APIを含むPython unittest 11件が成功した。
- Python compileallとJavaScript構文確認が成功した。Uvicornをloopbackの検証用port 8876で実起動し、画面、health、Dashboard、Tracks APIが200で新fieldを返すことを確認した。既定8766は既存processが使用中だったため変更せず残した。
- Swift側の追加変更はないためXcode buildは対象外。

## 制約・未解決事項

- AnalyticsからMyMusicへの書き戻しは行わない。
- Preferences exportに含まれないTrackは、明示的な0ではなく未取込として表示する。
