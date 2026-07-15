import XCTest

@testable import Wavepoint

final class MusicProviderPickerTests: XCTestCase {
  func testPickerOptionsExposeEqualProviderActionsAndTruthfulRequirements() {
    XCTAssertEqual(MusicProviderPickerOption.spotify.title, "SPOTIFY · LIMITED BETA")
    XCTAssertEqual(
      MusicProviderPickerOption.spotify.accessibilityIdentifier,
      "continue-with-spotify"
    )
    XCTAssertTrue(MusicProviderPickerOption.spotify.disclosure.contains("Premium"))
    XCTAssertTrue(MusicProviderPickerOption.spotify.disclosure.contains("tester access"))

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

    XCTAssertEqual(MusicProviderPickerOption.demo.title, "TRY A DEMO CLEANUP")
    XCTAssertEqual(MusicProviderPickerOption.demo.accessibilityIdentifier, "try-demo-cleanup")
    XCTAssertTrue(MusicProviderPickerOption.demo.disclosure.contains("fictional"))
    XCTAssertTrue(MusicProviderPickerOption.demo.disclosure.contains("Nothing"))
  }

  func testOnlySpotifyHasAWavepointServerAccountToDelete() {
    XCTAssertTrue(AccountProviderPresentation(provider: .spotify).showsAccountDeletion)
    XCTAssertFalse(AccountProviderPresentation(provider: .appleMusic).showsAccountDeletion)
  }

  func testAccountProvidesPublicPrivacyAndSupportDestinations() {
    let presentation = AccountProviderPresentation(provider: .spotify)

    XCTAssertEqual(
      presentation.privacyURL.absoluteString,
      "https://markxiong0122.github.io/wavepoint/privacy.html"
    )
    XCTAssertEqual(
      presentation.supportURL.absoluteString,
      "https://markxiong0122.github.io/wavepoint/support.html"
    )
  }
}
