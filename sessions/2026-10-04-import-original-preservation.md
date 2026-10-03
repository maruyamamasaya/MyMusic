# DI-001 Playback Events原本保全

- 要求はMATCH。既存未コミット変更を保持し、最初の小さな対策としてMyMusicのPlayback Events Import確定時だけ元JSONを保管する処理を追加した。
- 追加: PlaybackEventImportArchiveService actor。SHA-256名、atomic保存、read-back完全一致、既存file非上書き。Storeは期間filter前のDataを渡し、原本保存失敗では履歴Importを呼ばない。cancel／Previewでは保存しない。
- 両Gitへ同じ課題一覧を追加しAGENTSから参照。共通契約をrevision 2へ同期。MyMusicのCURRENT／ARCHITECTUREも更新。HomeStereoのコードは変更しない。
- 検証: generic Simulator Debug BUILD SUCCEEDED。既存iPhone 17e（EB3A49ED-6553-4D7E-B933-387951643EAB）1台、並列無効でPlaybackEventImportTests 8件成功。未照合原本保持と原本保存失敗で履歴非更新を検証。Service実ソースをSwiftで直接compileし、元bytes一致、重複保管、破損拒否、既存原本非上書き、書込失敗を検証した。
- 最初のsandbox内buildはcache権限で失敗したため、承認された通常Xcode cacheアクセスで再実行した。build log: /tmp/mymusic-import-archive-build.log、test log: /tmp/mymusic-import-archive-tests.log。
- ストレージ: test前のXCTestDevices UUID一覧と各容量をtool出力へ記録、baseline一覧は/tmp/mymusic-archive-xctest-before.txt。開始前21 folder、計90,913,760 KiB。終了後も同じ21 folder・90,913,760 KiB（約86.7 GiB）。今回新規作成0、削除0。既存Xcode dataは削除していない。
- 両契約・両課題一覧の本文一致、各git diff --checkと変更範囲を確認。専用lintはなし。
- 制約: 原本の再適用UI、HomeStereo側／他文書の保管、受領確認、原本の外部backup、容量管理、実機UIは未対応。内部原本保持だけで無消失保証を達成したとは扱わない。DI-001はMyMusic対象範囲のみ完了。
