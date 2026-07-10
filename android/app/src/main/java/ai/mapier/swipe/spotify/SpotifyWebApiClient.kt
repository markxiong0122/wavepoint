package ai.mapier.swipe.spotify

import ai.mapier.swipe.cleanup.LibraryTrack
import java.net.URI
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request

data class SpotifyHttpRequest(
  val method: String,
  val url: String,
  val headers: Map<String, String>,
  val body: ByteArray? = null,
) {
  val path: String
    get() = URI(url).path

  fun queryValues(name: String): List<String> =
    url.toHttpUrl().queryParameter(name)
      ?.split(',')
      ?.filter(String::isNotEmpty)
      .orEmpty()
}

data class SpotifyHttpResponse(
  val statusCode: Int,
  val headers: Map<String, String>,
  val body: ByteArray,
)

interface SpotifyHttpTransport {
  suspend fun send(request: SpotifyHttpRequest): SpotifyHttpResponse
}

interface SpotifyLibraryService {
  suspend fun fetchSavedTracks(): List<LibraryTrack>
  suspend fun fetchRecentlyPlayedTrackIds(): Set<String>
  suspend fun removeFromLibrary(uris: List<String>): Int
}

class OkHttpSpotifyTransport(
  private val client: OkHttpClient = OkHttpClient(),
) : SpotifyHttpTransport {
  override suspend fun send(request: SpotifyHttpRequest): SpotifyHttpResponse =
    withContext(Dispatchers.IO) {
      val builder = Request.Builder().url(request.url)
      request.headers.forEach(builder::header)
      when (request.method) {
        "GET" -> builder.get()
        "DELETE" -> builder.delete()
        else -> builder.method(request.method, null)
      }
      client.newCall(builder.build()).execute().use { response ->
        SpotifyHttpResponse(
          statusCode = response.code,
          headers = response.headers.names().associateWith { response.header(it).orEmpty() },
          body = response.body.bytes(),
        )
      }
    }
}

class SpotifyWebApiClient(
  private val transport: SpotifyHttpTransport = OkHttpSpotifyTransport(),
  private val sleepMilliseconds: suspend (Long) -> Unit = { delay(it) },
  private val json: Json = Json { ignoreUnknownKeys = true },
  private val accessToken: suspend (forceRefresh: Boolean) -> String,
) : SpotifyAccountEligibilityChecker, SpotifyLibraryService {
  override suspend fun fetchAccountEligibility(): SpotifyAccountEligibility {
    return try {
      val product = decode<CurrentUserProfile>(authorized("$BASE_URL/me")).product
        ?: throw SpotifyWebApiException(SpotifyWebApiErrorKind.ACCOUNT_ELIGIBILITY_FORBIDDEN)
      when (product.lowercase()) {
        "premium" -> SpotifyAccountEligibility.PREMIUM
        "free", "open" -> SpotifyAccountEligibility.FREE
        else -> SpotifyAccountEligibility.UNVERIFIABLE
      }
    } catch (error: SpotifyWebApiException) {
      if (error.kind == SpotifyWebApiErrorKind.HTTP_STATUS && error.statusCode == 403) {
        throw SpotifyWebApiException(SpotifyWebApiErrorKind.ACCOUNT_ELIGIBILITY_FORBIDDEN)
      }
      throw error
    }
  }

  override suspend fun fetchSavedTracks(): List<LibraryTrack> {
    var nextUrl: String? = "$BASE_URL/me/tracks?limit=50"
    val tracks = mutableListOf<LibraryTrack>()
    while (nextUrl != null) {
      val page = decode<SavedTracksPage>(authorized(nextUrl))
      tracks += page.items.mapNotNull(SavedTrackItem::libraryTrack)
      nextUrl = page.next
    }
    return tracks
  }

  override suspend fun fetchRecentlyPlayedTrackIds(): Set<String> {
    val page = decode<RecentlyPlayedPage>(
      authorized("$BASE_URL/me/player/recently-played?limit=50"),
    )
    return page.items.mapNotNull { it.track.id }.toSet()
  }

  override suspend fun removeFromLibrary(uris: List<String>): Int {
    if (uris.isEmpty()) return 0
    var committed = 0
    for (chunk in uris.chunked(40)) {
      val url = "$BASE_URL/me/library".toHttpUrl().newBuilder()
        .addQueryParameter("uris", chunk.joinToString(","))
        .build()
        .toString()
      try {
        authorized(url, method = "DELETE")
        committed += chunk.size
      } catch (error: Throwable) {
        if (committed == 0) throw error
        throw SpotifyWebApiException(
          kind = SpotifyWebApiErrorKind.PARTIAL_REMOVAL,
          committedCount = committed,
          remainingCount = uris.size - committed,
          cause = error,
        )
      }
    }
    return committed
  }

  private suspend fun authorized(
    url: String,
    method: String = "GET",
  ): SpotifyHttpResponse {
    return try {
      validated(request(url, method, forceRefresh = false))
    } catch (error: SpotifyWebApiException) {
      if (error.kind != SpotifyWebApiErrorKind.AUTHORIZATION_EXPIRED) throw error
      validated(request(url, method, forceRefresh = true))
    }
  }

  private suspend fun request(
    url: String,
    method: String,
    forceRefresh: Boolean,
  ) = SpotifyHttpRequest(
    method = method,
    url = url,
    headers = mapOf("Authorization" to "Bearer ${accessToken(forceRefresh)}"),
  )

  private suspend fun validated(request: SpotifyHttpRequest): SpotifyHttpResponse {
    var response = transport.send(request)
    if (response.statusCode == 429) {
      val retryAfter = response.header("Retry-After")?.toDoubleOrNull()
      if (retryAfter != null) {
        sleepMilliseconds((retryAfter * 1_000).toLong())
        response = transport.send(request)
      }
    }
    return when (response.statusCode) {
      in 200..299 -> response
      401 -> throw SpotifyWebApiException(SpotifyWebApiErrorKind.AUTHORIZATION_EXPIRED)
      429 -> throw SpotifyWebApiException(SpotifyWebApiErrorKind.RATE_LIMITED)
      else -> throw SpotifyWebApiException(
        SpotifyWebApiErrorKind.HTTP_STATUS,
        statusCode = response.statusCode,
      )
    }
  }

  private inline fun <reified T> decode(response: SpotifyHttpResponse): T = try {
    json.decodeFromString(response.body.decodeToString())
  } catch (error: SerializationException) {
    throw SpotifyWebApiException(SpotifyWebApiErrorKind.INVALID_DATA, cause = error)
  } catch (error: IllegalArgumentException) {
    throw SpotifyWebApiException(SpotifyWebApiErrorKind.INVALID_DATA, cause = error)
  }

  private fun SpotifyHttpResponse.header(name: String): String? =
    headers.entries.firstOrNull { it.key.equals(name, ignoreCase = true) }?.value

  private companion object {
    const val BASE_URL = "https://api.spotify.com/v1"
  }
}
