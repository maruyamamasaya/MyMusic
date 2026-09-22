# 大規模ライブラリ性能改善 Phase 1

## 背景

約10,000曲で全体が重く感じられ、音声は継続する一方で再生バーが止まることがある、という報告を起点に調査した。今回は永続化schemaや再生音声経路を変えず、影響の小さい高頻度処理から改善した。開始時点にはUSB DACネイティブレート出力関連など別件の未コミット差分があり、それらは保持した。

## 調査結果

- `AudioPlayerService`は0.5秒ごとに再生位置eventを発行する。Now Playingの`hasNext`／`hasPrevious`はその再描画経路で`playbackOrder.firstIndex`を使っていたため、queueが長いほど線形走査が増えていた。
- Now Playingは現在TrackのAlbum／Artistを表示するため、全Album／Artistと各`trackIDs`を再描画時に走査していた。`LibraryStore.resolvedTracks`も呼び出しごとに表示中全TrackからDictionaryを作り直していた。
- PCM tapはオーディオ情報の波形やVisual Worldが非表示でも、約2,048 frameごとに32本のlevel、左右RMS、差分powerを計算し、MainActorへ`spectrumLevels`／`spatialSnapshot`を通知していた。音声再生を止めなくてもUI更新を圧迫できる経路だった。
- `SearchView`は`PlaybackHistoryStore.entries`全体を`onChange`監視していた。PlayerStoreは再生中15秒ごとに総再生時間を保存するため、検索条件に関係しない変更でも大きなDictionary比較と検索更新の入口になり得た。

## 変更

- playback order変更時にqueue index→order positionを再構築し、再生中の位置参照をO(1)化した。
- Library snapshot反映時にTrack／Album／Artistのlookup indexを構築し、再生中画面と詳細画面の参照解決へ使用した。
- 旧波形／空間メーター計算をatomic gateで停止し、activeな`AudioInformationView`またはVisual World解析中だけ有効にした。音声tap、再生engine、Visual World mailboxのbounded/drop方針は維持した。
- SearchはLibrary／History／Preferenceの軽量revisionを監視し、15秒ごとの総再生時間更新だけでは再検索しないようにした。

## 検証

- `git diff --check`: 成功。
- generic iOS Simulator Debug build: **BUILD SUCCEEDED**。既存の`MusicHistoryView`のSwift 6 async警告とApp Intents metadata警告のみ。
- iPhone 17e / iOS 26.5 Simulator、並列無効・worker 1で対象XCTest 7件成功、失敗0。
  - Library索引とgenre filter: 2件。
  - 10,000曲queueの末尾付近からのNext／Previous可否: 1件（0.099秒）。
  - 既存Shuffle／Repeat／自然終了queue遷移: 3件。
  - リアルタイムaudio metrics gate: 1件。
- XCTestDevicesは各test前後とも12 KB、新規UUID folder 0、削除0。Xcode processが実行中だったが削除対象自体はなかった。

## 未確認・次段階

- 実機の実ライブラリを用いたTime Profiler／SwiftUI Instruments計測は未実施。今回の原因順位はコード上の頻度と曲数依存性からの推定であり、実測で確定していない。
- 10,000件を返す検索結果List、HomeのMix再計算、shuffle生成、起動時snapshot decode／index構築は操作時の候補として残る。Phase 2では実機計測結果に基づき、必要な箇所だけpagination、cache、signpostを追加する。
- 実音源での長時間再生、background／lock screen、Watch同期、Audio Information／Visual Worldの表示復帰は手動確認が必要。
