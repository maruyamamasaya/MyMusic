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
        case library
        case activity
    }

    static let all: [HomeCategory] = [
        HomeCategory(
            id: .myMusic,
            title: "マイミュージック",
            description: "お気に入り・最近再生した曲・おすすめ再生",
            systemImage: "heart.circle.fill",
            items: [
                HomeCategoryItem(title: "クイック再生", description: "直近のお気に入りとその他の曲を1:1で再生", systemImage: "play.square.stack", destination: .quickPlay),
                HomeCategoryItem(title: "未発見再生", description: "まだ再生していない曲をランダムに再生", systemImage: "sparkles", destination: .discoveryPlay),
                HomeCategoryItem(title: "最近追加した曲", description: "追加から2週間以内の曲をシャッフル再生", systemImage: "clock.badge.plus", destination: .recentlyAddedPlay),
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
                HomeCategoryItem(title: "作曲者", description: "作曲者別に表示", systemImage: "music.quarternote.3", destination: .composers)
            ]
        ),
        HomeCategory(
            id: .playback,
            title: "作業用",
            description: "長尺の音楽を作業のお供に",
            systemImage: "timer",
            items: [
                HomeCategoryItem(title: "作業用サイズ再生", description: "作業用の曲を項目別に探す", systemImage: "timer", destination: .workSizePlay)
            ]
        ),
        HomeCategory(
            id: .activity,
            title: "アクティビティ",
            description: "再生履歴・再生回数・よく聴く音楽を確認します",
            systemImage: "chart.bar.xaxis",
            items: [
                HomeCategoryItem(title: "再生分析", description: "履歴、再生回数、よく聴く曲をまとめて表示", systemImage: "chart.xyaxis.line", destination: .analytics),
                HomeCategoryItem(title: "音楽史", description: "年・月・日の記録から聴いてきた音楽を振り返る", systemImage: "calendar.badge.clock", destination: .musicHistory)
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

enum HomeDestination: Hashable {
    case nowPlaying
    case queue
    case quickPlay
    case discoveryPlay
    case recentlyAddedPlay
    case selectiveRandomPlay
    case repeatPlay
    case workSizePlay
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
    case analytics
    case musicHistory

    var localBackgroundImageName: String? {
        switch self {
        case .songs: "library-songs"
        case .albums: "library-albums"
        case .artists: "library-artists"
        case .genres: "library-genres"
        case .composers: "library-composers"
        case .analytics: "activity-analytics"
        case .musicHistory: "activity-music-history"
        default: nil
        }
    }
}
