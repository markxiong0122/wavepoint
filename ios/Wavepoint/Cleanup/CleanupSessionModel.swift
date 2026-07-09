import Foundation
import Observation

enum CleanupSessionState: Equatable, Sendable {
  case idle
  case loading
  case deciding
  case reviewing
  case committing
  case complete(CleanupSummary)
  case failed(String)
}

struct CleanupSummary: Equatable, Sendable {
  let decisionCount: Int
  let removedCount: Int
}

enum CleanupOutcome: Equatable, Sendable {
  case keep
  case remove
}

struct CleanupDecision: Equatable, Sendable {
  let track: SpotifyTrack
  let outcome: CleanupOutcome
}

@MainActor
@Observable
final class CleanupSessionModel {
  private(set) var state: CleanupSessionState = .idle
  private(set) var deck: [SpotifyTrack] = []
  private(set) var decisions: [CleanupDecision] = []

  private let service: any SpotifyLibraryServing
  private let deckBuilder: CleanupDeckBuilder

  init(
    service: any SpotifyLibraryServing,
    deckBuilder: CleanupDeckBuilder = CleanupDeckBuilder()
  ) {
    self.service = service
    self.deckBuilder = deckBuilder
  }

  var currentTrack: SpotifyTrack? {
    guard decisions.count < deck.count else { return nil }
    return deck[decisions.count]
  }

  var stagedRemovals: [SpotifyTrack] {
    decisions.compactMap { decision in
      decision.outcome == .remove ? decision.track : nil
    }
  }

  var completedCount: Int { decisions.count }
  var totalCount: Int { deck.count }

  func load() async {
    state = .loading

    do {
      async let savedTracks = service.fetchSavedTracks()
      async let recentIDs = service.fetchRecentlyPlayedTrackIDs()
      deck = try await deckBuilder.build(
        from: savedTracks,
        recentTrackIDs: recentIDs
      )
      decisions = []
      state =
        deck.isEmpty
        ? .complete(CleanupSummary(decisionCount: 0, removedCount: 0))
        : .deciding
    } catch {
      state = .failed(error.localizedDescription)
    }
  }

  func keepCurrentTrack() {
    decide(.keep)
  }

  func removeCurrentTrack() {
    decide(.remove)
  }

  func undo() {
    guard state == .deciding, !decisions.isEmpty else { return }
    decisions.removeLast()
  }

  func beginReview() {
    guard state == .deciding else { return }
    finishDeciding()
  }

  func cancelReview() {
    guard state == .reviewing else { return }
    state = .deciding
  }

  func confirmRemovals() async {
    guard state == .reviewing else { return }
    state = .committing

    do {
      let removedCount = try await service.removeFromLibrary(
        uris: stagedRemovals.map(\.uri)
      )
      state = .complete(
        CleanupSummary(
          decisionCount: decisions.count,
          removedCount: removedCount
        )
      )
    } catch {
      state = .failed(error.localizedDescription)
    }
  }

  func returnToReview() {
    guard case .failed = state, !stagedRemovals.isEmpty else { return }
    state = .reviewing
  }

  func reset() {
    state = .idle
    deck = []
    decisions = []
  }

  private func decide(_ outcome: CleanupOutcome) {
    guard state == .deciding, let currentTrack else { return }
    decisions.append(CleanupDecision(track: currentTrack, outcome: outcome))
    if decisions.count == deck.count {
      finishDeciding()
    }
  }

  private func finishDeciding() {
    if stagedRemovals.isEmpty {
      state = .complete(
        CleanupSummary(decisionCount: decisions.count, removedCount: 0)
      )
    } else {
      state = .reviewing
    }
  }
}
