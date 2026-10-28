# ステーション正式表記と背景ランダム表示

- ユーザー承認で入口のBETAを撤去し、質問案内を実装どおり2問へ訂正。選曲処理は変更なし。
- 元のstation-background.jpgを保持し、station-golden-island.jpgとstation-golden-spiral.jpgを追加。初回抽選、ホーム更新では直前以外の読み込める画像へ切替。Playlistの共有入口でも初回抽選する。
- built-in image_genで既存画像を参照し、濃紺・金色の音の波・モザイク都市の同系列を生成。1枚目は浮島のアンテナと右上へ流れる波、2枚目は右の2塔と左から回り込む波。文字・ロゴなし。原本は ~/.codex/generated_images/01a1804b-a638-7ed0-952c-4d39afdbc5e5/exec-df4ac1ab-0d53-4b3d-afff-62428f309d5f.png と exec-fab174ca-5dfe-4cb7-a35a-14ac972eb292.png。JPEG85へ変換して同梱。
- 指定iPhone 17e Simulator向けDebug build: BUILD SUCCEEDED。最初のsandbox内buildはキャッシュ権限制限で失敗し、許可された再実行で成功。画像2枚のbundleコピー確認。git diff --check成功。
- test未実施。test端末作成0・削除0、XCTestDevices未変更。実画面・実機未確認、実機未デプロイ。

## Vesperaデプロイ

- 明示依頼によりgit status、check-iphone.sh成功後にdeploy-iphone.shを実行。初回は端末再確認の15秒timeoutでbuild前停止。再実行でDebug Build・Install・Launch成功。
- MyMusic.xcodeproj／scheme MyMusic／product MyMusic／Bundle ID maruyama.MyMusic。VesperaはiPhone 17e、UDID 00008150-000C54280E33401C。署名・識別子等の設定変更なし。
- 実機外観・操作はユーザー確認待ち。test未実施、test端末作成0・削除0、XCTestDevices未変更。
