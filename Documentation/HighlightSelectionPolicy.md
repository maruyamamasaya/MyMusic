# Highlight Selection Policy

この文書は、ハイライト再生で「次にどの曲を並べるか」の現行仕様を示す。Highlight Candidateの区間解析・位置選択・再生制御は対象外である。パラメータを変更するときは、コード、テスト、この文書を同時に更新する。

## モード

| モード | 目的 |
| --- | --- |
| シャッフル | 音響特徴へ方向付けせず、Preference、Overplay、直近Highlight再生を反映する。 |
| アガる | energy、aggressive、bright、補助的なdrumAndBassが高い曲を優先する。 |
| 穏やか | calm、ambient、pianoが高い曲を優先する。 |
| 発掘 | 未再生、低再生、長期間再生していない曲を優先する。Preferenceは同程度の発掘候補間で使う。 |

特徴量がない曲はアガる／穏やかで適合度0.5の中立とし、除外しない。Boredom中または永久Shuffle非表示の曲は、既存の通常shuffle eligibilityにより全モードから除外する。

## 選曲の優先順位

キューは先頭から1曲ずつ決める。同じ曲は候補から取り除くため、1キュー内で重複しない。

1. アガる／穏やか／発掘では、モード適合度を0.05幅のbandへ分け、最も高いbandだけを比較する。多様性で低いbandが追い越すことはない。シャッフルはmode bandを使わない。
2. 直前または短い選択済み履歴と同じArtist／Albumの候補へ反復penaltyを付け、penaltyが小さい候補を優先する。これは除外ではなく、他候補を置いた後には再び選択できる。
3. 同じdiversity penalty内で、`Preference × Overplay × Recent Highlight`を比較する。
4. シャッフル以外では、直前曲との主要特徴量距離が極端に近い候補だけ、前項scoreを3%下げる。これは大きなPreference差を消さない。
5. scoreへ±0.5%のRandom jitterを掛ける。完全同点はTrack ID順で安定化する。

モード切替時は現在曲までを維持し、その曲列を直近文脈として後続キューだけを同じ手順で再構築する。

## パラメータ

| 名前 | 値 | 理由と強さ |
| --- | ---: | --- |
| `modeBandWidth` | 0.05 | 近い適合度だけを同群とみなし、異なるbandは他の全補正より強くする。 |
| `artistImmediatePenalty` | 4 | 直前と同一Artistを強く後退させる。 |
| `artistRecentWindow` | 3曲 | 短い連続感だけを見る。 |
| `artistRecentPenalty` | 2 | 直前一致より弱いが、同band内ではPreferenceより先に扱う。 |
| `albumImmediatePenalty` | 4 | 直前と同一Albumを強く後退させる。Album Artist＋Album名で比較する。 |
| `albumRecentWindow` | 5曲 | Album偏重をArtistより少し長く見る。 |
| `albumRecentCountThreshold` | 2曲 | 直近5曲に同じAlbumが2曲以上ある場合だけ追加減点する。 |
| `albumRecentPenalty` | 3 | 単なる過去1回より、まとまったAlbum偏重を強く避ける。 |
| `featureSimilarityDistanceThreshold` | 0.08未満 | 共通して有効な主要特徴量のRMS距離が非常に近い場合だけ反応する。 |
| `featureSimilarityPenalty` | 0.97倍 | 誤差レベルの補正。Artist／Album penaltyより弱く、大きなPreference差を消さない。 |
| `randomJitterRange` | 合計1%、±0.5% | ほぼ同scoreの順序だけを揺らす。mode bandとdiversity段階は逆転しない。 |
| Recent Highlight | 直近20回: 0.20倍、21〜50回: 0.60倍、以前: 1.00倍 | 同じ曲の短期反復を抑える。同一曲は最新出現位置を使い、除外しない。 |
| Preference | 既存0.01〜42のweight | 明示的な長期Preference。mode bandとArtist／Album多様性の後で比較する。 |
| Overplay | 既存1.0〜0.125のfactor | 短期的な聴きすぎを抑える。保存せず、既存計算を再利用する。 |

## 特徴量距離

`energy / calm / aggressive / bright / dark / ambient / piano / drumAndBass`のうち、直前曲と候補の双方に0〜1の有効値がある次元だけを使う。各差の二乗平均平方根（RMS）を距離とする。共通次元がなければ補正しない。シャッフルでは特徴量距離を一切使わない。

## 具体例

### Preference最大の逆モード曲

アガる適合度0.90の曲Aが低PreferenceかつRecent 0.20、適合度0.10の曲BがPreference最大でも、Aは高いmode bandにいるため先になる。PreferenceやRecent Highlightは異なるbandを逆転しない。

### 同じAlbumが続く場合

同じmode bandに曲A（直前と同じAlbum、Preference高）と曲B（別Album、Preference低）があれば、Bを先に置く。候補がAしか残っていない場合はAを通常どおり選択し、除外はしない。直近5曲に同じAlbumが2曲以上あれば追加penaltyも付く。

### 特徴量がほぼ同じ別曲

直前曲に対してRMS距離0.02の候補Aと0.20の候補Bが同じband・同じArtist/Album penalty・同じ基本scoreなら、Aだけ0.97倍となりBを先に置く。一方Aの基本scoreがBの2倍なら、0.97倍後もAが先であり、特徴多様性だけで大幅な順位逆転は起こらない。
