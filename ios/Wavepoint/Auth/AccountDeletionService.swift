import Foundation
import Supabase

protocol AccountDeleting: Sendable {
  func deleteAccount() async throws
}

protocol AccountDeletionHTTPTransport: Sendable {
  func send(_ request: URLRequest) async throws -> HTTPURLResponse
}

struct URLSessionAccountDeletionTransport: AccountDeletionHTTPTransport {
  let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func send(_ request: URLRequest) async throws -> HTTPURLResponse {
    let (_, response) = try await session.data(for: request)
    guard let response = response as? HTTPURLResponse else {
      throw AccountDeletionError.invalidResponse
    }
    return response
  }
}

struct SupabaseAccountDeletionService: AccountDeleting {
  private let functionURL: URL
  private let publishableKey: String
  private let transport: any AccountDeletionHTTPTransport
  private let accessToken: @Sendable () async throws -> String

  init(
    functionURL: URL,
    publishableKey: String,
    transport: any AccountDeletionHTTPTransport = URLSessionAccountDeletionTransport(),
    accessToken: @escaping @Sendable () async throws -> String
  ) {
    self.functionURL = functionURL
    self.publishableKey = publishableKey
    self.transport = transport
    self.accessToken = accessToken
  }

  init(
    client: SupabaseClient,
    configuration: AppConfiguration,
    transport: any AccountDeletionHTTPTransport = URLSessionAccountDeletionTransport()
  ) {
    self.init(
      functionURL: configuration.supabaseURL
        .appending(path: "functions/v1/delete-account"),
      publishableKey: configuration.supabasePublishableKey,
      transport: transport,
      accessToken: { try await client.auth.session.accessToken }
    )
  }

  func deleteAccount() async throws {
    var request = URLRequest(url: functionURL)
    request.httpMethod = "DELETE"
    request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
    request.setValue(publishableKey, forHTTPHeaderField: "apikey")

    let response = try await transport.send(request)
    switch response.statusCode {
    case 204:
      return
    case 401:
      throw AccountDeletionError.authorizationExpired
    default:
      throw AccountDeletionError.httpStatus(response.statusCode)
    }
  }
}

enum AccountDeletionError: LocalizedError, Equatable {
  case authorizationExpired
  case invalidResponse
  case httpStatus(Int)

  var errorDescription: String? {
    switch self {
    case .authorizationExpired:
      "Reconnect Spotify, then try deleting your account again."
    case .invalidResponse:
      "Wavepoint could not confirm account deletion. Your account was not deleted."
    case .httpStatus:
      "Please try again. Your account was not deleted."
    }
  }
}
