# 設定整理と再生時間カレンダー

- Context Guard: MATCH。Git rootを確認。開始時の作業ツリーはclean。
- 音楽特徴量の入口をデータ管理へ移動。聴きすぎ候補は合計曲数と一覧リンクに簡略化。View評価内で再生傾向analysisを共有。
- 分析に総再生時間とカレンダーへの入口を追加。選択日の月・週・日別値を終了済みeventのlistenedSecondsから開始日で集計。集計をServiceへ分離し、日別snapshot生成をMainActor外で実行。
- iPhone／埋め込みWatch generic Simulator Debug build: BUILD SUCCEEDED。初回のsandboxによるキャッシュアクセス失敗後、通常のXcodeアクセスで再実行。Section定義のcompile errorを修正して成功。
- Swift単独の集計チェック: 同日加算、月境界、週境界、空の日、非有限値除外、時間表示が成功。PlaybackDurationSummaryTestsへ期間境界と表示の回帰テストを追加。XCTest自体は未実行。
- xcodebuild testは実行せず、test端末作成／削除は0台。XCTestDevices容量は未計測（test未実行）。専用lintなし。git diff --check成功。
- 制約: 日跨ぎは開始日へ全時間を割当てる。旧履歴と再生中の未確定時間により全体値と期間別値は一致しない場合がある。既存schema、記録処理、他repositoryは変更なし。実機での見た目とDynamic Typeは未検証。
