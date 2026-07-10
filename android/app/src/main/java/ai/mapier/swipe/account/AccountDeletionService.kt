package ai.mapier.swipe.account

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request

interface AccountDeleting {
  suspend fun deleteAccount()
}

data class AccountDeletionRequest(
  val method: String,
  val url: String,
  val headers: Map<String, String>,
)

data class AccountDeletionResponse(val statusCode: Int)

interface AccountDeletionTransport {
  suspend fun send(request: AccountDeletionRequest): AccountDeletionResponse
}

class OkHttpAccountDeletionTransport(
  private val client: OkHttpClient = OkHttpClient(),
) : AccountDeletionTransport {
  override suspend fun send(request: AccountDeletionRequest): AccountDeletionResponse =
    withContext(Dispatchers.IO) {
      val builder = Request.Builder().url(request.url)
      request.headers.forEach(builder::header)
      if (request.method == "DELETE") builder.delete()
      client.newCall(builder.build()).execute().use { response ->
        AccountDeletionResponse(response.code)
      }
    }
}

enum class AccountDeletionErrorKind {
  AUTHORIZATION_EXPIRED,
  HTTP_STATUS,
}

class AccountDeletionException(
  val kind: AccountDeletionErrorKind,
  val statusCode: Int? = null,
) : Exception(
  when (kind) {
    AccountDeletionErrorKind.AUTHORIZATION_EXPIRED ->
      "Reconnect Spotify, then try deleting your account again."
    AccountDeletionErrorKind.HTTP_STATUS ->
      "Please try again. Your Wavepoint account was not deleted."
  },
)

class SupabaseAccountDeletionService(
  private val functionUrl: String,
  private val publishableKey: String,
  private val transport: AccountDeletionTransport = OkHttpAccountDeletionTransport(),
  private val accessToken: suspend () -> String,
) : AccountDeleting {
  override suspend fun deleteAccount() {
    val response = transport.send(
      AccountDeletionRequest(
        method = "DELETE",
        url = functionUrl,
        headers = mapOf(
          "Authorization" to "Bearer ${accessToken()}",
          "apikey" to publishableKey,
        ),
      ),
    )
    when (response.statusCode) {
      204 -> Unit
      401 -> throw AccountDeletionException(AccountDeletionErrorKind.AUTHORIZATION_EXPIRED)
      else -> throw AccountDeletionException(
        AccountDeletionErrorKind.HTTP_STATUS,
        statusCode = response.statusCode,
      )
    }
  }
}
