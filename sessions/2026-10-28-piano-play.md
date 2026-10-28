# ピアノを聴く Beta

- Context Guard: MATCH。MyMusic Git root確認、既存変更を保持。
- 発掘する音楽へ「ピアノを聴く」を追加。画像生成は行わず対象曲のArtworkを使用。
- PianoSelectionPolicyを共通化。pianoがfinite・0...1内かつ0.5以上の曲を採用し重複除外。暫定cutoff、校正済み確率ではない。
- 既存Semantic資料のpiano値域を踏まえ保守的な0.5から開始。正解ラベルによる精度検証は未実施、実際の聴感で調整が必要。
- PlaybackHistoryStore.pianoPlayTracksはチューニング済みtracksから上記条件と通常ランダム再生適格性を適用し均等shuffle。ボーカル・弦楽器・ジャンルで除外せず、未解析／条件外へのfallbackなし。
- Home snapshotと実再生で同policyを共有。古い代表曲は再生時に現在の候補で再検証。
- 空候補では既存再生を変更せず案内alert。詳細destination側も同じ選曲条件。
- CURRENT／ARCHITECTURE更新。JSON・解析model・音声・署名設定は変更なし。

## 検証

- 指定iPhone 17e Simulatorの既存端末を利用、並列test無効。
- cutoff境界・欠落・NaN／無限／範囲外・チューニング入力範囲・声あり許可・重複除外・空候補をテスト。
- 実機・実画面・実ライブラリでの聴感は未確認、実機未反映。

- 関連17テスト成功（PianoSelectionPolicyTests 2件・HomeCategoryTests 9件・HomeRepresentativeTrackPolicyTests 6件）。
- 指定destinationのDebug build成功（BUILD SUCCEEDED）。git diff --check成功。専用lint設定なし。
- テスト端末作成0・削除0。XCTestDevicesのUUID folderは開始前／終了後とも0件、残存12 KiB。削除なし。
- ログ: /tmp/mymusic-piano-test.log、/tmp/mymusic-piano-build.log。
