# 共通データ交換・保全契約

- 明示依頼によりMyMusicと別GitのHomeStereoのrootを確認し、両者のAGENTS／現在状態／architecture／交換コード・文書を調査した。
- 両repositoryへ同一revision 1の共通契約を追加し、各AGENTSから参照した。粒度、Canonical ID、原本保持、再送、競合、削除境界、受領確認、復元と互換fixtureの完成条件を記載。
- 未解決原本の耐久保持、受領確認、同一ID異内容、Playlist欠落参照の往復は未検証。HomeStereoのplayCount正本に関する文書矛盾も記録した。コード変更は行わず、無消失が実現したとは扱わない。
- 検証: 両契約本文一致とgit diff --check。文書のみのためbuild／test未実行、test端末作成・削除各0台。既存未コミット変更を保持した。
