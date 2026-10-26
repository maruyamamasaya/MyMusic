# iOS検証端末の固定

- ユーザー指定によりAGENTS.mdへ、このMacでのSimulatorを既存iPhone 17e／iOS 26.5／UDID `EB3A49ED-6553-4D7E-B933-387951643EAB` に固定する方針を追記。標準buildコマンドのdestinationも同UDIDへ更新。
- build・起動・testでUDIDを明示し、並列testを無効化。別端末作成・clone、runtime追加・更新の自動実行を禁止。端末不在・互換性問題では代替を作らず理由と必要対応を報告する。
- 既存Simulatorのアプリ・test dataの無断初期化／削除を禁止。実機確認候補は接続済みiPhone 12 mini／iPhone 13／iPhone 17e。既存の実機デプロイ手順・明示依頼条件を維持。
- 検証：Git rootと開始時のcleanな作業ツリーを確認。文書差分と`git diff --check`を確認。文書のみの変更のためbuild・testは未実行。端末・runtimeの実在や互換性は今回未検証。
- Simulator／test端末の作成・削除はともに0台。アプリ構造・データフロー・製品状態の変更はなく、CURRENT.md／ARCHITECTURE.mdの変更は不要。
- 適用範囲はこのMyMusic repository。Mac全体や別repositoryの共通指示ファイルは変更していない。
- 追加依頼：Watchの検証モデルをApple Watch SE（第2世代／SE 2）に指定。既存端末のモデル・watchOS・UDIDと連携時のpairingを確認して再利用する。サイズ・OS・UDIDは未指定。候補不在・複数候補・互換性問題では自動作成やpairing変更を行わず報告する。今回も文書のみの更新で端末調査・build・testは未実行、端末作成・削除は0台。
