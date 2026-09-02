# Preference手動双方向連携

## 作業

- アプリへschema v2 Preference JSONの厳格なImport検証を追加した。未知field、UUID不正、重複、範囲外、Bool／構造不正はStore変更前に全件拒否する。
- 現在Libraryに存在するTrackだけを既存Preferenceへmergeし、atomic保存成功後にStoreへ反映する。未収録TrackとJSONにない既存Trackは変更しない。
- データ管理の再生データへ「再生傾向を読み込む」と件数結果表示を追加した。
- Analytics TracksでImport済みPreferenceのFavoriteとGood／Badを編集できるようにし、現在Libraryと照合できる有効UUIDだけをschema v2でExportする導線を追加した。
- Analytics編集は`playback_preferences` tableだけを更新し、Library／Playback Events等を変更しない。

## 検証

- `analytics/.test-venv/Scripts/python.exe -m unittest discover -s tests -v`: 16件成功（一時venvは検証後に削除）。
- `node --check analytics/web/app.js`: 成功。
- `git diff --check`: 成功（改行コード変換警告のみ）。
- Windows環境のためXcode build／MyMusicTestsは未実行。macOSで既存schemeのbuildとSwiftテストが必要。

## 未解決事項

- 実機／SimulatorでのfileImporter、結果alert、AnalyticsブラウザUIの操作確認は未実施。
