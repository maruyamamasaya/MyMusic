# Analytics ZIP一括書き出し

## 作業

- iOSの「Analyticsと同期」に、既存8種類のJSONを日付付きZIPへまとめる導線を追加した。
- JSON生成契約と個別共有は変更せず、圧縮だけを専用ServiceでMainActor外に分離した。
- ZIPFoundation 0.9.20をSwift Package Managerのexact versionで追加した。
- ZIP作成中は再操作を無効化してProgressViewを表示し、共有終了後は既存経路で一時ファイルを削除する。

## 検証

- iPhone Simulator向けDebug build: `BUILD SUCCEEDED`。
- `AnalyticsArchiveExportTests`: 8ファイルがZIP直下へ入ること、ZIPのUTType、日付付きファイル名を確認して成功。
- 既存のasset catalogとSwift concurrencyに関するwarningは残るが、今回追加箇所のwarningはない。

## 未解決事項

- 実機でFilesへ保存したZIPをPC版Analyticsへ取り込む手動確認は未実施。
