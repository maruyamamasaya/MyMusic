# MyMusic Analytics Web

MyMusicが書き出したJSONを、サーバーへ送らずブラウザメモリ内だけで分析する静的Webアプリです。DB、ログイン、環境変数、ビルド、外部依存はありません。既存のFastAPI / SQLite版は隣の`analytics/app`、`analytics/web`にそのまま残ります。

一般公開版: https://mymusic-analytics.maruyama-001.chatgpt.site

## 起動

リポジトリルートから次のように静的ファイルを配信し、`http://127.0.0.1:8000`を開きます。

```powershell
python -m http.server 8000 --directory analytics/web-static
```

任意の静的ホスティングにも`web-static/`の内容をそのまま配置できます。CSPの`connect-src 'none'`により、画面からのHTTP API、WebSocket等の接続を禁止しています。

## データを開く

MyMusicの「設定」→「データ管理」→「Analyticsと同期」からJSONを書き出します。「すべてまとめて書き出す」で得たZIPは先に展開してください。画面の「分析データを開く」から、次のJSONを複数選択できます。

- `MyMusic-Library.json`（曲情報）
- `MyMusic-Playback-Events.json`（再生イベント）
- `MyMusic-Playback-Preferences.json`（Favorite / Good / Bad）
- `MyMusic-Track-Features.json`（音楽特徴量）

加えて、既存Analyticsと同じVolume Normalization、Playlists、Equalizer、Genre Display Presets JSONも判別し、データソースとして表示します。Web版独自の入力形式は追加しません。

既存契約を変更せず、ファイル種別をroot fieldから判別します。Playback Events v1、Library v1、Preferences v1/v2、Track Features v1に対応します。不正JSON、未対応version、必須field不足は画面内に表示し、受理済みデータは維持します。同じevent IDはメモリ内で重複排除します。

## 構造とプライバシー

```text
JSON (File API)
  → Web Adapter (core.js / parseDocument)
  → Normalized Data (tracks, playEvents, features, preferences)
  → Analytics Core (core.js / aggregate, featureStats)
  → Web UI (app.js)
```

すべての状態はページ内のJavaScript変数だけにあり、ページを閉じるか「データを閉じる」で破棄されます。`fetch`、`XMLHttpRequest`、`WebSocket`、Beacon、IndexedDB、LocalStorage、SessionStorageは使用しません。音源、Artwork、SQLite、ZIPを読み込む機能もありません。

## テスト

```powershell
node --test analytics/tests/web_static_core.test.cjs
```

Local版と共通化できる将来境界は、入力contract、Normalized Data、Early Skip等の指標定義です。今回はLocal版のSQLと保存境界を変更せず、Web版のAdapter / Coreを独立させています。
