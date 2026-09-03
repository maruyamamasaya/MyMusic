# Analytics Libraryジャンル一覧

## 作業

- Data Sourcesへ「ジャンル（Library集計）」を追加した。
- 専用JSONや永続tableは追加せず、現在Libraryの`genre`から都度導出する。
- iOSと同様に`;`とNULで分割し、trim、空要素除外、曲内重複除外を行う。
- GenreランキングとInsightsのGenre変化集計にも同じ分割規則を適用した。
- RankingsへArtist／Genreフィルターを追加し、曲・Artist・Album・Genreの全ランキングへ共通適用した。
- フィルターは単独・併用でき、再生回数／再生時間の切替と期間指定を維持する。

## 検証

- 複合ジャンル、重複、NUL区切り、未設定、GenreランキングをAnalytics unittestへ追加した。
- Analytics unittest 32件成功。
- `node --check analytics/web/app.js`成功。
- `git diff --check`成功。

## 制約

- 大文字小文字や表記揺れは統合しない。
- ジャンル一覧はLibrary snapshot由来であり、ジャンル表示プリセットJSONを正本にしない。
