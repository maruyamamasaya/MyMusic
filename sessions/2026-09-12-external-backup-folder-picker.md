# App外バックアップのフォルダ選択修正

## 作業

- `ExternalBackupView` に同時に付いていた保存先用・復元用の2つの `fileImporter` を、用途を切り替える単一のフォルダImporterへ統合した。
- 保存先選択ではbookmark保存と状態更新、復元選択では確認ダイアログへの引き渡しという既存処理を維持した。

## 原因

- 同一View階層に同種のpresentation modifierが2つあり、後段の復元用Importerと競合して保存先用Importerが安定して提示されない構成だった。

## 検証

- 標準Simulator buildは、既知のWatch AppIcon applicable content不足で失敗した。
- 代替としてWatch埋め込みを含むGeneric iOS Device向け署名なしDebug buildを実行し、`BUILD SUCCEEDED`。`MyMusic.app/Watch/MyMusicWatch.app`のcopyと`ValidateEmbeddedBinary`も成功した。
- `git diff --check`: 成功。
- XCTestは実行しない。永続化・backup形式・restore処理は変更しておらず、今回の変更はSwiftUIのpresentation経路の統合に限定される。
