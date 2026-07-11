#if DEBUG && targetEnvironment(simulator)
  import Foundation

  enum AppleMusicSimulatorDemoScenario: String, Equatable, Sendable {
    case eligible
    case permissionDenied = "permission-denied"
    case accountNotReady = "account-not-ready"
    case serviceUnavailable = "service-unavailable"
    case subscriptionRequired = "subscription-required"
    case syncLibraryRequired = "sync-library-required"

    var eligibility: AppleMusicEligibility {
      switch self {
      case .eligible: .eligible
      case .permissionDenied: .permissionDenied
      case .accountNotReady: .accountNotReady
      case .serviceUnavailable: .serviceUnavailable
      case .subscriptionRequired: .subscriptionRequired
      case .syncLibraryRequired: .syncLibraryRequired
      }
    }
  }

  enum AppleMusicSimulatorDemo {
    private static let launchArgument = "-WavepointAppleMusicDemo"

    static func scenario(arguments: [String]) -> AppleMusicSimulatorDemoScenario? {
      guard let flagIndex = arguments.firstIndex(of: launchArgument) else { return nil }
      let valueIndex = arguments.index(after: flagIndex)
      guard arguments.indices.contains(valueIndex) else { return .eligible }
      return AppleMusicSimulatorDemoScenario(rawValue: arguments[valueIndex]) ?? .eligible
    }

    @MainActor
    static func dependencies(
      for scenario: AppleMusicSimulatorDemoScenario
    ) -> AppleMusicAppDependencies {
      AppleMusicAppDependencies(
        authorizer: SimulatorAppleMusicAuthorizer(eligibility: scenario.eligibility),
        selectionStore: SimulatorMusicProviderSelectionStore(),
        cleanupService: SimulatorAppleMusicLibraryService(),
        playerClient: SimulatorAppleMusicPlayerClient()
      )
    }
  }

  private struct SimulatorAppleMusicAuthorizer: AppleMusicAuthorizing {
    let eligibility: AppleMusicEligibility

    func currentEligibility() async throws -> AppleMusicEligibility { eligibility }
    func requestEligibility() async throws -> AppleMusicEligibility { eligibility }
  }

  @MainActor
  private final class SimulatorMusicProviderSelectionStore: MusicProviderSelectionStoring {
    var selectedProvider: MusicProvider? = .appleMusic
  }

  private actor SimulatorAppleMusicLibraryService: CleanupLibraryServing {
    nonisolated let provider = MusicProvider.appleMusic
    private let tracks = (1...12).map { index in
      LibraryTrack(
        id: "apple-demo-\(index)",
        provider: .appleMusic,
        playbackID: "apple-demo-\(index)",
        commitID: "apple-demo-\(index)",
        title: index == 2
          ? "A Very Long Apple Music Song Title That Exercises The Real Card Layout"
          : "Demo Track \(index)",
        artistNames: [index.isMultiple(of: 2) ? "The Simulators" : "Wavepoint Radio"],
        artworkURL: URL(string: "https://picsum.photos/seed/wavepoint-\(index)/800/800"),
        previewURL: nil,
        destinationURL: URL(string: "https://music.apple.com/us/song/apple-demo-\(index)"),
        durationMilliseconds: 180_000,
        addedAt: Date(timeIntervalSince1970: TimeInterval(index) * 31_536_000)
      )
    }

    func fetchLibraryTracks() async throws -> [LibraryTrack] { tracks }

    func commit(trackIDs: [String]) async throws -> CleanupCommitResult {
      .dumpster(
        updatedCount: trackIDs.count,
        destinationURL: URL(string: "music://playlist/wavepoint-demo")!
      )
    }
  }

  @MainActor
  private final class SimulatorAppleMusicPlayerClient: AppleMusicPlayerClient {
    func play(songID: String) async throws {}
    func pause() {}
    func resume() async throws {}
  }
#endif
