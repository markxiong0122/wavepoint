import Foundation

@MainActor
protocol DumpsterPlaylistStoring: AnyObject {
  var playlistID: String? { get set }
}

@MainActor
final class UserDefaultsDumpsterPlaylistStore: DumpsterPlaylistStoring {
  private static let playlistIDKey = "appleMusicDumpsterPlaylistID"
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  var playlistID: String? {
    get { defaults.string(forKey: Self.playlistIDKey) }
    set { defaults.set(newValue, forKey: Self.playlistIDKey) }
  }
}
