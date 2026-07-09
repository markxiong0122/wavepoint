import Foundation
import XCTest
@testable import Wavepoint

final class SpotifyWebAPIClientTests: XCTestCase {
  func testFetchSavedTracksFollowsPaginationAndAuthorizesRequests() async throws {
    let transport = RecordingSpotifyTransport(responses: [
      response(
        status: 200,
        body: savedTracksPage(
          id: "one",
          next: "https://api.spotify.com/v1/me/tracks?offset=1&limit=50"
        )
      ),
      response(status: 200, body: savedTracksPage(id: "two", next: nil)),
    ])
    let client = SpotifyWebAPIClient(transport: transport) { "spotify-access" }

    let tracks = try await client.fetchSavedTracks()
    let requests = await transport.requests

    XCTAssertEqual(tracks.map(\.id), ["one", "two"])
    XCTAssertEqual(requests.count, 2)
    XCTAssertEqual(requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer spotify-access")
    XCTAssertEqual(requests[1].url?.absoluteString, "https://api.spotify.com/v1/me/tracks?offset=1&limit=50")
  }

  func testFetchRecentlyPlayedReturnsTrackIDs() async throws {
    let transport = RecordingSpotifyTransport(responses: [
      response(
        status: 200,
        body: """
        {"items":[
          {"track":\(trackJSON(id: "recent-1")),"played_at":"2026-07-09T12:00:00Z"},
          {"track":\(trackJSON(id: "recent-2")),"played_at":"2026-07-09T11:00:00Z"}
        ],"next":null}
        """
      )
    ])
    let client = SpotifyWebAPIClient(transport: transport) { "token" }

    let ids = try await client.fetchRecentlyPlayedTrackIDs()

    XCTAssertEqual(ids, ["recent-1", "recent-2"])
  }

  func testUnauthorizedResponseMapsToAuthorizationExpired() async {
    let transport = RecordingSpotifyTransport(responses: [response(status: 401, body: "{}")])
    let client = SpotifyWebAPIClient(transport: transport) { "expired" }

    do {
      _ = try await client.fetchSavedTracks()
      XCTFail("Expected authorizationExpired")
    } catch {
      XCTAssertEqual(error as? SpotifyWebAPIError, .authorizationExpired)
    }
  }

  func testRemovalChunksFortyOneURIsIntoFortyAndOne() async throws {
    let transport = RecordingSpotifyTransport(responses: [
      response(status: 200, body: "{}"),
      response(status: 200, body: "{}"),
    ])
    let client = SpotifyWebAPIClient(transport: transport) { "token" }
    let uris = (0..<41).map { "spotify:track:\($0)" }

    let removedCount = try await client.removeFromLibrary(uris: uris)
    let requests = await transport.requests
    let bodies = try requests.map { request -> [String] in
      let object = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody))
      return try XCTUnwrap((object as? [String: [String]])?["uris"])
    }

    XCTAssertEqual(removedCount, 41)
    XCTAssertEqual(requests.map(\.httpMethod), ["DELETE", "DELETE"])
    XCTAssertEqual(requests.map(\.url?.path), ["/v1/me/library", "/v1/me/library"])
    XCTAssertEqual(bodies.map(\.count), [40, 1])
  }

  func testRemovingNothingPerformsNoRequest() async throws {
    let transport = RecordingSpotifyTransport(responses: [])
    let client = SpotifyWebAPIClient(transport: transport) { "token" }

    let removedCount = try await client.removeFromLibrary(uris: [])

    XCTAssertEqual(removedCount, 0)
    let requests = await transport.requests
    XCTAssertTrue(requests.isEmpty)
  }

  private func savedTracksPage(id: String, next: String?) -> String {
    let nextValue = next.map { "\"\($0)\"" } ?? "null"
    return """
    {"items":[{"added_at":"2020-01-01T00:00:00Z","track":\(trackJSON(id: id))}],"next":\(nextValue)}
    """
  }

  private func trackJSON(id: String) -> String {
    """
    {"id":"\(id)","uri":"spotify:track:\(id)","name":"Song \(id)","artists":[{"name":"Artist"}],"album":{"images":[{"url":"https://img.example/\(id).jpg","height":640,"width":640}]},"preview_url":null,"external_urls":{"spotify":"https://open.spotify.com/track/\(id)"},"duration_ms":180000}
    """
  }

  private func response(status: Int, body: String) -> SpotifyHTTPResponse {
    SpotifyHTTPResponse(
      data: Data(body.utf8),
      response: HTTPURLResponse(
        url: URL(string: "https://api.spotify.com")!,
        statusCode: status,
        httpVersion: nil,
        headerFields: nil
      )!
    )
  }
}

private actor RecordingSpotifyTransport: SpotifyHTTPTransport {
  private(set) var requests: [URLRequest] = []
  private var responses: [SpotifyHTTPResponse]

  init(responses: [SpotifyHTTPResponse]) {
    self.responses = responses
  }

  func send(_ request: URLRequest) async throws -> SpotifyHTTPResponse {
    requests.append(request)
    guard !responses.isEmpty else {
      throw SpotifyWebAPIError.invalidResponse
    }
    return responses.removeFirst()
  }
}
