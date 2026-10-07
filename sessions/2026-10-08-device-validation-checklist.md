# 次回実機検証チェックリスト

- MyMusic保守としてMATCH。Git root一致を確認。既存の文書変更とAnalyzer等の未追跡ファイルは維持。
- ユーザー方針（個人利用で支障がなければ定量計測を急がない／ハイレゾは加工を加えない独立経路）をCURRENTへ記録し、冒頭にチェックリストへの入口を追加。
- Documentation/DeviceValidationChecklist.mdに通常再生、background／ロック／AirPods、Hi-Res／USB DAC切り替え、Watch、任意の性能計測、履歴／保全の確認と結果記録を整理。既存rate確認手順へリンク。全項目の即時実施は要求しない。
- アプリコード・アーキテクチャ・保存契約の変更なし。文書の差分・リンク先・git diff --checkを確認。build／testは実行せず、test端末作成0、削除0。XCTestDevices容量は未計測。
