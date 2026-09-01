# ライブラリ整理候補のPlayback Event比率判定

## 作業

- 直接選択とearly skip累計による候補条件を廃止し、終了理由を持つ直近20件までのPlayback Eventを使う比率判定へ変更した。
- 通常曲について、最低5件、ユーザーの「次へ」による途中スキップ率50%以上、平均再生率10%以下をすべて満たす場合だけ候補にする。既存`playCount`が0でもeventがあれば判定できる。
- Playback Eventへ`natural / user_skipped / other`の終了理由を追加した。「次へ」は再生秒数に関係なく、完走扱いでなければ`user_skipped`になる。停止、別曲選択、ライフサイクルflushは途中スキップにしない。
- SQLite schemaをversion 3へ更新し、`playback_events.end_kind`をnullable追加した。旧eventは不明のまま保持し、候補判定から除外する。
- 候補画面に判定対象件数、途中スキップ件数／率、平均再生率を表示する。

## 検証

- iPhone 17 / iOS 26.5 Simulatorで整理候補、Playback Event、SQLite永続化／v2→v3 migrationの対象XCTest 21件と、全XCTest 120件が成功した。
- Simulator Debug build、`swiftc -parse`、`git diff --check`が成功した。

## 制約

- 旧eventは終了理由を履歴だけから正確に復元できないため、新形式eventが5件たまるまで候補判定しない。
- 20分以上または作業用ジャンルの曲は通常曲向け10%基準から除外する。
