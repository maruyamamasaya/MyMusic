# Playlist JSON往復の重複・タグ保全調査

要求: MyMusic→HomeStereo→MyMusicの反復でPlaylistが増える原因とタグを横断調査。Context GuardはMATCH。両Git rootを確認し、共通契約revision 2の本文がcmpで一致することを確認した。既存の未コミット作業には変更を加えていない。

## 確認した実装事実

- MyMusicのMusicDataExportServiceはplaylistID、createdAt、updatedAt、kind、tagsをJSON v1へ出力する。しかしMusicDataImportServiceのPlaylistImportDraftはID・日時を持たず、parseJSONObjectもそれらを読まない。DataManagementViewはdraftをPlaylistStore.importPlaylistへ渡し、同関数は毎回createPlaylistを呼んでUUIDを発行する。同一JSONの再Importだけでも新規Playlistが増える。名前や曲の一致による重複判定もない。
- HomeStereoのLibraryRepository.mergeMyMusicPlaylistsはmymusic_playlist_id、または未接続のローカルid一致で既存を探し、同じ外部IDを更新する。ExportはmyMusicPlaylistID ?? idを使う。MyMusicで新IDになった複製はMacにとって別Playlistである。削除や絞り込みなしに全件往復すると、MyMusicの件数は1→2→4→8と増え得る（コードからの帰結、実機での件数計測ではない）。
- HomeStereoはtagsをDTO・交換Model・Playlist Model・SQLite tags_json・Exportで保持する。PlaylistStoreのrename/add/move/removeは既存Modelを更新するためtagsを維持する。PlaylistsViewとStoreにタグ編集／filterの入口は確認できない。「UI未対応」と「データ未対応」は異なる。Mac新規作成はtags=[]。M3U8はJSON Identity／タグ保持の代替ではない。
- MyMusicのタグは最大20個、1個40文字、空白正規化とcase/幅/発音区別の重複除去がある。JSON取込でtags欠落／型不一致は[]。Macから不適合なタグが来れば完全な文字列往復は保証されない。
- Mac Importは未照合／競合Trackを除外し、解決済みtrackIDsで既存playlist_itemsを削除・再挿入する。transactionはあるが、未照合参照をPlaylistへ保持する実装ではない。Mac Exportも未接続／競合曲を除外する。件数報告は耐久的な参照保管の代わりにならない。
- MyMusic Importは重複Track ID、未照合曲、kind非互換曲を除外する。Exportも与えられたtracks索引で解決できない参照をcompactMapで除外する。Macは全Playlistに通常／作業用／ハイレゾ混在を許すが、MyMusicはkind.acceptsで絞るため意味が一致しない。Mac連携詳細文書には旧来の種別分離説明が残り、CURRENT／現行Storeと一致しない。
- MyMusicはcreatedAt／updatedAtを読み込まず新しい時刻にする。searchDefinition、description、artworkIdentifierはPlaylist JSONに含まれず、検索Playlistの条件も復元されない。
- Macの同一ID更新は受信値でname、日時、kind、tags、曲一覧を置換し、双方編集の競合を保全しない。MyMusicに単純upsertだけを追加すると、部分snapshotや古いtags=[]が既存内容を損なう可能性がある。

## テストの不足

MyMusic PlaylistTagTestsはparse結果のtagsを確認するが、Storeまで通した再Importの件数・IDを確認しない。Mac MyMusicPersistenceTestsには同一ID再Importの冪等testがあるが、未照合曲の除外を期待しており無欠落往復の保証ではない。両アプリをまたぐ反復fixture試験は今回確認できていない。既存testの実行・実機データとの照合は行っていない。

## 対策の順序

1. 両端末の現状と過去のExport原本を保全する。既存重複を名前だけで自動削除／統合しない。IDを失った複製は確実な元ID対応がなく、タグ・曲順・編集差分を比較する必要がある。
2. MyMusic JSON取込でIDと日時を保持し、同じID／同じ内容を再適用しても件数・内容を変えない。IDなし旧形式の新規作成と区別する。異内容は上書き前に差分・旧値・原本を保全する。
3. 未照合曲と種別非互換曲の順序付き参照を保持し、部分取込で完全な既存Playlistを縮めない。Mac側の既存置換経路も対象。DI-006／DI-007と関連。
4. タグ非対応UIでも受信タグを保持することを明文化し、空配列による明示削除と欠落を区別する。Macのタグ管理UI追加は別の製品変更として扱う。
5. 両側の実保存を通して3往復以上のfixture試験を行い、Playlist数・ID・曲順・未照合参照・tags・kind・日時、双方編集、保存失敗を確認する。

## 作業範囲と未検証

調査記録のみ追加。アプリ、データ、共通契約、隣接Gitのファイルは変更していない。利用者の実JSON／実DBとインストール済みbinaryは確認していないため、実データ固有の重複数・既に失われた参照は不明。build／XCTestは未実行、test端末の作成・削除は0。ストレージの測定・削除も行っていない。
