# Mac Analytics ジャンル表示プリセット管理

## 結果

- Local／Desktop Analyticsへ「ジャンルプリセット」画面を追加し、一覧、作成、編集、削除確認、上下移動、JSON Import／Exportを実装した。
- `genre_display_presets`をMac上で編集した正本、`source_records`をImport原本provenanceとして分離した。旧`source_records`の有効なプリセットはmigration marker付きで一度だけbackfillする。
- Importは`mymusic.genre-display-presets` version 1文書全体を厳密検証してから1 transactionでmergeする。同名は既存IDを維持して更新し、新規名は末尾へ追加、既存ID衝突時はUUIDを再発行、文書にない既存項目は維持する。
- 未分類設定の`true`／`false`／省略、Libraryにないジャンル、配列順をImport／編集／Exportの往復で保持する。通常候補から`作業用BGM`と`ハイレゾ`を除外する。
- Tracks画面上部へプリセットをタグ表示し、選択した通常ジャンル、未分類、固定分類でLibrary曲を絞り込めるようにした。手動検索条件とはANDで組み合わせる。
- TracksのGood／Bad編集を任意値selectから1クリック±1へ変更し、-10／+10で該当ボタンを無効化した。
- iPhoneのApplication Supportへは直接書き込まず、`MyMusic-Genre-Display-Presets.json`だけを交換境界とする。

## 検証

- `cd analytics && . .venv/bin/activate && python -m unittest discover -s tests -v`: 59件成功。
- `cd analytics && node --test tests/*.test.cjs`: 19件成功。
- 一時SQLiteと実ブラウザでLibrary JSON Import、候補表示、2件の作成、編集、並べ替え、JSON Exportを確認した。埋め込み検証ブラウザがdownload後のnative file chooser／confirmを自動操作できなかったため、削除とExport JSON再Importは同じ保護APIで実行し、内容と順序の復元をブラウザ表示で確認した。
- 埋め込みブラウザにnative `<dialog>` APIがないことを確認し、aria付き通常DOM modalへ変更して互換性を確保した。
- 一時SQLiteの実ブラウザでTracks上部の「すべて」「集中」タグ表示を確認した。タグ選択のAPI意味とJavaScript wiringは自動テストで確認した。

## 未検証

- pywebviewでpackagingしたmacOS `.app`自体の起動と、OS native file pickerを使った専用Importボタンの自動操作は未実施。ブラウザ版の同じ画面、Import API、JavaScript handler、JSON round-tripは検証済み。
