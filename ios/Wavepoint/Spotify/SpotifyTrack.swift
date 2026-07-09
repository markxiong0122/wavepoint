import Foundation

struct SpotifyTrack: Identifiable, Equatable, Sendable {
  let id: String
  let uri: String
  let name: String
  let artistNames: [String]
  let artworkURL: URL?
  let previewURL: URL?
  let spotifyURL: URL
  let durationMilliseconds: Int
  let addedAt: Date

  var artistLine: String {
    artistNames.joined(separator: ", ")
  }
}
