import Foundation

struct CleanupProviderPresentation: Equatable, Sendable {
  let provider: MusicProvider

  var destructiveActionLabel: String {
    provider == .spotify ? "× REMOVE" : "× TOSS"
  }

  func reviewActionTitle(count: Int) -> String {
    provider == .spotify
      ? "REMOVE \(count) FROM LIKED SONGS"
      : "SEND \(count) TO THE DUMPSTER"
  }

  var reviewTrustCopy: String {
    switch provider {
    case .spotify:
      "Nothing has changed in Spotify yet. These are the songs staged for removal."
    case .appleMusic:
      "Apple doesn't let Wavepoint remove these automatically. This creates or updates a playlist; the songs stay in your Library until you delete them in Music."
    }
  }

  func completionTitle(hasDecisions: Bool) -> String {
    guard hasDecisions else { return "Nothing to clean." }
    return provider == .spotify ? "That feels lighter." : "DUMPSTER READY"
  }

  var completionInstructions: String {
    switch provider {
    case .spotify:
      ""
    case .appleMusic:
      "In the Dumpster, touch and hold each song and choose Delete from Library. Remove from Playlist alone does not delete it from your Library."
    }
  }

  var destinationActionTitle: String {
    provider == .spotify ? "OPEN IN SPOTIFY" : "OPEN IN MUSIC"
  }

  func completionStatLine(decisionCount: Int, affectedCount: Int) -> String {
    provider == .spotify
      ? "\(decisionCount) decided  ·  \(affectedCount) removed"
      : "\(decisionCount) decided  ·  \(affectedCount) in Dumpster"
  }

  func committingTitle(count: Int) -> String {
    provider == .spotify
      ? "REMOVING \(count) SONGS…"
      : "SENDING \(count) TO THE DUMPSTER…"
  }

  var loadingTitle: String {
    provider == .spotify
      ? "DIGGING THROUGH LIKED SONGS…"
      : "DIGGING THROUGH YOUR LIBRARY…"
  }

  var autoplayStartingDetail: String {
    provider == .spotify
      ? "Spotify will open with your first cleanup track."
      : "Starting your first Apple Music cleanup track."
  }

  var errorEyebrow: String {
    provider == .spotify ? "SPOTIFY HIT A SNAG" : "APPLE MUSIC HIT A SNAG"
  }
}
