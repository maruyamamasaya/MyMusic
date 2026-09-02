# Analytics v0

## 作業

- `analytics/`を独立したFastAPI／SQLite／vanilla Web UIとして追加した。
- playback export JSON v1 schema、イベント単位検証、`eventId`重複排除、Raw JSON保持、Import原本archiveとImport履歴を実装した。
- 今日／7日／30日／全期間のDashboard、Tracks集計・検索、drag and drop対応Import画面を追加した。
- macOS／Windowsの起動script、固定依存、セットアップ・契約・運用READMEを追加した。

## 検証

- `analytics/.venv/Scripts/python.exe -m unittest discover -s tests -v`: 6件成功。
- Uvicornを`127.0.0.1:8766`で実起動し、`GET /`と`GET /api/health`が200、画面titleを返すことを確認した。
- Swift、Xcode project、`analyzer/`には変更を加えていない。Swift変更がないためXcode buildとAnalyzer testは対象外。

## 制約・未解決事項

- v0 JSON contractはAnalytics側で新規定義したもので、iOS export実装は今回の対象外。
- 認証を持たないローカル専用ツールのため、loopback以外へ公開しない。
- Analyzer特徴量との結合は将来のImporter／join境界だけを確保し、v0では未実装。
