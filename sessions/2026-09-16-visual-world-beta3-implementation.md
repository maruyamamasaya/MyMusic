# Visual World Beta 3 初回実装

## 変更

- VisualWorldAudioAnalyzer: 既存tapと共有するatomic単一slot／事前確保PCM、20Hzのserial解析、左右power加算FFT、24帯域、flux、4調波salienceとconfidence。短いbufferは蓄積、overflowはdrop、generationで古い結果を拒否。
- AudioPlayerService / PlayerStore: 解析購読、snapshot、表示session seed。既存音源処理・32区間表示・EQ・キューは維持。
- VisualWorldSimulation: 特徴量ごとの力・拘束・減衰、強い変位、イベント、不応期、有限の余韻。
- MetalView / Installation shader: 巨大な枠面・膜・弧、遮蔽、限定した一面の反射、発光／bloom。フレーム上限、解像度上限、GPU未完了最大2、低電力・thermal品質制御、Canvas fallback。
- Artworkのaccent・色占有率・無彩色fallback、曲変更の姿勢と色の補間、常時説明文を小さいellipsisへ変更。
- 設計書・CURRENT・ARCHITECTURE・ADR-0006を更新。新規package、署名、AppIcon、deployment設定、実機導入は変更なし。

## 検証

- `xcodebuild -project MyMusic.xcodeproj -scheme MyMusic -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO build`: BUILD SUCCEEDED。
- 指定の`-sdk iphonesimulator`形式では既存Watch AppIcon / WatchKitを誤ったSDKで処理するため、destination形式へ変更。設定fileは変更なし。
- Metal compilerが未導入だったため`xcodebuild -downloadComponent MetalToolchain`でApple公式Metal Toolchain 17F109を導入（download約688MB）。Simulator・OS runtimeは追加していない。
- `scripts/check-visual-world.sh`: macOS standalone XCTest 10件成功、失敗0。実ソースをコンパイルし、iOS test fileと同じテストを実行。iOS全test suiteは未実行。
- Mac GPUの実シェーダーで4テーマ×静穏／最大値を描画。20秒・30fpsの合成入力で実Simulationとshaderを通す動画を生成し、2／8／12／19秒frameを目視。音楽を流した実機の動画ではない。
- 検証出力 `/tmp/mymusic-beta3/`: `motion-study.mp4`、frame画像、build／testログ。生成物はrepoに追加していない。
- git diff --check成功。XCTestDevicesは開始前／終了後ともUUID folder 0件・合計12KB。test端末の作成0、削除0。DerivedDataは削除していない。

## 残る確認

- iPhone実機15分の連続再生、発熱・battery、Bluetoothの体感同期、操作の回帰。実機デプロイは未依頼のため未実施。
- FFT 2048点固定での高sample rate低域分解能。音程感は調波salienceの推定で、音名／多声旋律の認識ではない。
- 完全な物理光学やhistory textureは未実装。初回Betaの光学近似・慣性として記録。
