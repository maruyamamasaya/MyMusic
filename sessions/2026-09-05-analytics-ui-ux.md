# Web Analytics UI/UX Beta

## 調査と変更

既存コード、CURRENT／ARCHITECTURE、ランキングの前回更新記録、Git履歴を確認し、取込済みSQLiteの一時コピーを使って全7画面を調査した。実データにはArtist候補が1,109件あった。

| 課題 | 対応 |
| --- | --- |
| 大量のArtist／Genreをプルダウンで探す必要がある | 検索可能な候補選択UI。NFKC・英字大小正規化、複数語AND、完全一致／前方一致優先、最大30候補、個別解除、キーボード操作 |
| 条件変更後に古いリクエストが後勝ちする | ページ単位のAbortController、古い応答の抑止、読み込み表示、古い結果の操作無効化 |
| APIエラーが非表示の日付入力領域に隠れる | 各画面の見える位置でエラーと再試行を案内 |
| 日付入力や集計対象の理解が難しい | カレンダー入力、日付範囲検証、JSTと適用条件の要約 |
| 4列ランキングで曲名が省略される／下の種類へ移動しづらい | 通常2列、広い画面4列、スマホ1列。名前を折り返し、種類別表示切替 |
| Tracksの列が多く、横スクロール中に曲を見失う | 基本／詳細切替、固定見出しと曲名列、表内スクロール、行hover |
| Data Sourcesで数千件をページ送りして探す | SQLで全件を対象に名称／補足情報を検索。検索後の件数・紐付け件数・ページングを一致させる |
| 1ページ以下では検索結果件数がわからない | 0件を含む件数・表示範囲の常時表示、ページ番号の直接入力 |
| スマホでナビ名が消え、検索フォームがはみ出す | 名前付き横ナビ、可変グリッド、折り返し、共通フォーカス表示 |
| 指標の意味が曖昧 | Overviewの全体Library値を区別。Artist再生回数の誤った「曲」単位を修正。Historyの欠損詳細値を0にしない |
| Insightsの続きで現れる曲のリンクが動かない | イベント委譲で追加行もTracksへ移動し、URL履歴にも反映 |
| ファイル選択をキーボード操作しづらい | file inputのフォーカス経路を保持し、ドロップ領域にフォーカスリングを表示 |

候補選択のキーボード／ARIA設計は[W3C APG Combobox Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/combobox/)を参照した。

## 変更範囲

- `analytics/web/index.html`、`app.js`、新規`controls.js`／`experience.css`
- `analytics/app/main.py`／`queries.py`: Data Sourcesに検索引数を追加。LIKE特殊文字のエスケープ、parameter binding、検索後の件数とページング。
- `analytics/tests/test_analytics.py`、新規`controls.test.cjs`／`browser_ux.cjs`
- CURRENT、ARCHITECTURE、Analytics READMEを更新。
- iOSコード、音源、JSON契約、DB schemaは変更なし。新規production依存なし。

## 検証

- Analytics Python unittest: 45件成功（検索・全件ページング・紐付け件数・LIKE文字のリテラル検索の追加2件を含む）。
- Node検索ロジックテスト: 4件成功。
- Playwright + Chrome: 2,000候補、NFKC／複数語検索、キーボード選択、候補0件、Escape、個別解除、ランキング種類切替、遅延した旧応答、503から再試行、日付逆転、詳細指標、検索結果0件を確認。
- 全7画面を1440／768／390px幅で検証。ページ全体の横はみ出しなし、JavaScript例外なし。
- 実データコピー上の画面キャプチャでOverview、検索候補、ランキング、Tracks等を目視確認。
- `node --check`、Python compile、`git diff --check`成功。
- 初回Pythonテストは作業ディレクトリが異なりimportに失敗したため、READMEのanalyticsディレクトリから実行し直して成功。
- agent-browser CLIは未配置。既存Playwright runtimeとChromeを代用。テスト・画像・DBコピーは`/tmp`に配置し、元データには書き込んでいない。
- Swift変更なしのためXcode build／Analyzerテストは対象外。

## 制約

- ランキングは引き続き上位50件。候補の検索は正規化するが、選択後のAPIフィルターは従来どおりLibrary値の完全一致。
- 通常ページ間の条件はメモリ内で維持する。期間・検索条件自体のURL保存は未対応。
- 音楽史の月内サブ画面は従来の個別読込経路。画面全体の新旧リクエスト制御とは別経路として残る。
- Chromeで確認済み。Safari／VoiceOver実機の検証は未実施。

## ローカル反映

通常サーバーの起動コマンドと作業ディレクトリを確認して再起動し、従来の`http://127.0.0.1:8766`へ反映した。通常URLでも実データの候補検索とData Sources検索APIのHTTP 200／検索0件を確認した。検証用コピーは別ポート8877で使い、検証後に停止する。

## 表スクロールの再調整

Tracks／Data Sourcesの30行表に`72vh`の高さ制限を設けた結果、ページと表に別々の縦スクロールが生じ、sticky見出し・先頭列が行へ重なる問題があった。高さ制限とsticky指定を削除し、30行をページ本体の単一縦スクロールで閲覧する構成へ変更した。列数が多い場合の横スクロールは維持する。

- 実データでTracksは表の`clientHeight`／`scrollHeight`がともに1960px、Data Sourcesはともに2005pxとなり、表内の縦スクロール領域がないことを確認した。
- 両画面で見出しと先頭列のcomputed `position`が`static`であり、固定要素と行が重ならないことを確認した。
- ページ全体は900pxのviewportに対して2456px／2509pxとなり、30行とページ送りを単一のページスクロールで閲覧できる。
- ブラウザ回帰は全7画面・1440／768／390px幅で成功し、JavaScript例外なし。Python unittest 45件も成功した。
