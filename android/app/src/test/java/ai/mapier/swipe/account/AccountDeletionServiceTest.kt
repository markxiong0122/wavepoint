package ai.mapier.swipe.account

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

class AccountDeletionServiceTest {
  @Test
  fun sendsAnAuthenticatedDeleteToTheAccountFunction() = runTest {
    val transport = RecordingDeletionTransport(AccountDeletionResponse(204))
    val service = SupabaseAccountDeletionService(
      functionUrl = "https://project.supabase.co/functions/v1/delete-account",
      publishableKey = "public-key",
      transport = transport,
      accessToken = { "user-token" },
    )

    service.deleteAccount()

    assertEquals("DELETE", transport.request?.method)
    assertEquals(
      "https://project.supabase.co/functions/v1/delete-account",
      transport.request?.url,
    )
    assertEquals("Bearer user-token", transport.request?.headers?.get("Authorization"))
    assertEquals("public-key", transport.request?.headers?.get("apikey"))
  }

  @Test
  fun authorizationFailureHasReconnectCopy() = runTest {
    val service = SupabaseAccountDeletionService(
      functionUrl = "https://project.supabase.co/functions/v1/delete-account",
      publishableKey = "public-key",
      transport = RecordingDeletionTransport(AccountDeletionResponse(401)),
      accessToken = { "expired" },
    )

    val error = runCatching { service.deleteAccount() }.exceptionOrNull()

    assertEquals(AccountDeletionErrorKind.AUTHORIZATION_EXPIRED, error.kind)
  }

  @Test
  fun serverFailureDoesNotPretendDeletionSucceeded() = runTest {
    val service = SupabaseAccountDeletionService(
      functionUrl = "https://project.supabase.co/functions/v1/delete-account",
      publishableKey = "public-key",
      transport = RecordingDeletionTransport(AccountDeletionResponse(503)),
      accessToken = { "valid" },
    )

    val error = runCatching { service.deleteAccount() }.exceptionOrNull()

    assertEquals(AccountDeletionErrorKind.HTTP_STATUS, error.kind)
    assertEquals(503, error.statusCode)
  }
}

private class RecordingDeletionTransport(
  private val response: AccountDeletionResponse,
) : AccountDeletionTransport {
  var request: AccountDeletionRequest? = null

  override suspend fun send(request: AccountDeletionRequest): AccountDeletionResponse {
    this.request = request
    return response
  }
}

private val Throwable?.kind: AccountDeletionErrorKind?
  get() = (this as? AccountDeletionException)?.kind

private val Throwable?.statusCode: Int?
  get() = (this as? AccountDeletionException)?.statusCode
