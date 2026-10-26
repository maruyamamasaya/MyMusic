# ライブラリのタグ年別表示

- ユーザー合意：ライブラリへ追加し、追加年ではなくタグ年で分類する。
- LibraryViewに年の入口、YearsViewに年と曲数、新しい年順、不明は末尾。既存SongsViewへ遷移する。
- LibraryYearServiceが1〜9999を有効年とし、nil・0・負数・範囲外を不明へ分類。LibraryStoreの表示snapshot適用時に再生成する。既存のジャンル除外と通常ライブラリ境界を維持。
- 検証：実際のTrack／AudioFormat／分類Model・Serviceをswiftcでコンパイルし、XCTestと同じ検証内容をpreconditionに置換した一時harnessで2ケース確認。XCTest自体は実行していない。変更Swiftの構文parse、git diff --check成功。
- 指定UDIDのSimulator確認はCoreSimulatorService接続拒否。指定destinationでbuildを試行したが、ZIPFoundation取得のDNS失敗で停止。iPhone／Watchの型検証・UI実操作は未確認。端末・runtime変更なし。
- XCTest未実行。作成／削除test端末0台。XCTestDevices容量は未計測。
- 既存の他作業の未コミット変更は保持。署名・project設定・音源・metadata・JSON契約変更なし。
