---
status: active
updated: 2026-08-28
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
- 曲、アルバム、アーティスト、ジャンル、作曲者別の閲覧、ジャンル表示設定、非同期 sort / 段階表示。
- ローカル音源の再生、一時停止、seek、前後移動、queue、shuffle、repeat、EQ、共通 playback transition。
- mini player / Now Playing、audio 情報、簡易 spectrum、lock screen / Control Center 情報、remote command、background audio 設定。
- 曲・アルバム・アーティストのお気に入り、通常 / 作業用 playlist、playlist import / export。
- 複数条件検索、home の各種再生入口、再生回数・評価・履歴・analytics、calendar / yearly insights / discovery / memory navigation。

### Beta

- **ハイライト再生**: 約30秒の候補区間、縦 paging、先読み cache、反応による傾向調整。
- **作業用サイズ再生**: 20分以上または「作業用BGM」の曲を通常ランダム再生から分離し、専用 player / playlist を提供。
- **選択してランダム再生**: 最初の候補曲と共通ジャンルを起点に queue を作成。
- **共通再生トランジション**: 設定可能な fade と切替時の安全減衰。crossfade ではない。
- **音楽特徴量 Beta 1 / 3**: Mac Analyzer の schema v1 JSON を安全に照合・永続化し、audio 情報面で分類 badge と詳細を表示。

Beta の操作と制約は [README.md](README.md)、特徴量の contract は [Documentation/TrackFeatureBeta1.md](Documentation/TrackFeatureBeta1.md) と [Documentation/TrackFeatureBeta3.md](Documentation/TrackFeatureBeta3.md) を参照してください。

## テスト・検証の現状

- `MyMusicTests` に音楽特徴量の import / matching / persistence / presentation / Observation / layout を対象とする XCTest がある。
- `analyzer/tests` に discovery、cache、schema、audio analysis、CLI を対象とする Python unittest がある。
- 2026-08-27 の特徴量 Beta 3 記録では iPhone 17 / iOS 26.5 Simulator の XCTest 19件と Debug build が成功。
- 専用 lint 設定、Swift Package Manager 依存、CI/CD workflow はリポジトリ内で確認できない。

## 既知の制約・未検証

- 特徴量分類とハイライト候補は軽量 heuristic であり、学習済み分類器の確率やサビ判定ではない。
- 特徴量 schema v1 の `contentHash` は予約項目で、iPhone での生成・照合は未実装。未照合 / 曖昧項目の修正 UI もない。
- 作業用の20分境界、暗転時間、完全一致 genre 名は固定。直接選曲時は通常 player を使う。
- crossfade、streaming、server integration、offline download、ReplayGain は未実装。
- 実音源での全再生回帰、実機 background / lock screen / AirPods、特徴量の聴感妥当性は、最新資料上では未確認。
- `MetadataService` は `.m4a` container を AAC と表示し、ALAC の stream-level 判別は未実装。
- Xcode の Deployment Target は 26.5。変更理由は今回確認した資料・履歴だけでは不明であり、明示依頼なしに変更しない。

## 次のアクション

1. 新しい Beta は一機能ずつ実装し、対象 test と Simulator build を成功させる。
2. 特徴量 Beta はまず少数の実音源で照合・表示・聴感を確認し、その後に大規模解析へ進む。
3. 実機確認が必要なリリース候補では、再生操作、background、lock screen / Control Center / AirPods、データ削除の非破壊性を検証する。
4. CI / lint を導入する場合は、既存環境に存在しないことを前提に別タスクとして設計判断を記録する。
