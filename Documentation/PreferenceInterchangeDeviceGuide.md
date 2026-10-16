# 評価の受け渡しとGood 8〜15の実機確認

更新: 2026-10-16。

## 今の疎結合の仕組み

MyMusicとHomeStereoは別Git・別アプリ・別の保存領域を持つ。MyMusicはiPhone内のJSON等、HomeStereoはMac内のSQLite等を正本とし、相手のDBや設定へ直接書き込まない。必要なデータだけをversion付きJSONへ書き出し、ユーザーが相手アプリで読み込む。

```mermaid
flowchart LR
    A[MyMusicの端末内データ] <-->|JSONを手動で書き出し・読み込み| B[HomeStereoのMac内データ]
    A -->|JSONを書き出し・読み込み| C[Analyticsの独立した分析データ]
```

- Library、Preferences、Playback Events、Playlistsは別文書。評価を渡しても再生履歴やPlaylistは同期しない。
- 同一曲の交換用IdentityはMyMusicのTrack ID。HomeStereoは自身のTrack IDを保持し、MyMusic IDとの対応表を持つ。初期照合には共通root以下の相対path、size、duration、fingerprint等を使う。曲名だけで常に一致するわけではない。
- iCloud Drive等はJSONファイルの運搬手段。置くだけでアプリ内の評価が自動同期される機能はない。
- Preferences schema v2は曲ごとの現在の整数評価とfavorite Boolを渡す。タップ履歴／差分回数ではなく、両端末で押した回数は加算しない。
- MyMusicは保存された評価をExportする。HomeStereoはMacでFavorite／評価を変更した、MyMusic ID接続済みの曲だけを差分Exportする。
- Importに含まれる曲は受信値へ更新し、含まれない曲を削除・初期化しない。同じ曲を両側で編集した場合、自動競合解決はなく、後のImport等で上書きされ得る。
- HomeStereoはExportファイル保存成功時に、Previewと同じ変更世代だけを送信済みにする。相手のImport成功を検知する受領確認は未実装。再送のためJSONを反映確認まで残す。
- Analyticsは独立した分析用データ。Local/Desktop版は評価編集・JSON Exportもできるが、自動的にMyMusic／HomeStereoへ反映はしない。

共通の意味とversion付きデータ形式を揃え、UI・再生・DBを独立して変更できるのが現在の疎結合。仕様の正本は[共通データ交換・保全契約](DataInterchangeContract.md)、未実装事項は[保全課題](DataInterchangeIssues.md)。

## 今回の評価と演出

| 項目 | MyMusic | HomeStereo |
| --- | --- | --- |
| 保存・編集・交換範囲 | -10〜15 | -10〜15 |
| 選曲効果 | 10以上はweight 42で一定 | 候補抽選は10以上でweight 11のまま |
| Good 8〜15の豪華な演出 | 対応 | 対象外 |
| 評価順や評価別表示 | 生の値を使用 | 生の値を使用 |

従来の-10〜10の選曲式は変更していない。15からBadを押すと14となり、9で初めて選曲weightが下がる。旧版受信側は11以上を拒否するため、両側を対応版へ更新してから交換する。

2026-10-16の導入基準: MyMusic `7a36d62`、HomeStereo `83d286f`（正式配置build `20261016185415`）。VesperaへのInstall／LaunchとHomeStereo正式配置／起動は確認済み。実機での以下のチェック成功を意味しない。

## 開始前

- [ ] 両アプリのbackupを確保する。全体Restoreの検証はこの評価確認と分け、試験用データで行う。
- [ ] 両方でTrack ID照合済みの通常曲を1曲選び、元の評価・ハート状態・Track IDを控える。比較用に変更しない曲も1曲決める。
- [ ] Macに未送信の評価変更がある場合、先にJSON保存・整理する。同じ曲を両側で変更していたら採用値を決め、基準を揃えてから開始する。MyMusicの全件Preferencesを安易に読み込んでMac側編集を消さない。
- [ ] 試験中は片側ずつ編集する。新旧JSONを区別できるファイル名を付ける。

## 1. MyMusicの演出と保存

1. 通常再生画面で試験曲をGood 8にし、8→9→10→11→12→13→14→15と1回ずつ増やす。
2. 数字が1ずつ増え、星の数・大きさ・広がり・光量が段階的に増すことを確認する。8〜9は金／白、10から周回する輪、11から虹色が加わる。
3. タップ時の波紋・アイコン拡大も強まることを確認する。15でもう一度押して16にならないことを確認する。
4. Badで15→14→…→8と戻し、演出も小さくなることを確認する。
5. 小型プレイヤー、ハイライト、Visual Worldでも確認する。Visual Worldは周囲の星・光が対象で、共通ボタンのタップ波紋は対象外。
6. 数字・隣の操作が読める／押せること、はみ出した装飾がタップを奪わないことを確認する。
7. 別曲へ移った時に評価・演出が切り替わり、再起動しても15を保持することを確認する。
8. iOSの「視差効果を減らす」有効時に連続する動きが止まることを確認する。backgroundからの復帰でも正常に再表示することを確認する。
9. 数分再生して音切れ、操作の引っかかり、目立つ発熱がないことを確認する。

5〜7は従来の3つの光。8〜15は星7〜21個、外側への広がり6〜20pt。動きと明るさで見え方は変わるため、静止画だけで最終判断しない。

## 2. MyMusic → HomeStereo

1. 試験曲を15にする。
2. MyMusicの設定・データ管理内で「再生傾向を書き出す」を選び、`MyMusic-Playback-Preferences.json`をMacへ渡す。
3. HomeStereo「MyMusic連携」のPreferences読み込みで選択する。評価・ハートの「現在→読み込み後」、更新予定／変更なし／未照合の件数を確認して「読み込む」。変更なしはtoggleで表示する。
4. 未解決なら「MyMusic適用状況」でID対応を確認し、必要ならMyMusicのLibrary JSONを読み込んで照合する。曲名の似た別曲へ適用して続行しない。
5. 評価15とハートが一致し、10へ丸められないことを確認する。比較用の未変更曲も確認する。
6. HomeStereoの分析・評価別一覧で15が表示されることを確認する。11でも同じ流れを試し、「評価11」と「未設定」が混ざらないことを確認する。

HomeStereoに豪華な星・虹色がないのは仕様。

## 3. HomeStereo → MyMusic → 再送

1. HomeStereoで試験曲を15→14へ変更する。
2. 「MyMusic連携」からPreferences書き出しを選び、変更曲Previewに試験曲が含まれることを確認して保存する。
3. JSONをiPhoneへ渡し、MyMusicの「再生傾向を読み込む」で選択する。差分sheetで評価・ハートの「現在→読み込み後」と件数を確認し、「確認して読み込む」。キャンセルでは変更されない。
4. 評価14と14相当の演出、ハートが反映されることを確認する。
5. MyMusicから再ExportしてHomeStereoへImportし、14を維持することを確認する。
6. 同じJSONを再Importしても数値の加算・曲の複製がないことを確認する。
7. 両アプリを再起動し、評価・ハート・比較用の未変更曲が保たれることを確認する。
8. 必要なら控えた元の評価・ハートへ戻し、片側で修正して相手へ渡す。古い全件JSONの再Importで、その後の別曲編集まで戻さない。

HomeStereoで一度Exportした曲は、そのまま再Exportしても対象外になり得る。反映確認までは保存したJSONを保持し、再送には同じファイルを使う。

## 差分Previewの追加確認

- [ ] JSONを選んだだけ／キャンセルで評価・ハートが変わらない。
- [ ] 評価だけ・ハートだけ・両方の変更と変更なしが正しく表示される。
- [ ] 変更なしtoggleで対象が増減し、未照合の現在値を0と表示しない。
- [ ] Preview中に別画面等で同じ曲を再編集した場合、適用が拒否されて変更が残る。JSONを選び直して再確認できる。
- [ ] HomeStereoでは拒否後もその曲の未送信変更が残る。
- [ ] 多数の曲でも100件以降の変更を確認できる。

## 4. 選曲効果・旧backupの検証範囲

10と15の頻度が同じかを少数回のshuffleで判定しない。weightの同一性は自動テストで確認済み。実機は15でもqueue生成・再生が正常に動くかを確認する。

自動検証済み: MyMusicの保存／再起動／Watch通信／backup manifest v1・v2復元、HomeStereoの旧DB v14保存状態backup復元→v15移行と既存field／ID／未送信token保持、評価の反復JSON往復、Analyticsの旧DB移行。実ユーザーbackupの復元や実端末間往復は、自動テストから成功扱いにしない。

旧backupを新アプリで読む互換性と、新しい15入りデータを旧アプリで読む互換性は別。後者は保証しない。

## より効率よくするには

### 今の機能だけでできる運用

- iCloud Drive等に交換専用folderを1つ決め、日付・方向をファイル名に含める。例: `2026-10-16-iPhone-to-Mac-preferences.json`。ファイルの同期完了後、相手で手動Importする。
- 評価だけならPreferencesだけを交換する。毎回Library・履歴・Playlistを送り直さない。LibraryはID照合に必要な時に使う。
- 編集は「iPhoneを使う時間→Macへ渡す→Macを使う時間→iPhoneへ戻す」の順でまとめ、同曲の並行編集を避ける。
- 毎回の短い確認は「15でExport→Macで14→iPhoneへ戻す→再起動」の1往復。演出の全8段階、11／未設定、Reduce Motion、狭い画面は初回や表示変更時に行う。
- 一度確認した記録を残し、変えていない部分の全試験を毎回やり直さない。

### 差分Previewの実装状況と今後の改善候補

差分Previewは2026-10-16の追加実装。上記の導入基準revisionより後の変更で、21:49 JSTにVesperaへInstall／Launch、HomeStereoはbuild `20261016214812`として正式配置済み。実機での画面確認・JSON往復は別途実施する。残る案の推奨順は「確認の手間を減らす→受け渡しの手間を減らす」。DBを共通化せずJSON境界を維持できる。

1. **差分PreviewはBeta実装済み**: 更新前→受信後の評価・ハート、変更件数、未解決曲を表示し、Preview後の対象曲の再編集は拒否する。前回の受け渡し状態の記録は未実装。
2. **送信fileの履歴・受領確認**: 保存済みと相手で反映済みを区別し、未受領のJSONと変更世代を再送できるようにする（DI-005／DI-007に関連）。
3. **交換folderを記憶した読込候補の提示**: 毎回file pickerで探す手間を減らし、Preview後の明示適用を維持する。iOSのfolder権限、iCloudの未download／部分書込、旧file再適用の判定が必要。
4. 自動同期はさらに後。安定した変更世代・競合解決・原本保持・受領確認が揃ってから検討する。現状の後勝ちImportをそのまま自動化しない。

「同じfolderを使う」は運用改善、「folder監視で自動適用する」は機能開発であり、現在は後者を実装していない。

## 結果の記録

`sessions/YYYY-MM-DD-<topic>.md`へ次を記録する。チェック欄は実施時だけ埋める。

```text
日時／iPhone・MacのOS／アプリrevision:
試験曲のTrack ID／元の評価・ハート:
演出8〜15／上限15／減少／各画面／Reduce Motion:
MyMusic 15 → HomeStereo 15:
HomeStereo 14 → MyMusic 14:
評価11と未設定／同じJSON再Import／再起動:
未変更曲・ハートの保全:
使用JSONと保管場所:
不具合・再現手順・未実施項目:
```

全般的な実機確認は[実機検証チェックリスト](DeviceValidationChecklist.md)、今回の自動検証・配置履歴は[評価範囲の作業記録](../sessions/2026-10-16-preference-range.md)と[演出・配置の作業記録](../sessions/2026-10-16-preference-effects-deploy.md)を参照。
