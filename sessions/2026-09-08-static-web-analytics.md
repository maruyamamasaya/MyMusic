# Static Web Analytics

- `origin/main`をfetchし、cleanな`main`を`ea94530`へfast-forwardしてから着手した。
- 既存FastAPI / SQLite / Local UI、8種類のJSON Export、Analyzerの特徴量生成、関連文書とテストを調査した。
- `analytics/web-static/`へ依存なしの静的Web版を追加した。既存JSONをFile APIで読み、Adapter → Normalized Data → Core → UIの境界でブラウザ内集計する。

## Sites一般公開

- Sites用projectを作成し、`analytics/web-static/.openai/hosting.json`へproject IDと静的出力設定を追加した。
- `https://mymusic-analytics.maruyama-001.chatgpt.site`へ一般公開した。
- 公開対象は静的HTML、CSS、JavaScriptだけとし、runtime binding、DB、認証、upload APIは追加していない。
- 一般公開サイトで誤解を招かないよう、画面の`PRIVATE · CLIENT-SIDE`表記を`LOCAL DATA · CLIENT-SIDE`へ変更した。
- `node --test analytics/tests/web_static_core.test.cjs`を実行し、4件すべて成功した。

## Local版とのデザイン・規模統一

- 公開版をLocal版と同じ左サイドバー、黒基調＋ピンク／紫アクセント、カード・表中心の情報密度へ変更した。
- 概要、音楽史、インサイト、ランキング、曲ライブラリ、データソース、インポートの7画面へ揃えた。
- Web版独自の入力形式を作らず、既存Analyticsの8種類のJSON判別を維持するテストを追加した。
- JavaScript構文確認と`node --test analytics/tests/web_static_core.test.cjs`を実行し、5件すべて成功した。
- Sites version 2として同じ一般公開URLへ反映した。
- Dashboard、期間、Track Library、再生詳細指標、特徴量傾向、Preference、簡易Insights、不正入力エラーを実装した。通信はCSP `connect-src 'none'`でも禁止し、Storage APIは使用しない。
- 既存Local版、iOS、Analyzer、SQLite、JSON契約は変更していない。
- Node契約テストとブラウザでのJSON読込・主要表示・console errorなしを確認した。既存Python testは追跡済み`.venv`のPython実体がなく、bundled PythonにもFastAPI / compatible pydantic-coreがないため実行不能だった。
