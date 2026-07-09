import Foundation

struct SpotifyProviderTokens: Codable, Equatable, Sendable {
  let accessToken: String
  let refreshToken: String?
}
