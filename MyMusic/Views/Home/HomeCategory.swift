import Foundation

struct HomeCategory: Identifiable, Hashable {
    let id: ID
    let title: String
    let description: String
    let systemImage: String
    let items: [HomeCategoryItem]

    enum ID: String, Hashable {
        case playback
        case myMusic
        case explore
        case library
        case hiRes
        case activity
    }

    static let all: [HomeCategory] = [
        HomeCategory(
            id: .explore,
            title: "発掘する音楽",
            description: "ハイライトや、しばらく聴いていない音楽へ",
            systemImage: "sparkles",
            items: [
                HomeCategoryItem(title: "クイック再生", description: "直近のお気に入りとその他の曲を1:1で再生", systemImage: "play.square.stack", destination: .quickPlay),
                HomeCategoryItem(title: "発掘する音楽①", description: "直近24時間に聴いた曲を除いてクイック再生", systemImage: "sparkle.magnifyingglass", destination: .rediscoverPlay),
                HomeCategoryItem(title: "発掘する音楽②", description: "直近7日間に聴いた曲を除いてクイック再生", systemImage: "sparkle.magnifyingglass", destination: .rediscoverWeekPlay),
                HomeCategoryItem(title: "未発見", description: "まだ再生していない曲をランダムに再生", systemImage: "sparkles", destination: .discoveryPlay),
                HomeCategoryItem(title: "ピアノを聴く", description: "ピアノが中心の曲を特徴量から選んで再生", systemImage: "pianokeys", destination: .pianoPlay),
                HomeCategoryItem(title: "アンビエントを聴く", description: "アンビエントの特徴がある曲を選んで再生", systemImage: "waveform.path", destination: .ambientPlay)
            ]
        ),
        HomeCategory(
            id: .myMusic,
            title: "マイミュージック",
            description: "お気に入り・最近再生した曲・おすすめ再生",
            systemImage: "heart.circle.fill",
            items: [
                HomeCategoryItem(title: "次に再生する", description: "ランダムな30曲から気分で選んでキューに追加", systemImage: "text.line.first.and.arrowtriangle.forward", destination: .manualQueue),
                HomeCategoryItem(title: "あとで聴く", description: "追加した曲を一度聴くまで表示", systemImage: "text.badge.plus", destination: .listenLater),
                HomeCategoryItem(title: "最近追加した曲", description: "追加から2週間以内の曲をシャッフル再生", systemImage: "clock", destination: .recentlyAddedPlay),
                HomeCategoryItem(title: "選択してランダム再生", description: "最初の曲を選んで同じジャンルをランダム再生", systemImage: "shuffle.circle", destination: .selectiveRandomPlay),
                HomeCategoryItem(title: "リピート曲再生", description: "よく聴く曲からランダムに再生", systemImage: "repeat", destination: .repeatPlay),
                HomeCategoryItem(title: "お気に入り", description: "お気に入りに登録した曲", systemImage: "heart.fill", destination: .favorites),
                HomeCategoryItem(title: "お気に入りアルバム", description: "一覧から選んでランダム再生", systemImage: "square.stack.fill", destination: .favoriteAlbums),
                HomeCategoryItem(title: "お気に入りアーティスト", description: "一覧から選んでランダム再生", systemImage: "person.2.fill", destination: .favoriteArtists),
                HomeCategoryItem(title: "最近再生した曲", description: "最近聴いた曲を新しい順に表示", systemImage: "clock.arrow.circlepath", destination: .recentTracks)
            ]
        ),
        HomeCategory(
            id: .library,
            title: "ライブラリ",
            description: "曲・アルバム・アーティストなどから探します",
            systemImage: "music.note.house.fill",
            items: [
                HomeCategoryItem(title: "曲", description: "ライブラリ内のすべての曲", systemImage: "music.note", destination: .songs),
                HomeCategoryItem(title: "アルバム", description: "アルバム別に表示", systemImage: "square.stack", destination: .albums),
                HomeCategoryItem(title: "アーティスト", description: "アーティスト別に表示", systemImage: "music.mic", destination: .artists),
                HomeCategoryItem(title: "ジャンル", description: "ジャンル別に表示", systemImage: "guitars", destination: .genres),
                HomeCategoryItem(title: "作曲者", description: "作曲者別に表示", systemImage: "music.quarternote.3", destination: .composers),
                HomeCategoryItem(title: "年", description: "音源のタグの年から探す", systemImage: "calendar", destination: .years)
            ]
        ),
        HomeCategory(
            id: .playback,
            title: "作業用",
            description: "指定したBGMを作業のお供に",
            systemImage: "timer",
            items: [
                HomeCategoryItem(title: "作業用BGM再生", description: "作業用の曲を項目別に探す", systemImage: "timer", destination: .workSizePlay)
            ]
        ),
        HomeCategory(
            id: .activity,
            title: "アクティビティ",
            description: "再生履歴・再生回数・よく聴く音楽を確認します",
            systemImage: "chart.bar.xaxis",
            items: [
                HomeCategoryItem(title: "Weekly", description: "今週・先週・先々週のアーティスト上位100組（Beta）", systemImage: "calendar", destination: .weeklyRanking),
                HomeCategoryItem(title: "ランキング", description: "インスト・ボーカルのアーティスト上位100組", systemImage: "trophy.fill", destination: .artistRanking),
                HomeCategoryItem(title: "再生分析", description: "履歴、再生回数、よく聴く曲をまとめて表示", systemImage: "chart.xyaxis.line", destination: .analytics),
                HomeCategoryItem(title: "音楽史", description: "年・月・日の記録から聴いてきた音楽を振り返る", systemImage: "calendar.badge.clock", destination: .musicHistory),
                HomeCategoryItem(title: "最近の音楽傾向", description: "聴く音楽の変化を時系列で見る", systemImage: "waveform.path.ecg", destination: .recentMusicTrends)
            ]
        ),
        HomeCategory(
            id: .hiRes,
            title: "ハイレゾ",
            description: "高解像度のロスレス音源を専用出力で再生",
            systemImage: "waveform.badge.magnifyingglass",
            items: [
                HomeCategoryItem(title: "ハイレゾ音源", description: "専用ライブラリとUSB DAC出力", systemImage: "waveform.circle.fill", destination: .hiResLibrary)
            ]
        )
    ]
}

struct HomeCategoryItem: Identifiable, Hashable {
    let title: String
    let description: String
    let systemImage: String
    let destination: HomeDestination

    var id: HomeDestination { destination }

    var localBackgroundImageName: String? {
        destination.localBackgroundImageName
    }
}

nonisolated enum HomeDestination: Hashable, Sendable {
    case nowPlaying
    case queue
    case manualQueue
    case ambientPlay
    case pianoPlay
    case quickPlay
    case rediscoverPlay
    case rediscoverWeekPlay
    case discoveryPlay
    case listenLater
    case recentlyAddedPlay
    case selectiveRandomPlay
    case repeatPlay
    case workSizePlay
    case hiResLibrary
    case workPlaylists
    case favorites
    case favoriteAlbums
    case favoriteArtists
    case recentTracks
    case playlists
    case tunings
    case songs
    case albums
    case artists
    case genres
    case composers
    case years
    case analytics
    case weeklyRanking
    case artistRanking
    case musicHistory
    case recentMusicTrends

    var localBackgroundImageName: String? {
        switch self {
        case .ambientPlay: "ambient-crystal-lake-v1"
        case .pianoPlay: "piano-crystal-v1"
        case .manualQueue: "manual-queue-v1"
        case .songs: "library-songs-v2"
        case .albums: "library-albums-v2"
        case .artists: "library-artists-v2"
        case .genres: "library-genres-v2"
        case .composers: "library-composers-v2"
        case .years: "library-years"
        case .hiResLibrary: "library-hires-v1"
        case .artistRanking: "activity-ranking"
        case .weeklyRanking: "activity-weekly-ranking-v1"
        case .analytics: "activity-analytics-v2"
        case .musicHistory: "activity-music-history-v2"
        case .recentMusicTrends: "activity-music-trends"
        case .workSizePlay: "work-bgm-background"
        default: nil
        }
    }
}
