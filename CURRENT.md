---
status: active
updated: 2026-08-30
---

# MyMusic の現在状態

## 現在の位置づけと優先事項

- iPhone 向け個人用ローカル音楽プレイヤー。App Store 正式リリースを示す版番号は確認できません。
- 2026-08-14 の「完成基準版」を、基本体験を維持する基準としている。
- 現在は Original Features Beta を小さく追加し、個別に build・検証・文書化する段階。
- 最優先は、ライブラリ、検索、再生、お気に入り、プレイリスト、データ管理の基準版を回帰させないこと。
- Streaming / server integration は未着手の将来領域。

この方針を採った経緯は [ADR-0002](decisions/ADR-0002-baseline-and-beta-delivery.md)、利用者向け機能説明は [README.md](README.md) を参照してください。

## 実装済み

### 基準版

- Files / iCloud Drive の複数フォルダ登録、security-scoped bookmark の復元、音源 scan と library cache。
- 曲、アルバム、アーティスト、ジャンル、作曲者別の閲覧、ジャンル表示設定、非同期 sort / 段階表示。ジャンル設定適用時の全ライブラリ再構築は専用actorで実行し、最新の結果だけをMainActorへ反映する。
- iTunes / ID3のAlbum Artistと年を保持し、アルバムの統合・表示・検索に使用。検索画面では曲名、アルバム名、アーティスト名、アルバムアーティスト、年代を個別に選べ、225ms debounce、入力Task cancellation、専用actor検索、結果state保持を行う。
- ローカル音源の再生、一時停止、seek、前後移動、queue、shuffle、repeat、EQ、共通 playback transition。
- mini player / Now Playing、audio 情報、簡易 spectrum、lock screen / Control Center 情報、remote command、background audio 設定。
- ホームのライブラリ／アクティビティ各タイルは、ビルド前に所定名のローカル画像を置くと背景へ使用する。未配置・破損時は既存の個別グラデーションを維持する。
- 曲・アルバム・アーティストのお気に入り、通常 / 作業用 playlist、playlist import / export。
- 複数条件検索、home の各種再生入口、アクティビティから直接開ける再生分析／音楽史、再生回数・評価・履歴・analytics、calendar / yearly insights / discovery / memory navigation。

### Beta

- **データ管理の解析・設定JSON**: 音量ノーマライズ解析値と音楽特徴量を用途別JSONへ出力する。現在のEQ＋オリジナルEQプリセット、ジャンル表示プリセットはversioned JSONで出力・読込でき、同名プリセットを更新し新規項目を追加する。プレイリスト／EQ／ジャンル設定のファイル選択は単一のImporterで対象を切り替え、同種presentationの競合を避ける。解析データの再読込と曲別手動調整の出力は対象外。
- **プレイリストタグ**: 通常／作業用Playlistへ複数タグを保存し、一覧と曲の追加先を1タグで絞り込む。旧Playlist JSONは空タグでdecodeし、JSON／Markdown import / exportでもタグを保持する。タグ・曲構成の更新は再生開始時のPlayerStore queue snapshotへ伝播させず、Playlist保存は更新順に直列化する。
- **Track Adjustments**: 通常Now Playingのアートワーク面を「アートワーク→オーディオ情報→曲別調整」の3状態にし、Stable Track IDごとの開始位置・終了位置・前回位置・±2 dBの手動ノーマライズ微調整を端末内へ保存する。開始／終了位置に共通の1秒戻る操作と、登録成功時のインラインフィードバックを持つ。終了位置はPlayerStoreの再生時刻eventから既存の次曲処理へ合流する。
- **音量ノーマライズ**: Mac Analyzerが全曲のIntegrated LUFS / True Peakと控えめな固定ゲインを算出し、特徴量JSON経由でiPhoneへ渡す。-17〜-11 LUFSは無補正、最大±4 dB、-1 dBTP ceiling。設定は初期OFFで、音源変更・動的圧縮は行わない。
- **1曲ごとの再生履歴リセット**: 分析の「よく再生している曲」を長押し、確認後にその曲の再生回数・日時履歴だけを削除できる。お気に入りや評価、シャッフル除外は保持し、全曲一括リセットは持たない。
- **ハイライト再生**: 約30秒の候補区間、縦 paging、先読み cache、反応による傾向調整。
- **作業用サイズ再生**: 20分以上または「作業用BGM」の曲を通常ランダム再生から分離し、専用 player / playlist を提供。
- **選択してランダム再生**: 最初の候補曲と共通ジャンルを起点に queue を作成。
- **気分ステーションの年代指定**: 気分・音の特徴に加え、通常再生対象かつ特徴量のある曲の年metadataから10年単位の候補を構成し、任意の年代へ絞って一時queueを生成できる。年がないlibraryでは年代質問を省略し、「すべての年代」では従来の選曲を維持する。
- **共通再生トランジション**: 設定可能な fade と切替時の安全減衰。crossfade ではない。
- **音楽特徴量 Beta 1 / 3**: Mac Analyzer の schema v1 JSON を安全に照合・永続化し、audio 情報面で分類 badge と詳細を表示。
- **Semantic v2 Analyzer**: 保存済みEmbeddingと学習済みheadからVocal / Instrumental、Mood、音色系特徴量を生成する。通常運用は音楽Rootを再帰走査し、relativePathとfileSize / mtimeNSで新規・更新・削除を差分反映する。library単位のcacheを維持したまま、完了済みJSONだけを`--export-all`でアプリ用の1ファイルへ統合できる。2026-08-29にインスト／OST中心3,837曲と従来3,552曲で分布を評価し、追加calibrationなしでraw headをFIXした。

Beta の操作と制約は [README.md](README.md)、特徴量の contract は [Documentation/TrackFeatureBeta1.md](Documentation/TrackFeatureBeta1.md) と [Documentation/TrackFeatureBeta3.md](Documentation/TrackFeatureBeta3.md) を参照してください。

## テスト・検証の現状

- `MyMusicTests` に音楽特徴量の import / matching / persistence / presentation / Observation / layout を対象とする XCTest がある。
- `analyzer/tests` に discovery、cache、schema、audio analysis、CLI を対象とする Python unittest がある。
- Semantic v2の差分更新testでは、既存曲Skip、新規曲と新規subfolderだけのaudio read、再実行の全Skip、head再評価時の`audioReads=0`、更新・削除・中断再開、20,000行reconciliationを確認している。
- Semantic v2統合testでは、defaultのみ、workspace 1件／複数件、空／破損JSON、relativePath衝突、別libraryの同名file、source manifest、統合件数、fail-closedを確認している。
- 2026-08-27 の特徴量 Beta 3 記録では iPhone 17 / iOS 26.5 Simulator の XCTest 19件と Debug build が成功。
- 2026-08-29 のTrack Adjustments追加後、iPhone 17 / iOS 26.5 SimulatorのXCTest 54件とDebug buildが成功。Analyzer / Semantic unittest 36件もPython 3.12環境で成功。
- 2026-08-30 のジャンルフィルタ非同期化後、連続する設定変更で最新結果だけが反映されるXCTestを追加し、iPhone 17 / iOS 26.5 Simulatorの全XCTestとiOS Device Debug buildが成功。
- 2026-08-30 のホームタイル画像設定追加後、画像名mappingを含むiPhone 17 / iOS 26.5 Simulatorの全XCTestとDebug test buildが成功。
- 2026-08-30 のAlbum Artist / 年代検索追加後、metadata field別検索と複合条件のXCTestを追加し、iPhone 17 / iOS 26.5 Simulatorの全XCTestとDebug buildが成功。
- 2026-08-30 の気分ステーション年代指定追加後、年代候補、年metadata絞り込み、質問遷移、Dynamic Type / Dark Modeを含むiPhone 17 / iOS 26.5 Simulatorの全XCTestとDebug buildが成功。
- 2026-08-30 のプレイリストタグ追加後、旧data decode、正規化、絞り込み、連続保存、import / export、再生中のPlaylist更新とqueue分離を含むiPhone 17 / iOS 26.5 Simulatorの全XCTestとDebug test buildが成功。
- 2026-08-30 のデータ管理拡張後、解析JSONの内容、EQ／ジャンルプリセットのround-trip・同名merge・永続化・不正値拒否を含むiPhone 17 / iOS 26.5 Simulatorの全XCTest 74件とDebug test buildが成功。
- 専用 lint 設定、Swift Package Manager 依存、CI/CD workflow はリポジトリ内で確認できない。

## 既知の制約・未検証

- 特徴量分類とハイライト候補は軽量 heuristic であり、学習済み分類器の確率やサビ判定ではない。
- Semantic v2のVocal / Instrumentalは学習済みbinary headだが、game / OST音色をVocalとする局所的なdomain shiftが残る。Artist / Title / Folderによる補正は行わず、再調整は作品横断の人手ラベル付き評価ができた場合に限定する。
- Semantic単独では新規Trackの`energy` / `tempo`を生成しない。同一relativePathのproduction DSP baselineがある場合だけ値を継承し、2.048秒未満の曲はmodel patchを構成できないため未解析となる。
- schema v1はmusic-root識別fieldを持たない。異なるrootの同一relativePathはmerged JSONで両方保持するが、fileSize / durationまで同じ複製音源はiPhone importでAmbiguousになり得る。source/library対応はimport対象外sidecarに保持する。
- 特徴量 schema v1 の `contentHash` は予約項目で、iPhone での生成・照合は未実装。未照合 / 曖昧項目の修正 UI もない。
- 作業用の20分境界、暗転時間、完全一致 genre 名は固定。直接選曲時は通常 player を使う。
- crossfade、streaming、server integration、offline download、ReplayGain は未実装。
- 実音源での全再生回帰、実機 background / lock screen / AirPods、特徴量の聴感妥当性は、最新資料上では未確認。
- 音量ノーマライズのTrue Peak ceilingは元音源＋固定ゲインを対象とし、後段EQによるピーク増加は保証しない。実ライブラリ全曲解析時間と実機聴感は未確認。
- Track Adjustmentsの開始・終了位置、background時の位置保存、手動補正の聴感はSimulatorのunit/integration testまで確認済み。実音源・実機での境界精度、background直後の永続化完了、操作性は未確認。
- 気分ステーションの年代指定はTrackの年metadataを10年単位で扱う。年代指定時、年がない曲は候補外となり、年metadata自体の正確性は音源tagに依存する。
- プレイリストタグは1プレイリスト20件・1タグ40文字までで、絞り込みは一度に1タグ。タグの一括名称変更、色、階層は未実装。
- `MetadataService` は `.m4a` container を AAC と表示し、ALAC の stream-level 判別は未実装。
- Xcode の Deployment Target は 26.5。変更理由は今回確認した資料・履歴だけでは不明であり、明示依頼なしに変更しない。
- 既存ライブラリキャッシュはそのままdecodeできる。Album Artistを旧キャッシュへ補完するには一度「再スキャン」が必要で、metadata revisionにより旧Trackだけを一度再抽出する。

## 次のアクション

1. 新しい Beta は一機能ずつ実装し、対象 test と Simulator build を成功させる。
2. Semantic v2はraw head仕様を維持する。変更が必要になった場合は、作品横断の人手ラベル付き評価で現行仕様との回帰を測る。
3. 実機確認が必要なリリース候補では、再生操作、background、lock screen / Control Center / AirPods、データ削除の非破壊性を検証する。
4. CI / lint を導入する場合は、既存環境に存在しないことを前提に別タスクとして設計判断を記録する。
