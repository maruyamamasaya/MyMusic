# Analytics Desktop pywebview Beta

## 作業

- 既存FastAPI / SQLite版をpywebviewで開くcross-platform launcherを追加した。
- OS標準Application Data配下へDesktop専用のSQLiteとImport原本を保存する。
- 空きloopback portを使用し、起動ごとのtoken cookieでDesktop APIを保護する。
- Window終了時にuvicorn serverを停止する。
- Windows用PyInstaller buildとmacOS用py2app buildを追加した。
- 配布resource探索をPyInstaller / py2appのbundle layoutへ対応させた。

## 検証

- Python unit / API tests: 52件成功（Desktop追加分6件を含む）。
- JavaScript tests: 9件成功。
- Windows PyInstaller onedir build成功。
- Windows packageの`--smoke-test`で同梱UIとserver起動・停止を確認した。

## 未検証・未対応

- macOS `.app` buildとWKWebView表示はWindows環境のため未検証。
- Windows / macOSのコード署名、Notarization、installer、自動更新は未対応。
- repository内の既存AnalyticsデータはDesktop保存先へ自動移行しない。
