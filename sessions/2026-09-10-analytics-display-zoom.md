# Analytics display zoom

## 作業

- Local／Desktop版へ75／80／90／100／110／125／150%の全画面表示倍率を追加した。
- サイドバーの縮小button、倍率select、拡大buttonと、Ctrl／Command＋`+`／`-`／`0`を追加した。
- 許可した倍率だけをlocal storageへ保存・復元する。保存失敗時は100%で安全に動作する。
- pywebviewのpersistent web storageを有効にした。起動ごとのAPI tokenと分析データ保存境界は変更していない。
- 静的公開版はブラウザメモリ限定の既存方針を維持し、対象外とした。

## 検証

- JavaScript unit tests 12件成功（倍率level、境界、shortcutを含む）。
- Python unit／API tests 52件成功。
- Chrome／Playwright browser regression成功。倍率の保存・reload復元、Ctrl shortcut、75%でのTrack Library実効表示幅増加を確認した。
- 75〜150%の全倍率でInsights／Track Libraryにdocument-level横overflowがないことを確認した。
- 全7画面を1440／768／390pxで確認し、JavaScript error、load failure、document-level横overflowなし。

## 制約

- 情報量を優先する縮小表示でも、列幅を超えるtableは既存どおりtable container内の横scrollを使用する。
- macOS WKWebView実機での目視確認はWindows環境のため未実施。
