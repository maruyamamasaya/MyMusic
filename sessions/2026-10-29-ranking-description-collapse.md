# 全期間ランキングの説明折りたたみ

- MyMusicにMATCH。Git root・status・CURRENT／ARCHITECTURE・既存Viewを確認し、他の変更を保持。
- ArtistRankingViewの全期間対象説明を既存の「総合点の計算方法」DisclosureGroup内へ移動。初期閉のため部門／方式切替から順位をすぐ確認できる。
- 集計・配点・カード・Weekly・保存形式・構造の変更なし。ARCHITECTURE更新不要。CURRENT更新。
- 指定iPhone 17e Simulator destinationでBUILD SUCCEEDED。初回は他ビルドのbuild.dbロックで失敗、再試行成功。
- git diff --check成功。表示文の移動のみのためtest未実行、専用lintなし。
- test端末作成／削除0台、XCTestDevices合計12K。実機未反映、実表示未確認。
