import Foundation
import XCTest
@testable import Wavepoint

final class AccountDeletionServiceTests: XCTestCase {
  func testDeleteSendsSessionBearerAndPublishableKey() async throws {
    let transport = RecordingAccountDeletionTransport(
      response: accountResponse(status: 204)
    )
    let service = SupabaseAccountDeletionService(
      functionURL: URL(string: "https://project.supabase.co/functions/v1/delete-account")!,
      publishableKey: "publishable-key",
      transport: transport,
      accessToken: { "supabase-session" }
    )

    try await service.deleteAccount()

    let recordedRequest = await transport.request
    let request = try XCTUnwrap(recordedRequest)
    XCTAssertEqual(request.httpMethod, "DELETE")
    XCTAssertEqual(
      request.value(forHTTPHeaderField: "Authorization"),
      "Bearer supabase-session"
    )
    XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "publishable-key")
    XCTAssertNil(request.httpBody)
  }

  func testUnauthorizedResponseRequiresReconnect() async {
    let service = SupabaseAccountDeletionService(
      functionURL: URL(string: "https://project.supabase.co/functions/v1/delete-account")!,
      publishableKey: "publishable-key",
      transport: RecordingAccountDeletionTransport(response: accountResponse(status: 401)),
      accessToken: { "expired-session" }
    )

    do {
      try await service.deleteAccount()
      XCTFail("Expected unauthorized error")
    } catch {
      XCTAssertEqual(error as? AccountDeletionError, .authorizationExpired)
    }
  }

  func testServerFailureDoesNotReportDeletion() async {
    let service = SupabaseAccountDeletionService(
      functionURL: URL(string: "https://project.supabase.co/functions/v1/delete-account")!,
      publishableKey: "publishable-key",
      transport: RecordingAccountDeletionTransport(response: accountResponse(status: 503)),
      accessToken: { "session" }
    )

    do {
      try await service.deleteAccount()
      XCTFail("Expected server error")
    } catch {
      XCTAssertEqual(error as? AccountDeletionError, .httpStatus(503))
    }
  }
}

private actor RecordingAccountDeletionTransport: AccountDeletionHTTPTransport {
  private(set) var request: URLRequest?
  private let response: HTTPURLResponse

  init(response: HTTPURLResponse) {
    self.response = response
  }

  func send(_ request: URLRequest) async throws -> HTTPURLResponse {
    self.request = request
    return response
  }
}

private func accountResponse(status: Int) -> HTTPURLResponse {
  HTTPURLResponse(
    url: URL(string: "https://project.supabase.co/functions/v1/delete-account")!,
    statusCode: status,
    httpVersion: nil,
    headerFields: nil
  )!
}
