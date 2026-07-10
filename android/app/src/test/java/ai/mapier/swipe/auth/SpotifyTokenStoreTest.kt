package ai.mapier.swipe.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

class SpotifyTokenStoreTest {
  @Test
  fun tokensAreEncryptedAtRestAndRoundTrip() {
    val values = MemoryKeyValueStore()
    val store = SpotifyTokenStore(values, PrefixCipherBox())
    val tokens = SpotifyProviderTokens("access-token", "refresh-token")

    store.save(tokens)

    assertFalse(values.value.orEmpty().contains("access-token"))
    assertFalse(values.value.orEmpty().contains("refresh-token"))
    assertEquals(tokens, store.load())
  }

  @Test
  fun clearRemovesTheEncryptedPayload() {
    val values = MemoryKeyValueStore()
    val store = SpotifyTokenStore(values, PrefixCipherBox())
    store.save(SpotifyProviderTokens("access", null))

    store.clear()

    assertNull(store.load())
    assertNull(values.value)
  }
}

private class MemoryKeyValueStore : EncryptedTokenKeyValueStore {
  var value: String? = null

  override fun read(): String? = value

  override fun write(value: String) {
    this.value = value
  }

  override fun clear() {
    value = null
  }
}

private class PrefixCipherBox : TokenCipherBox {
  override fun encrypt(plaintext: ByteArray): ByteArray =
    byteArrayOf(42) + plaintext.map { (it.toInt() xor 0x5A).toByte() }

  override fun decrypt(ciphertext: ByteArray): ByteArray =
    ciphertext.drop(1).map { (it.toInt() xor 0x5A).toByte() }.toByteArray()
}
