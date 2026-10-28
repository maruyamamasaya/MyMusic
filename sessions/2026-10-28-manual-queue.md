# 次に再生する Beta

- Context Guard: MATCH。Git rootはMyMusic。既存の多数の未コミット変更を保持。
- 発掘する音楽へ「次に再生する」タイルとManualQueueViewを追加。
- ManualQueueStoreが最大30曲のランダム候補・追加済みID・一時的な選曲sessionを管理。候補は現在のチューニングと通常ランダム再生適格性に従い、重みを付けず抽選する。更新時に同じ曲が再登場することはある。
- 最初の選択で既存queueを置換しshuffle／repeatをoff。以後は末尾へタップ順で追加、重複選択を防止。上部に現在曲と待機曲を表示。
- PlayerStoreへ手動開始／末尾追加APIと末尾自然終了状態を追加。終了後の追加だけを自動再生へ接続し、一時停止・通常resume時は再生位置を維持。
- ページ離脱では選曲sessionだけを破棄。再生queueは維持し、再入場後の最初の選択で再構築。外部queue編集後の次の選択も新規開始。
- CURRENT.md／ARCHITECTURE.md更新。永続化形式・音声仕様・署名設定に変更なし。

## 検証

- 指定iPhone 17e Simulator（EB3A49ED-6553-4D7E-B933-387951643EAB、iOS 26.5）を再利用。
- 指定destinationでDebug build成功。既存MusicHistoryViewのasync警告あり。
- PlaybackHistoryBehaviorTests 24件＋HomeCategoryTests 9件、計33件成功。新規2テストで置換・選択順・重複防止・終了停止・追加再開・一時停止・30候補・更新・再入場・通常resume後の追加を確認。
- 最初のテスト成功後、通常resume後の境界ケースを補強したため同じ関連33件を再実行し成功。
- 並列test無効。test端末作成0・削除0。XCTestDevicesの開始前／終了後UUID folderは双方0件、残存合計12 KiB。削除なし。
- git diff --check成功。専用lint設定なし。
- ログ: /tmp/mymusic-manual-queue-build.log、/tmp/mymusic-manual-queue-test.log。

## 未検証・制約

- 実画面・実音源を使う操作と実機は未確認、実機デプロイ未実施。
- 追加済みはsession内で保持し、既に聴き終えた同じ曲も再追加できない。ページを離れて新規開始すれば選択可能。
- 候補は手動更新かページ再入場で再抽選。画面表示中の同期変更による自動更新は行わない。


## Vesperaへのデプロイ

- ユーザーの明示依頼で実施。git status確認後、check-iphone.sh成功→deploy-iphone.sh実行。
- サンドボックス内の初回CoreDevice一覧取得はタイムアウト。権限を拡張した同スクリプトで接続を確認して成功。
- 対象: Vespera / iPhone 17e / UDID 00008150-000C54280E33401C。paired・Developer Mode enabled・connected。
- Project: MyMusic.xcodeproj、Scheme／Product: MyMusic、Configuration: Debug、Bundle Identifier: maruyama.MyMusic。
- Build・Install・Launchすべて成功。未コミット変更を保持し、署名・識別子・Deployment Targetは変更していない。
- ログ: /tmp/mymusic-manual-queue-vespera-deploy.log。
- 実機の外観・選曲操作の確認はユーザー待ち。今回のデプロイではtest未実行、test端末作成／削除なし。
