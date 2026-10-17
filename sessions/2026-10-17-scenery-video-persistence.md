# 車窓動画のアプリ内登録 — 2026-10-17

## 変更

- Files／iCloud Driveで選んだ動画をアプリ内へ変換せずコピーし、次回から自動復元して毎回ランダム位置から再生する。
- actorのSceneryVideoLibraryServiceとnonisolated CodableモデルRegisteredSceneryVideoを追加。Application Support/MyMusic/SceneryVideoへUUID名の動画とcurrent.jsonを保存する。
- security scope＋NSFileCoordinatorで読み、MainActor外でcopyItem、コピー先の映像・有限の正duration・playableを確認後manifestをatomic保存する。失敗時は旧manifestを変更しない。未確定コピー／旧コピーの掃除はbest effort。
- Storeが初回復元／登録とAVFoundation再生を調整。変更失敗時はエラーを表示して旧登録を再読込する。保存済み素材自体の再生失敗では登録を自動削除しない。
- 「動画の管理」に元ファイル名・容量、変更、登録解除を追加。解除は確認後にアプリ内のコピーを削除する。元のFiles／iCloud素材を削除しない。コピー中は登録操作を無効化。
- 18fps・無音・音楽pause連動・background停止・曲変更時の映像継続は維持。
- CURRENT／ARCHITECTUREを更新。既存外部backupのpath一覧は変更せず、この動画とmanifestはアプリ独自backup対象外。

## 検証

- 最終変更後のiPhone／埋め込みWatch generic Simulator Debug build: **BUILD SUCCEEDED**。
- 保存モデルのdefault MainActorに由来するCodable警告をnonisolatedモデルへ分離して解消。既存のAVMutableVideoComposition deprecated APIは維持。
- `scripts/check-scenery-video.swift`を拡張し、実Service＋合成H.264素材で成功:
  - 既存のランダム範囲・無音・18fps・seek・pause・item解放・不正URL拒否。
  - コピーと元動画のbytes一致。
  - 元動画移動後に、新Service instanceで登録をdisk復元し保存先で再生。
  - 不正動画による変更失敗で旧登録と旧コピーを保持。
  - 正常変更で新動画を登録し旧コピー削除。
  - 解除後の登録／コピー削除と元動画のbytes保全。
- 再実行例:
  `swiftc MyMusic/Models/RegisteredSceneryVideo.swift MyMusic/Services/SceneryVideoService.swift MyMusic/Services/SceneryVideoLibraryService.swift scripts/check-scenery-video.swift -o /tmp/check-scenery-video`
  → `/tmp/check-scenery-video`。
- `git diff --check`成功。専用lintなし。
- XCTest／Simulator testは未実行。test端末の作成0、削除0。XCTestDevices残容量12K。DerivedData削除なし。

## 残る確認・制約

- 保存対応版も下記の通りVesperaへデプロイ済み。保存・開き直し時のランダム再生・変更・解除は、下記のユーザー報告により実機確認済み。
- iCloud未ダウンロード動画の取得、容量不足、大容量動画、コピー中のアプリ終了、上記4項目以外の実機UI・background復帰は未検証。登録時は旧動画と新コピーの両方を保持する容量が必要。
- copyItemは途中の進捗／即時cancelを提供しない。画面を閉じるとTask cancellationを検知できた時点で未確定コピーを掃除する。process強制終了では未登録コピーが残る可能性があり、次回登録成功時または登録解除で掃除する。
- 登録解除でmanifest削除後にファイル削除が失敗すると、未登録コピーが残る。エラーを表示し再度解除可能。旧コピーのbest effort掃除失敗もあり得る。
- 18fps提示とrenderScaleは、元ファイルの容量・decode負荷軽減を保証しない。


## 保存対応版のVesperaデプロイ

ユーザーの明示依頼でGit rootと未コミット変更を確認し、check-iphone.sh成功後にdeploy-iphone.shを実行。現在の作業ツリーを保持したままDebug build・install・launchがすべて成功した。

- Project: MyMusic.xcodeproj / Scheme: MyMusic / Product: MyMusic
- Bundle Identifier: maruyama.MyMusic
- Device: Vespera（iPhone 17e） / UDID: 00008150-000C54280E33401C
- Build: BUILD SUCCEEDED / Install: succeeded / Launch: succeeded
- アプリコード・署名・識別子・Team・Deployment Targetの追加変更なし。
- XCTest実行なし。test端末作成0／削除0、XCTestDevices残容量12K。Xcode data削除なし。
- デプロイ後の実機確認結果は下記を参照。アプリ再起動と元動画保持の個別結果は未記録。


## ユーザーによる実機確認 — 2026-10-17

Vesperaに導入した保存対応版について、ユーザーから次の4項目が「全部問題なく動いた」と報告された。

- 動画の保存。
- 車窓モードを開き直したときのランダム再生。
- 動画の変更。
- 登録解除。

この4項目を実機確認済みとする。アプリ再起動後の復元、オフライン、元動画保持、iCloud未取得素材、大容量素材、background復帰、発熱・電池消費は個別結果が示されていないため、この報告だけでは確認済みにしない。

記録作業ではCURRENTと本sessionのみ更新し、アプリコード・構造は変更していない。文書変更のためbuild／testは再実行せず、git diff --checkで確認。test端末の作成0／削除0。
