import Foundation

enum CleanupPresentationMode: Equatable, Sendable {
  case spotify
  case appleMusic
  case demo
}

struct CleanupProviderPresentation: Equatable, Sendable {
  let mode: CleanupPresentationMode

  init(provider: MusicProvider) {
    mode = provider == .spotify ? .spotify : .appleMusic
  }

  init(mode: CleanupPresentationMode) {
    self.mode = mode
  }

  static let demo = CleanupProviderPresentation(mode: .demo)

  var isDemo: Bool { mode == .demo }

  var destructiveActionLabel: String {
    switch mode {
    case .spotify: "× REMOVE"
    case .appleMusic: "× TOSS"
    case .demo: "× CUT"
    }
  }

  func reviewActionTitle(count: Int) -> String {
    switch mode {
    case .spotify: "REMOVE \(count) FROM LIKED SONGS"
    case .appleMusic: "SEND \(count) TO THE DUMPSTER"
    case .demo: "FINISH DEMO WITH \(count) \(count == 1 ? "CUT" : "CUTS")"
    }
  }

  var reviewTrustCopy: String {
    switch mode {
    case .spotify:
      "Nothing has changed in Spotify yet. These are the songs staged for removal."
    case .appleMusic:
      "Apple doesn't let Wavepoint remove these automatically. This creates or updates a playlist; the songs stay in your Library until you delete them in Music."
    case .demo:
      "This is a local demo library. Finishing the demo will not change Spotify, Apple Music, or anything on this iPhone."
    }
  }

  func completionTitle(hasDecisions: Bool) -> String {
    guard hasDecisions else { return "Nothing to clean." }
    return switch mode {
    case .spotify: "That feels lighter."
    case .appleMusic: "DUMPSTER READY"
    case .demo: "DEMO COMPLETE"
    }
  }

  var completionInstructions: String {
    switch mode {
    case .spotify:
      ""
    case .appleMusic:
      "In the Dumpster, touch and hold each song and choose Delete from Library. Remove from Playlist alone does not delete it from your Library."
    case .demo:
      "Nice work. These were fictional songs, so no music service or personal library was changed."
    }
  }

  var destinationActionTitle: String {
    switch mode {
    case .spotify: "OPEN IN SPOTIFY"
    case .appleMusic: "OPEN IN MUSIC"
    case .demo: "DEMO TRACK"
    }
  }

  func completionStatLine(decisionCount: Int, affectedCount: Int) -> String {
    switch mode {
    case .spotify: "\(decisionCount) decided  ·  \(affectedCount) removed"
    case .appleMusic: "\(decisionCount) decided  ·  \(affectedCount) in Dumpster"
    case .demo:
      "\(decisionCount) decided  ·  \(affectedCount) demo \(affectedCount == 1 ? "cut" : "cuts")"
    }
  }

  func committingTitle(count: Int) -> String {
    switch mode {
    case .spotify: "REMOVING \(count) SONGS…"
    case .appleMusic: "SENDING \(count) TO THE DUMPSTER…"
    case .demo: "FINISHING \(count) DEMO \(count == 1 ? "CUT" : "CUTS")…"
    }
  }

  var loadingTitle: String {
    switch mode {
    case .spotify: "DIGGING THROUGH LIKED SONGS…"
    case .appleMusic: "DIGGING THROUGH YOUR LIBRARY…"
    case .demo: "UNPACKING THE DEMO CRATE…"
    }
  }

  var autoplayStartingDetail: String {
    switch mode {
    case .spotify: "Spotify will open with your first cleanup track."
    case .appleMusic: "Starting your first Apple Music cleanup track."
    case .demo: "Starting a local sample. No music service will open."
    }
  }

  var errorEyebrow: String {
    switch mode {
    case .spotify: "SPOTIFY HIT A SNAG"
    case .appleMusic: "APPLE MUSIC HIT A SNAG"
    case .demo: "THE DEMO MISSED A BEAT"
    }
  }

  var exitActionTitle: String {
    switch mode {
    case .spotify: "SIGN OUT"
    case .appleMusic: "CHANGE MUSIC SERVICE"
    case .demo: "EXIT DEMO"
    }
  }
}
