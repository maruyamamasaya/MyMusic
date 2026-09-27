# Library relativePath interchange

- `MyMusic-Library.json`のversion 1へoptionalの`relativePath`と`fileSize`を追加した。`relativePath`は利用者が選択した音楽ルート以下で、iCloud containerやFile Providerの端末固有絶対prefixを含まない。
- HomeStereoはこの値をMyMusic `trackID`の照合キーとして使用し、MyMusicのCanonical ID自体はJSONの`trackID`を維持する。
- iPhone 17e / iOS 26.5 Simulatorの対象XCTest 4件とgeneric iOS Simulator Debug buildが成功した。実機デプロイは行っていない。
