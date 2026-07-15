import Foundation

enum ReviewDemoError: LocalizedError, Equatable {
  case missingPreview

  var errorDescription: String? {
    "The local demo preview is missing. Please reinstall Wavepoint."
  }
}

struct ReviewDemoLibraryService: CleanupLibraryServing {
  let provider = MusicProvider.appleMusic
  private let previewURL: URL?

  init(
    previewURL: URL? = Bundle.main.url(
      forResource: "wavepoint-demo-preview",
      withExtension: "m4a"
    )
  ) {
    self.previewURL = previewURL
  }

  func fetchLibraryTracks() async throws -> [LibraryTrack] {
    guard let previewURL else { throw ReviewDemoError.missingPreview }
    return Self.makeTracks(previewURL: previewURL)
  }

  func commit(trackIDs: [String]) async throws -> CleanupCommitResult {
    .removed(count: trackIDs.count)
  }

  private static func makeTracks(previewURL: URL) -> [LibraryTrack] {
    let titles = [
      "Basement Polaroid",
      "Borrowed Moonlight",
      "Cassette Weather",
      "Corner Store Soul",
      "Last Train Home",
      "Neon After Rain",
      "Sunday on Repeat",
      "The Quiet Side",
      "Velvet Detour",
      "Window Seat Radio",
    ]
    let artists = [
      "The Dust Jackets",
      "Wavepoint Radio",
      "Side B Society",
      "Needle & Thread",
      "The Lost Receipts",
    ]

    return (1...50).map { index in
      LibraryTrack(
        id: "demo-\(index)",
        provider: .appleMusic,
        playbackID: "",
        commitID: "demo-\(index)",
        title: "\(titles[(index - 1) % titles.count]) · \(index)",
        artistNames: [artists[(index - 1) % artists.count]],
        artworkURL: nil,
        previewURL: previewURL,
        destinationURL: nil,
        durationMilliseconds: 20_000,
        addedAt: Calendar(identifier: .gregorian).date(
          byAdding: .month,
          value: index * 2,
          to: Date(timeIntervalSince1970: 978_307_200)
        )
      )
    }
  }
}
