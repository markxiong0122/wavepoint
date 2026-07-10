import Foundation

enum MusicProvider: String, Equatable, Sendable {
  case spotify
  case appleMusic
}

struct LibraryTrack: Identifiable, Equatable, Sendable {
  let id: String
  let provider: MusicProvider
  let playbackID: String
  let commitID: String
  let title: String
  let artistNames: [String]
  let artworkURL: URL?
  let previewURL: URL?
  let destinationURL: URL?
  let durationMilliseconds: Int
  let addedAt: Date?

  var artistLine: String {
    artistNames.joined(separator: ", ")
  }
}
