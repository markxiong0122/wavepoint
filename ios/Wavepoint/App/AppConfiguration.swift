import Foundation

struct AppConfiguration: Equatable {
  let supabaseURL: URL
  let supabasePublishableKey: String
  let spotifyClientID: String
  let callbackURL: URL

  static func load(from bundle: Bundle = .main) throws -> AppConfiguration {
    AppConfiguration(
      supabaseURL: try bundle.requiredURL(forInfoDictionaryKey: "SUPABASE_URL"),
      supabasePublishableKey: try bundle.requiredString(
        forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY"
      ),
      spotifyClientID: try bundle.requiredString(
        forInfoDictionaryKey: "SPOTIFY_CLIENT_ID"
      ),
      callbackURL: try bundle.requiredURL(forInfoDictionaryKey: "OAUTH_CALLBACK_URL")
    )
  }
}

private extension Bundle {
  func requiredString(forInfoDictionaryKey key: String) throws -> String {
    guard
      let value = object(forInfoDictionaryKey: key) as? String,
      !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      throw AppConfigurationError.missingValue(key)
    }
    return value
  }

  func requiredURL(forInfoDictionaryKey key: String) throws -> URL {
    let value = try requiredString(forInfoDictionaryKey: key)
    guard let url = URL(string: value), url.scheme != nil else {
      throw AppConfigurationError.invalidURL(key)
    }
    return url
  }
}

enum AppConfigurationError: LocalizedError, Equatable {
  case missingValue(String)
  case invalidURL(String)

  var errorDescription: String? {
    switch self {
    case let .missingValue(key):
      "Missing app configuration value: \(key)."
    case let .invalidURL(key):
      "Invalid URL in app configuration: \(key)."
    }
  }
}
