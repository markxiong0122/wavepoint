import XCTest

@testable import Wavepoint

final class MusicProviderPickerTests: XCTestCase {
  func testPickerOptionsExposeEqualProviderActionsAndTruthfulRequirements() {
    XCTAssertEqual(MusicProviderPickerOption.spotify.title, "CONTINUE WITH SPOTIFY")
    XCTAssertEqual(
      MusicProviderPickerOption.spotify.accessibilityIdentifier,
      "continue-with-spotify"
    )
    XCTAssertTrue(MusicProviderPickerOption.spotify.disclosure.contains("Premium"))

    XCTAssertEqual(
      MusicProviderPickerOption.appleMusic.title,
      "CONTINUE WITH APPLE MUSIC"
    )
    XCTAssertEqual(
      MusicProviderPickerOption.appleMusic.accessibilityIdentifier,
      "continue-with-apple-music"
    )
    XCTAssertTrue(MusicProviderPickerOption.appleMusic.disclosure.contains("Sync Library"))
    XCTAssertTrue(MusicProviderPickerOption.appleMusic.disclosure.contains("Dumpster"))
  }

  func testOnlySpotifyHasAWavepointServerAccountToDelete() {
    XCTAssertTrue(AccountProviderPresentation(provider: .spotify).showsAccountDeletion)
    XCTAssertFalse(AccountProviderPresentation(provider: .appleMusic).showsAccountDeletion)
  }
}
