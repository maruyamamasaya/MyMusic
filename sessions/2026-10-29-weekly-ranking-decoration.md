# Weeklyの説明折りたたみ・順位別装飾と余白

- MyMusicにMATCH。Git root・作業ツリー・CURRENT／ARCHITECTURE・既存Viewを確認。他の未コミット変更を保持。
- Weeklyの長い対象説明・前週比凡例を既存「総合点の計算方法」DisclosureGroupへ移動（初期閉）。期間・週／方式切替の下からランキングへ進める。説明文に更新タイミングも明記。
- 1位：王冠・金色系・濃度28％・Artwork約60pt・縦padding20pt・下間隔16pt。
- 2位：メダル・銀青・20％・約54pt・17pt・14pt。
- 3位：メダル・銅色・14％・約48pt・15pt・12pt。
- 4〜10位：紫・6％・約46pt・14pt・10pt。
- 11位以降：既存の装飾なし・44pt Artwork・12pt padding・10pt間隔を維持。全順位とも既存横長2行構成、順位によって縦高が段階的に変わる。
- ArtworkはScaledMetric基準の倍率でDynamic Type対応。固定カード高や影・blur・animationは追加しない。20組追加・LazyVStack・集計・全期間ランキングは維持。
- 対象View2ファイル、CURRENT／ARCHITECTURE、session更新。構造／永続化の変更なし。

## 検証

- 指定iPhone 17e Simulator UDID destinationで最終BUILD SUCCEEDED。
- git diff --check成功。専用lintなし。表示変更のみのため今回はtest未実行。
- test端末作成／削除0台、XCTestDevices合計12K。実画面・実機は未確認、未デプロイ。
