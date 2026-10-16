# ハイライトの評価アイコンを統一

- HighlightTrackPageの独自評価アイコンをPlaybackPreferenceButtonへ置換。段階別色、数字、タップ時のbounce／触覚、グッド5以上のきらめきを共有する。
- 共通ボタンへ丸背景の表示optionを追加し、ハイライトの42pt円形背景と押下反応を維持。
- 保存・再生・選曲の処理に変更なし。View構成のみでアーキテクチャ変更なし。
- git diff --check成功。実機表示・操作は未確認、今回のデプロイは未実施。
- XCTest未実行。test端末の作成・削除0台。
- generic iPhone／埋め込みWatch Simulator Debug build: BUILD SUCCEEDED。
