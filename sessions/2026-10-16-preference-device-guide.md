# 評価の実機確認・疎結合の利用ガイド

- ユーザー依頼によりDocumentation/PreferenceInterchangeDeviceGuide.mdへ独立DB／Track ID対応／version付きJSON／手動Importの境界を記録。
- MyMusicのGood 8〜15、HomeStereoとの15→14往復、未設定と11の分離、再送、再起動、未変更曲とFavoriteの保全を手順化。backup互換の自動検証と実機未検証を区別した。
- 効率化は、今できる交換folder・片側ずつの編集・短い確認と、未実装の差分Preview／受領確認／folder選択支援を分離。自動同期や新機能は実装していない。
- CURRENTと既存DeviceValidationChecklistへ参照を追加。共通契約本文は変更せず、HomeStereo側のファイルも変更していない。
- 文書のみ。相対linkの存在・git diff --checkを確認。build／testは実行せず、test端末の作成・削除0。
