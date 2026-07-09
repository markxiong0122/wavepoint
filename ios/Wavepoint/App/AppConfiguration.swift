import Foundation

struct AppConfiguration: Equatable {
  let supabaseURL: URL
  let supabasePublishableKey: String
  let callbackURL: URL
  let spotifyClientID: String
  let spotifyAppRemoteCallbackURL: URL

  static func load(from bundle: Bundle = .main) throws -> AppConfiguration {
    let configuration = AppConfiguration(
      supabaseURL: try bundle.requiredURL(forInfoDictionaryKey: "SUPABASE_URL"),
      supabasePublishableKey: try bundle.requiredString(
        forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY"
      ),
      callbackURL: try bundle.requiredURL(forInfoDictionaryKey: "OAUTH_CALLBACK_URL"),
      spotifyClientID: try bundle.requiredString(
        forInfoDictionaryKey: "SPOTIFY_CLIENT_ID"
      ),
      spotifyAppRemoteCallbackURL: try bundle.requiredURL(
        forInfoDictionaryKey: "SPOTIFY_APP_REMOTE_CALLBACK_URL"
      )
    )
    guard !configuration.supabasePublishableKey.contains("REPLACE_ME") else {
      throw AppConfigurationError.placeholderValue("SUPABASE_PUBLISHABLE_KEY")
    }
    guard !configuration.spotifyClientID.contains("REPLACE_ME") else {
      throw AppConfigurationError.placeholderValue("SPOTIFY_CLIENT_ID")
    }
    return configuration
  }
}

extension Bundle {
  fileprivate func requiredString(forInfoDictionaryKey key: String) throws -> String {
    guard
      let value = object(forInfoDictionaryKey: key) as? String,
      !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      throw AppConfigurationError.missingValue(key)
    }
    return value
  }

  fileprivate func requiredURL(forInfoDictionaryKey key: String) throws -> URL {
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
  case placeholderValue(String)

  var errorDescription: String? {
    switch self {
    case .missingValue(let key):
      "Missing app configuration value: \(key)."
    case .invalidURL(let key):
      "Invalid URL in app configuration: \(key)."
    case .placeholderValue(let key):
      "Add the public \(key) value in Config/Shared.xcconfig."
    }
  }
}
