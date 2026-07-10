import Foundation

struct SpotifyHTTPResponse: @unchecked Sendable {
  let data: Data
  let response: HTTPURLResponse
}

protocol SpotifyHTTPTransport: Sendable {
  func send(_ request: URLRequest) async throws -> SpotifyHTTPResponse
}

struct URLSessionSpotifyTransport: SpotifyHTTPTransport {
  let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func send(_ request: URLRequest) async throws -> SpotifyHTTPResponse {
    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw SpotifyWebAPIError.invalidResponse
    }
    return SpotifyHTTPResponse(data: data, response: httpResponse)
  }
}

protocol SpotifyLibraryServing: Sendable {
  func fetchSavedTracks() async throws -> [SpotifyTrack]
  func fetchRecentlyPlayedTrackIDs() async throws -> Set<String>
  func removeFromLibrary(uris: [String]) async throws -> Int
}

struct SpotifyWebAPIClient: SpotifyLibraryServing {
  private let transport: any SpotifyHTTPTransport
  private let accessToken: @Sendable (Bool) async throws -> String
  private let baseURL = URL(string: "https://api.spotify.com/v1")!

  init(
    transport: any SpotifyHTTPTransport = URLSessionSpotifyTransport(),
    accessToken: @escaping @Sendable (Bool) async throws -> String
  ) {
    self.transport = transport
    self.accessToken = accessToken
  }

  func fetchSavedTracks() async throws -> [SpotifyTrack] {
    var nextURL: URL? =
      baseURL
      .appending(path: "me/tracks")
      .appending(queryItems: [URLQueryItem(name: "limit", value: "50")])
    var tracks: [SpotifyTrack] = []

    while let url = nextURL {
      let response = try await sendAuthorizedRequest(to: url)
      let page = try decode(SavedTracksPage.self, from: response.data)
      tracks.append(contentsOf: page.items.compactMap(\.spotifyTrack))
      nextURL = page.next
    }

    return tracks
  }

  func fetchRecentlyPlayedTrackIDs() async throws -> Set<String> {
    let url =
      baseURL
      .appending(path: "me/player/recently-played")
      .appending(queryItems: [URLQueryItem(name: "limit", value: "50")])
    let response = try await sendAuthorizedRequest(to: url)
    let page = try decode(RecentlyPlayedPage.self, from: response.data)
    return Set(page.items.compactMap(\.track.id))
  }

  func removeFromLibrary(uris: [String]) async throws -> Int {
    guard !uris.isEmpty else { return 0 }

    var removedCount = 0
    for startIndex in stride(from: 0, to: uris.count, by: 40) {
      let endIndex = min(startIndex + 40, uris.count)
      let chunk = Array(uris[startIndex..<endIndex])
      let url =
        baseURL
        .appending(path: "me/library")
        .appending(queryItems: [
          URLQueryItem(name: "uris", value: chunk.joined(separator: ","))
        ])

      do {
        _ = try await sendAuthorizedRequest(
          to: url,
          method: "DELETE"
        )
        removedCount += chunk.count
      } catch {
        guard removedCount > 0 else { throw error }
        throw SpotifyWebAPIError.partialRemoval(
          committedCount: removedCount,
          remainingCount: uris.count - removedCount
        )
      }
    }

    return removedCount
  }

  private func sendAuthorizedRequest(
    to url: URL,
    method: String = "GET",
    body: Data? = nil,
    contentType: String? = nil
  ) async throws -> SpotifyHTTPResponse {
    do {
      return try await sendValidated(
        authorizedRequest(
          to: url,
          method: method,
          body: body,
          contentType: contentType,
          forceRefresh: false
        )
      )
    } catch SpotifyWebAPIError.authorizationExpired {
      return try await sendValidated(
        authorizedRequest(
          to: url,
          method: method,
          body: body,
          contentType: contentType,
          forceRefresh: true
        )
      )
    }
  }

  private func authorizedRequest(
    to url: URL,
    method: String,
    body: Data?,
    contentType: String?,
    forceRefresh: Bool
  ) async throws -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.httpBody = body
    request.setValue(
      "Bearer \(try await accessToken(forceRefresh))",
      forHTTPHeaderField: "Authorization"
    )
    if let contentType {
      request.setValue(contentType, forHTTPHeaderField: "Content-Type")
    }
    return request
  }

  private func sendValidated(_ request: URLRequest) async throws -> SpotifyHTTPResponse {
    var response = try await transport.send(request)
    if response.response.statusCode == 429,
      let value = response.response.value(forHTTPHeaderField: "Retry-After"),
      let delay = Double(value)
    {
      try await Task.sleep(for: .seconds(delay))
      response = try await transport.send(request)
    }

    switch response.response.statusCode {
    case 200..<300:
      return response
    case 401:
      throw SpotifyWebAPIError.authorizationExpired
    case 429:
      throw SpotifyWebAPIError.rateLimited
    default:
      throw SpotifyWebAPIError.httpStatus(response.response.statusCode)
    }
  }

  private func decode<Value: Decodable>(
    _ type: Value.Type,
    from data: Data
  ) throws -> Value {
    do {
      return try JSONDecoder().decode(type, from: data)
    } catch {
      throw SpotifyWebAPIError.invalidData
    }
  }
}

enum SpotifyWebAPIError: LocalizedError, Equatable {
  case authorizationExpired
  case invalidResponse
  case invalidData
  case rateLimited
  case httpStatus(Int)
  case partialRemoval(committedCount: Int, remainingCount: Int)

  var errorDescription: String? {
    switch self {
    case .authorizationExpired:
      "Your Spotify connection expired. Please reconnect."
    case .invalidResponse, .invalidData:
      "Spotify returned an unreadable response. Please try again."
    case .rateLimited:
      "Spotify is receiving too many requests. Please wait and retry."
    case .httpStatus(let status):
      "Spotify could not complete the request (\(status))."
    case .partialRemoval(let committedCount, let remainingCount):
      "Removed \(committedCount) songs, but \(remainingCount) still need to be retried."
    }
  }
}

private struct SavedTracksPage: Decodable {
  let items: [SavedTrackItem]
  let next: URL?
}

private struct SavedTrackItem: Decodable {
  let addedAt: String
  let track: TrackPayload

  enum CodingKeys: String, CodingKey {
    case addedAt = "added_at"
    case track
  }

  var spotifyTrack: SpotifyTrack? {
    guard
      let id = track.id,
      let spotifyURL = track.externalURLs.spotify,
      let addedDate = SpotifyDateParser.date(from: addedAt)
    else { return nil }

    return SpotifyTrack(
      id: id,
      uri: track.uri,
      name: track.name,
      artistNames: track.artists.map(\.name),
      artworkURL: track.album.images.first?.url,
      previewURL: track.previewURL,
      spotifyURL: spotifyURL,
      durationMilliseconds: track.durationMilliseconds,
      addedAt: addedDate
    )
  }
}

private struct RecentlyPlayedPage: Decodable {
  let items: [RecentlyPlayedItem]
}

private struct RecentlyPlayedItem: Decodable {
  let track: TrackPayload
}

private struct TrackPayload: Decodable {
  let id: String?
  let uri: String
  let name: String
  let artists: [ArtistPayload]
  let album: AlbumPayload
  let previewURL: URL?
  let externalURLs: ExternalURLs
  let durationMilliseconds: Int

  enum CodingKeys: String, CodingKey {
    case id, uri, name, artists, album
    case previewURL = "preview_url"
    case externalURLs = "external_urls"
    case durationMilliseconds = "duration_ms"
  }
}

private struct ArtistPayload: Decodable {
  let name: String
}

private struct AlbumPayload: Decodable {
  let images: [ImagePayload]
}

private struct ImagePayload: Decodable {
  let url: URL
}

private struct ExternalURLs: Decodable {
  let spotify: URL?
}

private enum SpotifyDateParser {
  static func date(from value: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
  }
}
