# 車窓動画の選択一覧・音楽との独立再生 — 2026-10-17

## 変更

- BGMパネル左端の白いaccent線を削除。下端の1pt進捗ラインは維持。
- 車窓映像のactive条件から音楽isPlayingを除外。曲切替・pause・stop後も映像を流す。車窓を閉じると解放、scene非activeではpauseする。
- 設定に複数動画の保存一覧と選択checkmarkを追加。追加した動画を選択状態にし、既存動画は保持する。選び直しはコピーなしでmanifestへ保存。
- 各動画の登録解除は確認付き。選択中の解除は残りの先頭へ切替、最後の解除は未登録へ。元のFiles／iCloud素材は削除しない。
- current.jsonをSceneryVideoCollection v2へ拡張。旧単一動画の形式はそのまま読め、最初の変更時に既存素材を保持して移行する。破損／未知versionは黙って空一覧で上書きしない。
- 追加時は完全copy＋映像検証後に最新一覧を再読込してmanifestをatomic保存。登録一覧にないコピーだけをbest effortで掃除。動画の自動切替・複数playlistは対象外で、設定で流す1本を差し替える。
- CURRENT／ARCHITECTURE更新。保存形式は車窓専用で、音楽ライブラリ・音源・JSON交換・署名は変更しない。

## 検証

- iPhone／埋め込みWatch generic Simulator Debug buildで検証。
- scripts/check-scenery-video.swiftを拡張しmacOSの実Model／Service／Storeで成功:
  - 従来のランダム範囲、無音18fps、seek・pause・解放、不正素材拒否、bytes一致、元素材移動後の復元。
  - 複数追加で既存動画保持、選択の新Service復元、設定で再生せず選択、選択／非選択／最後の1本の解除。
  - 旧単一manifestの読込と複数形式への移行時の素材保全。
  - 破損manifestへの追加失敗でmanifestと登録済み素材を保持。
- git diff --checkで確認。専用lintなし。XCTest／Simulator testは実行せず、test端末作成0／削除0。Xcode data削除なし。

## 未確認・制約

- 動画の選択切り替えと音楽停止後の映像継続は下記のユーザー報告により実機確認済み。個別削除・旧登録移行・background復帰の実機結果は個別には未報告。
- 選択は次回の車窓表示から反映。同時に別画面で管理・再生するフローは想定しない。
- 複数分の端末容量を使い、同じ素材を再追加した場合も別コピーとして扱う。重複検出・rename・reorderはない。
- copyや旧コピー掃除のbest effort制約は維持。アプリ独自外部backupの対象には含めない。


## Vesperaデプロイ — 2026-10-17

ユーザーの明示依頼でGit rootと作業ツリーを確認し、check-iphone.sh成功後にdeploy-iphone.shを実行。未コミット変更を保持して現コードを導入した。

- Project: MyMusic.xcodeproj / Scheme: MyMusic / Product: MyMusic
- Configuration: Debug / Bundle Identifier: maruyama.MyMusic
- Device: Vespera（iPhone 17e） / UDID: 00008150-000C54280E33401C
- Build: BUILD SUCCEEDED / Install: succeeded / Launch: succeeded
- デプロイ後、動画の選択切り替えと音楽停止後の映像継続をユーザーが実機確認（下記）。
- アプリコード・署名・識別子・Team・Deployment Targetの追加変更なし。
- XCTest未実行。test端末作成0／削除0、XCTestDevices残容量12K。Xcode data削除なし。git diff --checkで確認。


## ユーザー実機確認・コミット — 2026-10-17

ユーザーが「動画の選択切り替えも、音楽を止めても動画が流れ続けるのも問題なかった」と報告。Vesperaでこの2項目を実機確認済みとしてCURRENTと本sessionへ記録した。報告にない個別操作へ確認範囲を広げない。

ユーザーの明示依頼で、今回の複数動画一覧・選択・旧形式引継ぎ、音楽停止との非連動、BGM左accent線削除、統合チェックと文書をまとめてコミット・GitHubへpushする。コード追加変更はないため、成功済みbuild／統合チェックを再実行せず、stage差分とgit diff --checkを確認する。XCTest追加実行なし、test端末作成0／削除0、Xcode data削除なし。
