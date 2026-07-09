import Foundation
import Supabase

struct RefreshedSpotifyToken: Equatable, Sendable, Decodable {
  let accessToken: String
  let refreshToken: String?
  let expiresIn: Int

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case refreshToken = "refresh_token"
    case expiresIn = "expires_in"
  }
}

protocol SpotifyTokenRefreshServing: Sendable {
  func refresh(providerRefreshToken: String) async throws -> RefreshedSpotifyToken
}

actor SpotifyCredentialProvider {
  private let tokenStore: any SpotifyTokenStoring
  private let refreshService: any SpotifyTokenRefreshServing

  init(
    tokenStore: any SpotifyTokenStoring,
    refreshService: any SpotifyTokenRefreshServing
  ) {
    self.tokenStore = tokenStore
    self.refreshService = refreshService
  }

  func accessToken(forceRefresh: Bool) async throws -> String {
    guard let storedTokens = try tokenStore.load() else {
      throw SpotifyWebAPIError.authorizationExpired
    }
    guard forceRefresh else { return storedTokens.accessToken }
    guard let refreshToken = storedTokens.refreshToken else {
      throw SpotifyWebAPIError.authorizationExpired
    }

    let refreshed = try await refreshService.refresh(
      providerRefreshToken: refreshToken
    )
    try tokenStore.save(
      SpotifyProviderTokens(
        accessToken: refreshed.accessToken,
        refreshToken: refreshed.refreshToken ?? refreshToken
      )
    )
    return refreshed.accessToken
  }
}

struct SupabaseSpotifyTokenRefreshService: SpotifyTokenRefreshServing {
  private let client: SupabaseClient
  private let functionURL: URL
  private let publishableKey: String
  private let session: URLSession

  init(
    client: SupabaseClient,
    configuration: AppConfiguration,
    session: URLSession = .shared
  ) {
    self.client = client
    functionURL = configuration.supabaseURL
      .appending(path: "functions/v1/spotify-token-refresh")
    publishableKey = configuration.supabasePublishableKey
    self.session = session
  }

  func refresh(providerRefreshToken: String) async throws -> RefreshedSpotifyToken {
    let supabaseSession = try await client.auth.session
    var request = URLRequest(url: functionURL)
    request.httpMethod = "POST"
    request.setValue(
      "Bearer \(supabaseSession.accessToken)",
      forHTTPHeaderField: "Authorization"
    )
    request.setValue(publishableKey, forHTTPHeaderField: "apikey")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(
      RefreshRequest(refreshToken: providerRefreshToken)
    )

    let (data, response) = try await session.data(for: request)
    guard let response = response as? HTTPURLResponse else {
      throw SpotifyWebAPIError.invalidResponse
    }
    guard response.statusCode == 200 else {
      if response.statusCode == 401 {
        throw SpotifyWebAPIError.authorizationExpired
      }
      throw SpotifyWebAPIError.httpStatus(response.statusCode)
    }

    do {
      return try JSONDecoder().decode(RefreshedSpotifyToken.self, from: data)
    } catch {
      throw SpotifyWebAPIError.invalidData
    }
  }
}

private struct RefreshRequest: Encodable {
  let refreshToken: String

  enum CodingKeys: String, CodingKey {
    case refreshToken = "refresh_token"
  }
}
