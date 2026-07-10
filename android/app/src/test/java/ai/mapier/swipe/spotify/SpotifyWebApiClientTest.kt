package ai.mapier.swipe.spotify

import ai.mapier.swipe.cleanup.LibraryTrack
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SpotifyWebApiClientTest {
  @Test
  fun accountProductsMapWithoutTreatingUnknownAsFree() = runTest {
    val transport = RecordingTransport(
      response(200, """{"product":"premium"}"""),
      response(200, """{"product":"free"}"""),
      response(200, """{"product":"open"}"""),
      response(200, "{}"),
      response(200, """{"product":"student"}"""),
    )
    val client = SpotifyWebApiClient(transport) { "token" }

    assertEquals(SpotifyAccountEligibility.PREMIUM, client.fetchAccountEligibility())
    assertEquals(SpotifyAccountEligibility.FREE, client.fetchAccountEligibility())
    assertEquals(SpotifyAccountEligibility.FREE, client.fetchAccountEligibility())
    assertEquals(SpotifyAccountEligibility.UNVERIFIABLE, client.fetchAccountEligibility())
    assertEquals(SpotifyAccountEligibility.UNVERIFIABLE, client.fetchAccountEligibility())
    assertEquals(List(5) { "/v1/me" }, transport.requests.map { it.path })
  }

  @Test
  fun forbiddenEligibilityIsDistinguishedFromOtherHttpFailures() = runTest {
    val client = SpotifyWebApiClient(RecordingTransport(response(403, "{}"))) { "token" }

    val error = runCatching { client.fetchAccountEligibility() }.exceptionOrNull()

    assertEquals(SpotifyWebApiErrorKind.ACCOUNT_ELIGIBILITY_FORBIDDEN, error.kind)
  }

  @Test
  fun savedTracksFollowEveryNextPageAndMapStableUris() = runTest {
    val transport = RecordingTransport(
      response(200, savedPage("one", "https://api.spotify.com/v1/me/tracks?offset=1&limit=50")),
      response(200, savedPage("two", null)),
    )
    val client = SpotifyWebApiClient(transport) { "access" }

    val tracks = client.fetchSavedTracks()

    assertEquals(listOf("one", "two"), tracks.map(LibraryTrack::id))
    assertEquals("spotify:track:one", tracks.first().playbackId)
    assertEquals("spotify:track:one", tracks.first().commitId)
    assertEquals("Bearer access", transport.requests.first().headers["Authorization"])
    assertTrue(transport.requests.last().url.contains("offset=1"))
  }

  @Test
  fun recentlyPlayedReturnsTrackIds() = runTest {
    val body = """{"items":[{"track":${trackJson("one")}},{"track":${trackJson("two")}}]}"""
    val client = SpotifyWebApiClient(RecordingTransport(response(200, body))) { "token" }

    assertEquals(setOf("one", "two"), client.fetchRecentlyPlayedTrackIds())
  }

  @Test
  fun unauthorizedResponseForcesOneTokenRefreshAndRetry() = runTest {
    val transport = RecordingTransport(
      response(401, "{}"),
      response(200, savedPage("retried", null)),
    )
    val refreshCalls = mutableListOf<Boolean>()
    val client = SpotifyWebApiClient(transport) { forceRefresh ->
      refreshCalls += forceRefresh
      if (forceRefresh) "fresh" else "expired"
    }

    val tracks = client.fetchSavedTracks()

    assertEquals(listOf("retried"), tracks.map { it.id })
    assertEquals(listOf(false, true), refreshCalls)
    assertEquals(
      listOf("Bearer expired", "Bearer fresh"),
      transport.requests.map { it.headers["Authorization"] },
    )
  }

  @Test
  fun rateLimitWaitsAndRetriesTheSameRequestOnce() = runTest {
    val transport = RecordingTransport(
      response(429, "{}", mapOf("Retry-After" to "2")),
      response(200, savedPage("after-wait", null)),
    )
    val delays = mutableListOf<Long>()
    val client = SpotifyWebApiClient(
      transport = transport,
      accessToken = { "token" },
      sleepMilliseconds = { delays += it },
    )

    client.fetchSavedTracks()

    assertEquals(listOf(2_000L), delays)
    assertEquals(transport.requests[0], transport.requests[1])
  }

  @Test
  fun removalUsesFortyUriChunksWithoutABody() = runTest {
    val transport = RecordingTransport(response(200, ""), response(200, ""))
    val client = SpotifyWebApiClient(transport) { "token" }
    val uris = (0..40).map { "spotify:track:$it" }

    val count = client.removeFromLibrary(uris)

    assertEquals(41, count)
    assertEquals(listOf("DELETE", "DELETE"), transport.requests.map { it.method })
    assertEquals(listOf(40, 1), transport.requests.map { it.queryValues("uris").size })
    assertTrue(transport.requests.all { it.body == null })
  }

  @Test
  fun failedLaterRemovalChunkReportsCommittedAndRemainingCounts() = runTest {
    val transport = RecordingTransport(response(200, ""), response(400, "{}"))
    val client = SpotifyWebApiClient(transport) { "token" }

    val error = runCatching {
      client.removeFromLibrary((0..40).map { "spotify:track:$it" })
    }.exceptionOrNull()

    assertEquals(SpotifyWebApiErrorKind.PARTIAL_REMOVAL, error.kind)
    assertEquals(40, error.committedCount)
    assertEquals(1, error.remainingCount)
  }

  private fun savedPage(id: String, next: String?): String =
    """{"items":[{"added_at":"2020-01-01T00:00:00Z","track":${trackJson(id)}}],"next":${next?.let { "\"$it\"" } ?: "null"}}"""

  private fun trackJson(id: String) =
    """{"id":"$id","uri":"spotify:track:$id","name":"Song $id","artists":[{"name":"Artist"}],"album":{"images":[{"url":"https://img.example/$id.jpg"}]},"preview_url":null,"external_urls":{"spotify":"https://open.spotify.com/track/$id"},"duration_ms":180000}"""
}

private class RecordingTransport(vararg responses: SpotifyHttpResponse) : SpotifyHttpTransport {
  val requests = mutableListOf<SpotifyHttpRequest>()
  private val responses = responses.toMutableList()

  override suspend fun send(request: SpotifyHttpRequest): SpotifyHttpResponse {
    requests += request
    return responses.removeFirst()
  }
}

private fun response(
  status: Int,
  body: String,
  headers: Map<String, String> = emptyMap(),
) = SpotifyHttpResponse(status, headers, body.encodeToByteArray())

private val Throwable?.kind: SpotifyWebApiErrorKind?
  get() = (this as? SpotifyWebApiException)?.kind

private val Throwable?.committedCount: Int?
  get() = (this as? SpotifyWebApiException)?.committedCount

private val Throwable?.remainingCount: Int?
  get() = (this as? SpotifyWebApiException)?.remainingCount
