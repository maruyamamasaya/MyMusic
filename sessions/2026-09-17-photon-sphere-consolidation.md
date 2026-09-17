# Photon Sphereへの統合と下側の粒子表示

- ユーザーの指示でAurora Sphereを選択肢から外し、Photon Sphereを唯一の球体表現にした。Pulse Neon、Blue Cosmos、薄明は維持。
- 保存済みの`appearance.visualWorldStyle = living-aurora`、およびLiving Auroraテーマからの初期選択はPhoton Sphereへ読み替え、保存値を`simple-dark`へ正規化する。アプリ全体のテーマは変更しない。
- Metal／CanvasのAurora Sphere専用描画分岐を除去した。
- 球体下端の粒子に暗い前景gradientが重なることを避けるため、gradientの透明部分を画面高さの62%から76%まで延ばした。曲情報とコントローラーには個別の黒い背景がある。
- 旧選択値の移行testを追加した。`generic/platform=iOS`のDebug buildと、既存iPhone 17e Simulatorでの当該testが成功。`git diff --check`も成功。画面上の見え方と実機の熱・電力は手動確認が必要。
