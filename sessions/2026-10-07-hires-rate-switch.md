# Hi-Res Audio Queue rate切替

## 範囲・根拠

Context Guard MATCH。Git rootはMyMusic、branchはmain。既存の未コミット変更が多数あり、保持した。HEADのCURRENT.mdと作業ツリー文書、ADR-0007、HiResAudioQueueProbeService／HiResDirectOutputProbeStoreを確認した。通常backendへの拡張、履歴／Now Playing／EQ／normalizationの統合追加、実機デプロイは行わない。

192kHz／24bit ALACのTea Pro成功は既存の実機記録。2段階無音準備による全rate切替は未検証のまま。

## 変更

- 手動prepareでも前のキャンセル済みtaskの完了を待つ。stopでtask参照を即座に捨てず、停止直後の次要求もcleanup完了を待てるようにした。
- 無音queue準備中はstopからsessionをdeactivateせず、キャンセルによりqueueの同期stop／disposeが完了してからdeactivateする。失敗／キャンセル後もsession cleanupを試み、失敗をログに残す。
- category／希望rate設定をdeactivate後に移動。2回の準備と既存待機時間は変更しない。
- HiResRatePreparationへ順序付けを分離し、2回の順序、deactivate失敗時の打切り、待機中キャンセル、stop直後の別要求がcleanupを待つことをテストする。
- HiResRateSwitchログとDocumentation/HiResRateSwitchVerification.mdを追加。要求ID、phase、preferred／session／queue rate、route、stop／dispose／hardware読取OSStatusを記録。
- CURRENT.md／ARCHITECTURE.mdへ追記。既存の文書変更を保持。

## 検証

- 最終generic iPhone／埋め込みWatch Simulator Debug build: BUILD SUCCEEDED。
- 既存iPhone 17 Pro（F26F773A-A316-4610-9228-84217FEEB82A）1台、並列無効で対象XCTest 12件成功（新規4件、HiResPlaybackHistoryTests 8件）。
- 最初のsandbox内buildはXcodeキャッシュ権限で失敗し、権限付き実行で検証した。ログ追加後の明示self指定漏れを修正し、対象testと最終buildが成功。
- git diff --check成功。専用lint設定なし。既存の無関係な変更は保持。
- XCTestDevicesは開始前UUID folder 0件、終了後0件。新規作成／削除test端末0／0、残容量12KB。既存Simulatorを1台使用し、新しいSimulator／runtimeは作成しない。
- Tea Pro実機確認／Vesperaデプロイは未実施。

## 未解決

Tea Proで44.1／48／88.2／96／192kHzの上下両方向、初回接続、停止直後の再要求を確認する必要がある。固定90msのwarm-up観測はhardware安定の保証ではない。停止／解放エラーはログに残すが、失敗したhardware資源の解放を保証できない。rate一致はbit-perfectの保証ではない。
