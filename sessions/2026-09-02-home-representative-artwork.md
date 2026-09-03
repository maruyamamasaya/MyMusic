# ホーム代表アートワーク修正

## 作業

- GitHubの`origin/main`をfetchし、ローカル`HEAD`と同じ`f72c1a1`であることを確認した。
- 「マイミュージック」のアートワーク候補を通常再生対象かつアートワークを持つTrackへ限定した。
- ホーム表示セッション開始時と表示中の約60秒ごとだけ代表Trackを再選定し、ライブラリ変更で現在値が無効になった場合は即時に置換するようにした。
- 直前以外の候補がある場合は同じTrackの連続選定を避けるようにした。
- 即時ランダム再生では既存ロジックが生成したqueueの先頭へ表示中の代表Trackを置き、同Trackを後続から除外するようにした。
- Now Playing sheet表示中は更新Taskを止め、ホームへ戻った時に新しい表示セッションとして再選定するようにした。

## 検証

- `git diff --check`: 成功。
- 新規Policyについて、作業用Track除外、直前Track回避、代表Track先頭化と重複除去のXCTestを追加した。
- Simulator Debug build: CoreSimulatorの`simdiskimaged`停止とSwift macro pluginのmalformed responseにより失敗。今回の変更固有ではなく全`@Observable`型で失敗した。
- iOS Device Debug build: asset compileが同じCoreSimulator runtime不調を参照して失敗した。
- 変更したSwift 4ファイルの構文parse: 成功。
- `Track`、`AudioFormat`、新規Policyの独立typecheck: 成功。
- XCTest実行はCoreSimulator不調のため未実施。

## 未解決

- CoreSimulator復旧後に全XCTestとDebug buildを再実行する。
