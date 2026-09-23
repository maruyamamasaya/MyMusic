# クイック同期の保持規則と大規模library I/O削減

## 調査結果

- Appの上書きdeployは同じBundle IDのcontainerを通常維持するため、deploy自体が毎回libraryをゼロから作り直す経路ではなかった。
- cache復元後の`TrackIdentityService.registerExistingTracks`が全Trackのresource valuesとfile resource identifierを読み、Identity JSONも毎回保存していた。約20,000曲ではcache復元でも全件I/Oになっていた。
- quick同期はdirectory列挙後にsize／更新日時を曲ごとに再取得していた。未変更曲のAVFoundation metadataは再取得していなかったが、file attributesは二重に参照していた。
- iCloud未download／file・directory読取失敗／metadata読取失敗のTrackが完成snapshotから欠落した。cache属性が不足するTrackは無条件で未変更扱いとなり、後日の変更を検出できない場合があった。
- complete同期は10曲ごとに、それまで取得した全checkpoint entryを単一JSONへatomic保存していた。2万曲では最大2,000回の累積再encode／全書込となり、初回scanより大幅に遅く発熱する二次的コストがあった。

## 変更

- directory列挙結果へsizeと更新日時を含め、quick差分判定で再利用する。
- cache属性が不足する場合はmetadataを再取得する。
- 一時的に取得できないfile／directoryとmetadata失敗は既存Trackを保持する。noticeがなく列挙から消えたfileだけを削除扱いとする。
- cacheからIdentityを登録するときはcache内属性だけを使い、音源へアクセスしない。registryに差分がない場合は保存しない。
- complete同期のcheckpointを100曲単位のJSON Lines追記へ変更する。再開時に最新entryへ1回だけcompactし、旧単一JSON形式も読み込む。

## 検証

- generic iOS Simulator Debug build: 成功。
- iPhone 17e / iOS 26.5 Simulator、並列OFF、worker 1で`TrackFirstSeenAtTests`と`TrackIdentityMoveTests`を実行し、16件すべて成功。
- test開始前の`XCTestDevices`はUUID folder 0件、合計12 KB。実機約20,000曲での時間計測は未実施。
- Vespera（iPhone 17e）向けDebug buildとinstallは成功。端末ロックにより自動launchだけ拒否されたため、ロック解除後の手動起動を確認対象とする。

## 未確認

- Vespera上のcold launch時間、quick／complete同期時間、発熱、iCloud未download時の曲数維持。
- quick同期は追加・削除検出のため全path列挙自体は行う。2万曲で残る主なコストはFile Providerを含むdirectory列挙と、変更曲だけのmetadata取得である。
