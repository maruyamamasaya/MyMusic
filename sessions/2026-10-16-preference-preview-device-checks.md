# 差分Previewの実機手順の補足

- ユーザー依頼により実機ガイドへ、両アプリのキャンセル、HomeStereoのメニューバー経由の再編集、MyMusicのWatch等経由の再編集、拒否後の再選択と値／未送信情報保持を具体的に追記。
- 評価だけ・ハートだけ・両方を独立した試験条件として記載。「再生傾向」はPreferencesの評価値とfavoriteを指し、再生履歴やPlaylist等は別JSON／別確認であることを表で区別。
- Previewをキャンセルしてからの編集はstale Preview試験にならないこと、別操作経路がない場合は未実施とすることを明記。
- ガイドの導入基準を差分Preview導入済みrevisionへ更新。実装・共通交換契約は変更なし。
- 文書のみ。相対リンク確認とgit diff --check成功。build／testは実行せず、test端末の作成・削除0。
