# Hi-Res直接出力のmain昇格

## 判断

- Tea ProのUSB接続で、専用Audio Queue経路による音源sample rateの直接出力が実機確認され、内蔵無音PCMによるrate準備を含めて安定してきたため、`codex/hires-direct-output-beta`を`main`へ昇格する。
- 通常AVAudioEngine経路は置換せず、ハイレゾ専用ライブラリと専用Now Playingを独立したまま維持する。
- 同じ実機確認済み作業状態に含まれる大規模ライブラリ向けcache、検索pagination、ホームsnapshot改善も同時に基準版へ含める。

## 最終確認

- Vespera（iPhone 17e）向けDebug build、install、launch成功。
- iPhone 17e / iOS 26.5 Simulatorで、Hi-Res分類・再生履歴・repeat／shuffle、通常ライブラリ分離、ホーム代表曲、scan互換性、検索・paginationの関連XCTest 38件が成功した。
- testは並列実行せず既存Simulator 1台だけを使用した。XCTestDevicesは開始前後ともUUID folder 0件、合計12KBで、新規test端末の作成・削除はなかった。
- ALACのシークはAudio File Servicesのframe-to-packet変換へ修正し、先頭へ戻る原因を除去した。実機での最終的なシーク操作確認は利用者確認を継続する。
