# 分析・履歴・傾向・作業用のタイル画像

- Context Guard MATCH、Git root一致。既存変更を保持。
- built-in image_genで4枚を生成し、Resources/HomeTileImagesへコピー。元画像・既存jpgは保持。
- 共通生成指示：正方形・濃紺と黒背景、ガラスとクロームの抽象立体、上側に彫刻、下側は白いタイトル用の暗い余白。文字・数字・ロゴ・UI・人物なし。
- 再生分析：cyanのガラスdisc、金属の同心円とリズミカルなbar、音の構造。
- 音楽史：amber／goldのrecord状ringのらせん、蓄積する記録。
- 最近の音楽傾向：violet／indigo／cyanの変化する流線ribbon。
- 作業用BGM：tealの反復するarchと静かな波、集中する流れ。
- 保存名はactivity-analytics-v2.png／activity-music-history-v2.png／activity-music-trends.png／work-bgm-background.png。既存loaderへ接続。READMEとHomeCategoryTestsの期待値も更新。
- 4枚を目視確認。git diff --check実施。build・test・deployと実際のtile crop確認は未実施。再生・データ境界変更なし。
- 画像は既存方針でGit追跡外。テスト端末作成・削除0台、XCTestDevices調査・変更なし。
