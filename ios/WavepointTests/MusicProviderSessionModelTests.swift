import XCTest

@testable import Wavepoint

@MainActor
final class MusicProviderSessionModelTests: XCTestCase {
  func testRestoreWithoutSelectionShowsProviderPicker() async {
    let model = MusicProviderSessionModel(
      appleMusicAuthorizer: FakeAppleMusicAuthorizer(result: .eligible),
      selectionStore: InMemoryMusicProviderSelectionStore()
    )

    await model.restore()

    XCTAssertEqual(model.state, .providerPicker)
  }

  func testSelectingSpotifyPersistsProviderWithoutAppleAuthorization() {
    let store = InMemoryMusicProviderSelectionStore()
    let model = MusicProviderSessionModel(
      appleMusicAuthorizer: FakeAppleMusicAuthorizer(result: .eligible),
      selectionStore: store
    )

    model.selectSpotify()

    XCTAssertEqual(model.state, .spotifySelected)
    XCTAssertEqual(store.selectedProvider, .spotify)
  }

  func testConnectingAppleMusicPersistsProviderAndMapsEligibility() async {
    for (eligibility, expectedState) in [
      (AppleMusicEligibility.eligible, MusicProviderSessionState.appleMusicReady),
      (.permissionDenied, .appleMusicPermissionDenied),
      (.restricted, .appleMusicRestricted),
      (.subscriptionRequired, .appleMusicSubscriptionRequired),
      (.syncLibraryRequired, .appleMusicSyncLibraryRequired),
    ] {
      let store = InMemoryMusicProviderSelectionStore()
      let model = MusicProviderSessionModel(
        appleMusicAuthorizer: FakeAppleMusicAuthorizer(result: eligibility),
        selectionStore: store
      )

      await model.connectAppleMusic()

      XCTAssertEqual(model.state, expectedState)
      XCTAssertEqual(store.selectedProvider, .appleMusic)
    }
  }

  func testRestoringAppleSelectionChecksWithoutPrompting() async {
    let authorizer = FakeAppleMusicAuthorizer(result: .eligible)
    let model = MusicProviderSessionModel(
      appleMusicAuthorizer: authorizer,
      selectionStore: InMemoryMusicProviderSelectionStore(selectedProvider: .appleMusic)
    )

    await model.restore()

    XCTAssertEqual(model.state, .appleMusicReady)
    let requestCount = await authorizer.requestCount
    let currentCount = await authorizer.currentCount
    XCTAssertEqual(requestCount, 0)
    XCTAssertEqual(currentCount, 1)
  }

  func testClearingSelectionReturnsToProviderPicker() {
    let store = InMemoryMusicProviderSelectionStore(selectedProvider: .spotify)
    let model = MusicProviderSessionModel(
      appleMusicAuthorizer: FakeAppleMusicAuthorizer(result: .eligible),
      selectionStore: store,
      initialState: .spotifySelected
    )

    model.clearSelection()

    XCTAssertEqual(model.state, .providerPicker)
    XCTAssertNil(store.selectedProvider)
  }
}

private actor FakeAppleMusicAuthorizer: AppleMusicAuthorizing {
  private(set) var currentCount = 0
  private(set) var requestCount = 0
  private let result: AppleMusicEligibility

  init(result: AppleMusicEligibility) {
    self.result = result
  }

  func currentEligibility() async throws -> AppleMusicEligibility {
    currentCount += 1
    return result
  }

  func requestEligibility() async throws -> AppleMusicEligibility {
    requestCount += 1
    return result
  }
}

private final class InMemoryMusicProviderSelectionStore:
  MusicProviderSelectionStoring, @unchecked Sendable
{
  var selectedProvider: MusicProvider?

  init(selectedProvider: MusicProvider? = nil) {
    self.selectedProvider = selectedProvider
  }
}
