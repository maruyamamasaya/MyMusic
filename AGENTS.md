# MyMusic Development Guide

## Architecture

View
↓
Store
↓
Service
↓
Model / Framework

## Rules

- SwiftUIを使用
- iPhone優先
- Viewにビジネスロジックを書かない
- AVFoundationをViewから直接触らない
- 1ファイル1責務
- 巨大なViewを作らない
- 共通UIはComponentsへ分離
- 再生処理はAudioPlayerServiceへ集約
- 状態管理はStoreへ集約
- 既存機能を壊さない
- 不要な外部ライブラリを追加しない
- Apple標準Frameworkを優先
- 変更後はビルド確認する
- 高音質を重視するため、音源を不要に再エンコード・変換しない。
