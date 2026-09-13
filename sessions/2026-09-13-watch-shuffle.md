# Apple Watch シャッフルリモコン Beta

- Context Guard: MATCH。Git rootとcleanな開始状態を確認。
- Watch右上の将来枠をshuffle入口へ変更し、通常／お気に入り／未発見再生の一覧を追加。
- WatchShuffleKindのProperty List契約を追加。WatchSessionManagerは処理中・失敗を表示し、多重タップを抑止。成功返信でNow Playingへ戻る。
- MyMusicAppが既存LibraryStoreをWatch接続へ注入。iPhoneのPlayerStoreは通常／お気に入りにpreferenceWeightedShuffle、未再生にdiscoveryPlayTracksを再利用。生成済みqueueを順に再生し、DiscoveryのPreferenceのみ・最大30曲を維持。
- 未読込／対象なしはqueueを変更しない。既存playback taskの完了とrequest IDを確認して成功／失敗を返信する。
- Watchへのlibrary・履歴複製、選曲計算、音源再生は追加していない。署名・project設定変更なし。

## 検証

- `xcodebuild -project MyMusic.xcodeproj -scheme MyMusic -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO build`: BUILD SUCCEEDED（iPhone／Watch）。最終ガード追加後も成功。
- 標準の`-sdk iphonesimulator`指定はWatch AppIconに適用できず失敗。destination指定に変更して解消した。初回sandbox内実行もXcode cache権限不足のため、許可された昇格実行で検証した。
- 実際の共有Swiftソースを用いた単体スクリプト: 3種のProperty List binary round trip、未知種別・未知version拒否、既存commandとstateのround tripがすべて成功。
- 同内容のXCTestをWatchPlaybackMessageTestsへ追加。XCTest／Simulator testは実行していない。test端末の作成0、削除0。
- `git diff --check`成功。
- 実機間WatchConnectivity、非接続／対象なし／音源取得失敗、SE 40mm表示とDynamic Type操作は未検証。実機デプロイ未実施。
