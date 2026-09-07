---
status: active
updated: 2026-09-07
---

# MyMusic の現在状態

## 現在のフェーズ

- 2026-08-14 Baseline を維持しながら、Original Features Beta を小さく追加する段階。
- 最優先はライブラリ、検索、再生、お気に入り、プレイリスト、データ管理の回帰防止。方針は [ADR-0002](decisions/ADR-0002-baseline-and-beta-delivery.md)。

## 実装済み

- iOS アプリはローカルライブラリ、再生、検索、プレイリスト、履歴、Track Preference、特徴量 import、音量ノーマライズ、Track Adjustments、再生履歴 SQLite、Highlight 選曲補正を実装済み。
- `MyMusicWatch/` は iPhone `PlayerStore` を正本とする WatchConnectivity リモコン。Watch は音源、queue、再生ロジックを持たない。
- `analyzer/` は音楽特徴量／ラウドネスの Python Analyzer と、差分更新・複数 root 対応の Semantic v2 Analyzer を提供する。
- `analytics/` はアプリ export JSON を別 SQLite へ取り込むローカル FastAPI ツール。iOS・Analyzer と永続化を共有しない。

構造・保存境界は [ARCHITECTURE.md](ARCHITECTURE.md)、コード探索は [SOURCE_INDEX.md](SOURCE_INDEX.md) を参照する。

## 進行中

- 進行中の機能開発はない。次の Beta は一機能ずつ、対象テストと build を伴って追加する。

## 既知の課題・制約

- 実音源での全再生回帰、実機の background / lock screen / AirPods / Watch 接続、特徴量と音量補正の聴感は追加確認が必要。
- Playback History SQLite migration の長期運用・ディスク障害、Restore UI は追加確認または将来課題。
- Semantic v2 は game / OST で Vocal 判定の domain shift が残る。schema v1 は root ID を持たず、複製音源は import 時に曖昧になり得る。
- crossfade、streaming、server integration、offline download、ReplayGain は未実装。Deployment Target 26.5 は明示依頼なしに変更しない。

## 次のアクション

1. 新規 Beta は既存入口・保存契約・関連テストを検索してから最小単位で追加する。
2. リリース候補では実機の再生、background、lock screen / Control Center / AirPods / Watch、データ削除の非破壊性を確認する。
3. CI や lint 導入は、既存環境にないため別タスクで判断・記録する。
