# HomeStereo コンテキストガード導入用

この文書は、別Gitで開発するMacアプリ HomeStereo の `AGENTS.md` に組み込むための指示です。HomeStereo側の既存ガイドと統合し、実際のrepository root、技術構成、現在状態の参照先は導入先で確認してください。この文書の作成だけでは、HomeStereo側の設定へ適用されたことにはなりません。

## Project Context

- **Project Name:** HomeStereo
- **Purpose:** Macで手元の音源を探し、再生する独立したデスクトップ音楽プレイヤー。デスクトップの検索性、分析、統合的な設定を重視する。
- **MyMusicとの位置づけ:** MyMusicとHomeStereoは、それぞれ独立して利用できる対等なプレイヤーである。一方、製品方針ではiPhoneのMyMusicを中心に位置づける。HomeStereoはデスクトップでの検索・分析・統合的な設定を担う。この優先順位だけから、全データの正本がMyMusicにあるとは解釈しない。
- **Repository:** MyMusicとは別Gitで管理する。HomeStereoをMyMusicのMac target、同一repositoryのmodule、MyMusicのリモコンとして扱わない。
- **Expected Work:** HomeStereoの検索・分析・統合的な設定・ライブラリ・再生・データ管理、Mac固有の再生音響とスピーカー設定の保守・機能追加、およびMyMusicとの既存交換データ契約の保守。正当な新機能を固定的な機能一覧だけで拒否しない。
- **関連する別構成:** MyMusic repository内のPython AnalyzerとLocal／Static／Desktop Analyticsは、別GitのHomeStereoとは別の構成要素である。「Macアプリ」という呼称だけで同一視しない。
- **Clearly Unrelated Examples:** 別製品固有のEC／業務SaaS／ゲームの実装、MyMusicのiPhone／Watch固有画面や再生ServiceをHomeStereo内に存在する前提で変更する要求。Swift、Python、JavaScript、SQLite、API等の一般語だけでは不一致と判断しない。

## Project Context Guard

すべての要求について、実装、ファイル操作、依存追加、コマンド実行の前に、要求とProject Contextの整合性を判定する。

### MATCH

HomeStereo、その目的に沿う保守・機能追加、またはHomeStereo側のMyMusicデータ連携に明確に関係する要求。通常の調査・実装・検証へ進む。MyMusicが言及されているだけで拒否しない。

### UNCERTAIN

「Mac側」「検索」「同期」等の対象が曖昧、責務や交換契約の変更が大きい、または文脈が不足する要求。まず現在repositoryの文書、コード、履歴をread-onlyで確認し、MATCHまたはMISMATCHへ再判定する。必要なら実装前に対象を確認する。迷う場合はMISMATCHではなくUNCERTAINとする。

MyMusic側だけの変更を明示された場合は、関連プロジェクトへの依頼として対象repositoryの確認を求める。HomeStereoで代替実装を始めない。両repositoryの変更を明示された場合は、各rootと変更範囲を確認してから対応する。

### MISMATCH

別製品名、別製品固有の機能・class・file・directory、異なるplatform等、複数の矛盾したsignalから無関係な別プロジェクト向けと高い確信で判断できる要求。

直ちに停止し、Git root確認を含む追加command、ファイル変更、新規ファイル作成、依存追加、DB変更、commit、pushを行わない。回答には次だけを簡潔に示す。

- **Current Project:** HomeStereo
- **Reason:** MISMATCHと判断した理由
- **Conflicting Prompt Elements:** 要求内の具体的な不一致要素
- **No files were modified.**

## Repository Boundaries

1. MATCHまたはUNCERTAINのread-only調査を始める時だけ、`git rev-parse --show-toplevel`でrootを確認する。
2. 導入先のHomeStereo `AGENTS.md`を含むrepository rootと一致することを確認する。不一致なら変更を止める。
3. 原則としてHomeStereoのGit root内だけを読み書きする。隣接するMyMusic repositoryの変更を、HomeStereoの依頼に含まれるものと推測しない。
4. 別repositoryの調査・変更が必要な場合は、明示された依頼の対象と境界を確認する。既に明示された範囲について重ねて許可を求める必要はない。
5. 両repositoryの作業を依頼された場合も、変更、検証、Git状態をrepositoryごとに扱う。

## 疎結合のデータ連携

- HomeStereoの「統合的な設定」はデスクトップ側の役割を示す。具体的な編集対象と受け渡し方法は各契約で定め、両アプリの全設定を一律に同期する権限とは解釈しない。
- Mac側の再生音響・スピーカー設定はHomeStereo固有の責務であり、MyMusicとのデータ連携とは独立した方向で発展させる。iPhone側の出力環境へ合わせるために制限したり、MyMusicへ移植・同期・共通化したりすることを前提にしない。共有候補の設定とMac固有の音響設定を区別し、明示された交換契約の対象だけを受け渡す。
- 各アプリが自分の内部保存データと再生状態を所有する。相手のApplication Support、SQLite、cache、Storeへ直接書き込まない。
- 連携境界はversion付き交換データのImport／Exportとする。内部Model、DB schema、再生エンジンの共有を前提にしない。
- 現在MyMusic側で確認できる連携は、Library JSONの`trackID`・`relativePath`・`fileSize`によるHomeStereoの曲との関連付け、およびHomeStereo由来Playback Events JSONのMyMusicへの手動Importである。HomeStereo側の具体的実装は導入時に確認する。
- 絶対pathや端末固有のFile Provider prefixを共通の曲Identityとして扱わない。照合できない曲や曖昧な候補を推測で統合しない。
- MyMusic側のPlayback Events Importは文書全体の検証後に対象期間・現在Libraryへの解決を行い、新規event IDだけを保存する。既存event IDを重複集計せず、保存済みの`platform`を維持する。この受信仕様をHomeStereo側の全保存仕様として一般化しない。
- 新たな交換項目や契約変更では、送信元・受信先、データの所有者、schema version、旧データ互換、照合方法、重複排除、衝突時の扱いを明記する。
- 「MyMusicが中心」という製品方針から、Favorite／Preference／Playlist等の競合解決や自動上書きを導かない。個々の契約に定義がなければ未決定として確認する。
- 自動同期、共有DB、network service、共通library化は、既存の手動連携から推測して実装しない。明示依頼時に別の設計変更として検討する。
- 音源を不要に再エンコード、トランスコード、ビットレート低下、サンプルレート変更しない。

## 作業開始・終了時

作業開始時はこのガードに続き、HomeStereo側の現在状態・architecture・関連する判断記録と実装を確認する。未確認の技術構成、機能、MyMusicとの互換性を既成事実として扱わない。

作業終了時は、変更したrepositoryとファイル、連携契約への影響、実施した検証、相手側に必要な対応、未確認事項を簡潔に報告する。
