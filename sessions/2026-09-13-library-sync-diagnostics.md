# ライブラリ同期の診断と完全再取得

## 作業

- Libraryの手動同期を、既存差分判定を使う「クイック同期」と、全曲のmetadata／Artworkを読み直す「メタデータと画像を再取得」に分けた。
- 完全再取得もTrack Identity registryを維持し、Track UUID、firstSeenAt、再生履歴・Preference・Playlist等との参照を変えない。
- Artwork identifierをTrack UUID固定値から画像content hash付きへ変更し、同じTrackの埋め込みArtwork更新がdisk cacheとSwiftUIの`task(id:)`へ反映されるようにした。
- 同期中のfolder名、総曲数、完了数、残数をLibrary画面へ表示した。directory列挙中は総数未確定として表示する。
- 完全再取得の取得済みTrackを10分有効のfolder別checkpointへ10曲単位で保存する。再実行ではpath・size・更新日時・UUIDが一致するentryだけを再利用し、完成libraryの永続化成功後にcheckpointを削除する。
- iCloud未download、directory走査、file属性、metadata読取の失敗を集計し、folder、件数、代表path、NSError domain／codeをpopupへ表示するようにした。
- 再同期開始時に以前のerror表示を消し、成功後も古いerrorが残る問題を修正した。

## 検証

- iPhone側のみを検証するため、既存Watch target dependencyとEmbed Watch Contentを一時的に外してbuildし、直後にproject設定を復元した。App Icon名もcommand line上だけ空指定した。`BUILD SUCCEEDED`。
- `TrackFirstSeenAtTests`を既存iPhone 17 / iOS 26.5 Simulator 1台、並列OFF、worker 1で実行し、追加したiCloud／metadata notice、完全同期／進捗、10分checkpoint再開のtestを含む7件すべて成功した。途中の1回は既存一時DerivedDataのbuild DB lockでtest開始前にcancelされたため、別の一時DerivedDataで再実行した。
- 通常scheme buildは既存Watch targetのAppIcon不足、`WatchKit`解決、`WCSessionDelegate`適合エラーで失敗する。今回変更したiPhone codeのbuild結果とは分離して記録する。
- XCTestDevicesは開始前・終了後とも新規UUID folder 0件、合計12KB。削除対象なし。既存Simulator processが動作中だったため既存dataには触れていない。

## 未解決

- iCloud Driveの実際の未download／同期遅延状態で、notice分類と表示文言が期待どおりになるかは実機確認が必要。
- complete同期は全取得可能曲を読むため、大規模libraryでの所要時間は実機計測が必要。
- checkpointは書込負荷を抑えるため10曲単位で保存するので、強制終了の位置によって最大9曲は再処理される。
