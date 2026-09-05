# Track firstSeenAt

`firstSeenAt` は、MyMusicが論理Trackをライブラリscanで初めて確認した絶対時刻である。音楽ファイルの作成日・コピー日・更新日ではなく、ファイル自体の最終更新時刻である `modificationDate` とは別の値として扱う。

## 値の決定と互換性

- 1回のscan開始時に基準時刻を1つ取得し、そのscanで新規作成した全Trackへ同じ値を設定する。
- 既存の `library-index.json` またはidentity registryにfieldがない場合は `nil`（追加日時不明）とする。現在日時、`modificationDate`、再生履歴から補完しない。
- 通常の再scan、metadata・ファイル内容・更新日時の変更、Analyzer結果の更新では値を変更しない。
- path、resource identifier、file size＋duration、fingerprintの既存Identity照合で同じTrack IDを復元した場合、identity registryに保存した `firstSeenAt` も復元する。現在のfolder snapshotに同じIDがあれば、そのTrackの値を優先して維持する。
- scanがcancelまたは失敗した場合、scan中のidentity registry変更を開始前のmemory snapshotへ戻す。完成したlibraryを既存の保存経路でcommitするまでは `library-index.json` に反映されない。

## 削除後の再追加

folder snapshotから削除されたTrackもidentity registryのRecordは削除されない。後日の追加時にpath、resource identifier、file size＋duration、またはfingerprintでそのRecordを一意に復元できれば、Track IDと `firstSeenAt` を維持する。registryが失われた、または安全に一意照合できず新規Recordとなった場合は、再追加scanの基準時刻を新しい `firstSeenAt` とする。legacy Recordの `firstSeenAt == nil` は照合できても不明のまま維持する。

## 保存・Export・Analytics

- 正本はfolder別snapshotを保持する `library-index.json` 内のTrackで、削除後のIdentity復元用コピーを `track-identities.json` にも持つ。
- `MyMusic-Library.json` version 1は後方互換なoptional `firstSeenAt` をISO 8601で出力し、不明時はfield欠落として扱う。`MyMusic-Library.md` は `FirstSeenAt` を表示し、不明時は空欄にする。
- AnalyticsはLibrary import時にtimezone付き日時を検証し、SQLiteのnullable `library_tracks.first_seen_at` へUTCで保存する。NULLは「追加日時不明」であり、古い曲ではない。将来の期間条件では `IS NOT NULL` を明示して対象を選ぶ。
- Playlist、Playback History/Event/Preference、Track Features、Volume Normalization、Equalizer、Genre preset、Settingsの各契約には追加しない。これらはTrackの初回認識時刻を所有せず、Playlist importはTrack objectの追加fieldを無視してTrack IDだけを解決する。
- AnalyzerとSemantic Analyzerの音響特徴量schemaには追加しない。両者はLibrary exportを入力契約として使用せず、専用のfeature/scope JSONだけを扱う。

Homeの「最近追加した曲」は、現在時刻から14日前（境界を含む）から現在までの`firstSeenAt`を持つ通常再生対象曲を既存のPreference＋Overplay weightでシャッフル再生する。`nil`、未来日時、14日より前、作業用Trackは対象外とする。検索、Highlight、Discovery補正には使用しない。
