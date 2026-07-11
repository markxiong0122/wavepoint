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
  let provider: MusicProvider
  let decisionCount: Int
  let result: CleanupCommitResult

  var affectedCount: Int { result.committedCount }
}

enum CleanupOutcome: Equatable, Sendable {
  case keep
  case remove
}

struct CleanupDecision: Equatable, Sendable {
  let track: LibraryTrack
  let outcome: CleanupOutcome
}

@MainActor
@Observable
final class CleanupSessionModel {
  private(set) var state: CleanupSessionState = .idle
  private(set) var deck: [LibraryTrack] = []
  private(set) var decisions: [CleanupDecision] = []
  private(set) var alreadyCommittedCount = 0

  private let service: any CleanupLibraryServing
  private let deckBuilder: CleanupDeckBuilder
  private let analytics: any AnalyticsCapturing
  private let crashReporting: any CrashReporting
  private var committedTrackIDs: Set<String> = []

  init(
    service: any CleanupLibraryServing,
    deckBuilder: CleanupDeckBuilder = CleanupDeckBuilder(),
    analytics: any AnalyticsCapturing = NoOpAnalytics(),
    crashReporting: any CrashReporting = NoOpCrashReporting()
  ) {
    self.service = service
    self.deckBuilder = deckBuilder
    self.analytics = analytics
    self.crashReporting = crashReporting
  }

  var currentTrack: LibraryTrack? {
    guard decisions.count < deck.count else { return nil }
    return deck[decisions.count]
  }

  var stagedRemovals: [LibraryTrack] {
    decisions.compactMap { decision in
      decision.outcome == .remove && !committedTrackIDs.contains(decision.track.commitID)
        ? decision.track
        : nil
    }
  }

  var provider: MusicProvider { service.provider }
  var presentation: CleanupProviderPresentation {
    CleanupProviderPresentation(provider: provider)
  }

  var completedCount: Int { decisions.count }
  var totalCount: Int { deck.count }
  var requiresProviderChangeConfirmation: Bool { !decisions.isEmpty }

  func load() async {
    state = .loading

    do {
      deck = try await deckBuilder.build(
        from: service.fetchLibraryTracks()
      )
      decisions = []
      committedTrackIDs = []
      alreadyCommittedCount = 0
      analytics.capture(.cleanupDeckLoaded(AnalyticsProvider(provider)))
      state =
        deck.isEmpty
        ? .complete(
          CleanupSummary(provider: provider, decisionCount: 0, result: .noChanges)
        )
        : .deciding
    } catch {
      crashReporting.record(.libraryLoad)
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
      let result = try await service.commit(trackIDs: stagedRemovals.map(\.commitID))
      let finalResult: CleanupCommitResult
      if case .removed(let count) = result {
        finalResult = .removed(count: alreadyCommittedCount + count)
      } else {
        finalResult = result
      }
      state = .complete(
        CleanupSummary(
          provider: provider,
          decisionCount: decisions.count,
          result: finalResult
        )
      )
      analytics.capture(.cleanupSessionCompleted(AnalyticsProvider(provider)))
    } catch CleanupCommitError.partial(let committedCount, _) {
      crashReporting.record(.commit)
      let committedTracks = stagedRemovals.prefix(committedCount)
      committedTrackIDs.formUnion(committedTracks.map(\.commitID))
      alreadyCommittedCount += committedTracks.count
      state = .failed(
        CleanupCommitError.partial(
          committedCount: alreadyCommittedCount,
          remainingCount: stagedRemovals.count
        ).localizedDescription
      )
    } catch {
      crashReporting.record(.commit)
      state = .failed(error.localizedDescription)
    }
  }

  func returnToReview() {
    guard case .failed = state, !stagedRemovals.isEmpty else { return }
    state = .reviewing
  }

  func reset() {
    if !decisions.isEmpty, !isComplete {
      analytics.capture(.cleanupSessionAbandoned(AnalyticsProvider(provider)))
    }
    state = .idle
    deck = []
    decisions = []
    committedTrackIDs = []
    alreadyCommittedCount = 0
  }

  private var isComplete: Bool {
    if case .complete = state { return true }
    return false
  }

  private func decide(_ outcome: CleanupOutcome) {
    guard state == .deciding, let currentTrack else { return }
    if decisions.isEmpty {
      analytics.capture(.firstDecisionCompleted(AnalyticsProvider(provider)))
    }
    decisions.append(CleanupDecision(track: currentTrack, outcome: outcome))
    if decisions.count == deck.count {
      finishDeciding()
    }
  }

  private func finishDeciding() {
    if stagedRemovals.isEmpty {
      state = .complete(
        CleanupSummary(
          provider: provider,
          decisionCount: decisions.count,
          result: alreadyCommittedCount == 0
            ? .noChanges
            : .removed(count: alreadyCommittedCount)
        )
      )
      analytics.capture(.cleanupSessionCompleted(AnalyticsProvider(provider)))
    } else {
      state = .reviewing
      analytics.capture(.reviewOpened(AnalyticsProvider(provider)))
    }
  }
}
