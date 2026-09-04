# ホームパフォーマンス改善フォローアップ

## 調査と変更

- `HomePlaylistTile`と`HomeItemTile`が`[String]`全体を`task(id:)`へ渡し、taskからランダムなStateを更新していた。画像候補の選択を親snapshot更新時へ移し、Tileへ単一の安定したidentifierを渡すよう変更した。
- Destination／Playlistの再計算時は、以前のidentifierが候補内なら維持する。同値のDestination snapshot、Playlist tracks、Artwork ID、Playlist配列はStateへ書き戻さない。
- Artwork表示taskはロード前の`nil`代入を廃止し、identifierと結果を一つのStateとして1回だけ更新する。
- ArtworkServiceはImageIOで画像propertyを検証し、最大1024pxへMainActor外でdownsample／decodeする。decode済み画像に加え失敗identifierもcacheし、破損画像をView再描画ごとに再decodeしない。
- `unsafeForcedSync`を調べるため自アプリの`DispatchQueue.sync`等を検索したが該当なし。iPhone 17 SimulatorでMyMusic起動後とSimulator全体の直近logを検索し、`unsafeForcedSync`は再現しなかったため、根拠なくConcurrency構造を変更していない。

## 検証

- iOS Simulator Debug build: `BUILD SUCCEEDED`。
- `ArtworkServiceTests`と`HomeRepresentativeTrackPolicyTests`: 4件成功。破損画像の失敗cache、再登録後の復帰、代表曲先頭化を確認した。
- 全XCTestを実行。今回の対象テストを含む大半は成功したが、前回から確認済みの非同期timing依存テスト（Station、Genre Filter）とPreference persistence 1件がSimulator負荷下で失敗した。
- Simulator起動ログでは`onChange ... multiple times per frame`、画像decompress、gesture gate、`unsafeForcedSync`の対象ログなし。実ライブラリを用いた連続スクロールは実機確認が必要。
- `git diff --check`: 成功。
