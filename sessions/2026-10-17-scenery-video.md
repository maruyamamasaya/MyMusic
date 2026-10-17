# 車窓モード Beta — 2026-10-17

## 変更

- NowPlayingViewの電車ボタンから全画面へ。端末の既存回転設定で横向き表示、aspect fitで縦横比を維持。タップで操作を表示／非表示。
- Filesから動画1本を選択、毎回ランダム開始。曲変更で映像を飛ばさず、動画終端では先頭へ戻る。音楽再生／一時停止・次曲ボタンを既存PlayerStoreへ接続。
- SceneryVideoStore／Serviceへ状態・AVFoundation処理を分離。映像だけのcompositionとmuteを併用し、18fps設定。追加のAVAudioSession操作なし。
- background、音楽pause、picker表示中は映像をpause。閉じるとitemとscopeを解放。選択失敗・再生失敗を表示し、同じ動画の再選択も可能。
- 元動画の変換、アプリへのコピー、bookmark永続化なし。毎回Filesから選ぶ初期Beta。
- CURRENT／ARCHITECTUREを更新。恒久的な設計判断ではないためADR追加なし。

## 検証

- 最終変更後のgeneric iOS Simulator Debug build: **BUILD SUCCEEDED**（埋め込みWatch含む）。署名／識別子／project設定の変更なし。
- `scripts/check-scenery-video.swift`を実ServiceとmacOS向けにswiftcでcompileし実行成功。合成H.264動画で、ランダム範囲（長尺・短尺・不正値）、18fps設定、音声trackなし・mute、seek完了、pause、item解放、不正URL拒否を確認。
  - 実行例: `swiftc MyMusic/Services/SceneryVideoService.swift scripts/check-scenery-video.swift -o /tmp/check-scenery-video` → `/tmp/check-scenery-video`。
  - sandbox内の最初の試行はmacOS動画encoderを利用できず失敗。通常権限では保存した最終スクリプトが成功。
- `git diff --check`成功。専用lintなし。
- XCTest／Simulator testは未実行。test端末の作成0、削除0。XCTestDevices残容量12K。DerivedData削除なし。
- AVMutableVideoCompositionはiOS/macOS 26でdeprecated警告あり。既存deployment互換APIを使用している。

## 未検証・制約

- 実機での18fpsの雰囲気、回転・操作、音楽との同時再生、Bluetooth、background復帰、5時間動画、iCloud／File Provider、発熱・電池消費は未検証。デプロイは未実施。
- 18fpsは映像提示の設定。デコード負荷軽減の保証はなくcomposition分の追加処理もある。renderScaleを設定するが高解像度入力自体のdecode負荷は残る。
- 検証素材は合成の映像のみ。音声付き素材での実機無音確認は別途必要。
- 自動横向き固定・操作の時間経過による自動非表示・動画登録の永続化・複数動画は対象外。


## Vesperaへのデプロイ

ユーザーの明示依頼でGit root／未コミット変更を確認後、check-iphone.sh成功 → deploy-iphone.shを実行。sandbox内のCoreDevice接続はtimeoutしたため、通常権限で再実行し成功した。

- Project: MyMusic.xcodeproj / Scheme: MyMusic / Product: MyMusic
- Configuration: Debug / Bundle Identifier: maruyama.MyMusic
- Device: Vespera（iPhone 17e） / UDID: 00008150-000C54280E33401C
- Build: BUILD SUCCEEDED / Install: succeeded / Launch: succeeded
- アプリコード・署名・識別子・Team・Deployment Targetの追加変更なし。既存未コミット変更を保持。
- 実機での動画選択・18fpsの印象・音楽同時再生・発熱等はユーザー確認待ち。
- XCTest実行なし。test端末作成0／削除0。Xcode data削除なし。
