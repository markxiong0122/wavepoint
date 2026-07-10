package ai.mapier.swipe.auth

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.nio.ByteBuffer
import java.security.KeyStore
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

interface EncryptedTokenKeyValueStore {
  fun read(): String?
  fun write(value: String)
  fun clear()
}

interface TokenCipherBox {
  fun encrypt(plaintext: ByteArray): ByteArray
  fun decrypt(ciphertext: ByteArray): ByteArray
}

class SpotifyTokenStore(
  private val values: EncryptedTokenKeyValueStore,
  private val cipherBox: TokenCipherBox,
) : SpotifyTokenStoring {
  override fun save(tokens: SpotifyProviderTokens) {
    val encrypted = cipherBox.encrypt(encode(tokens))
    values.write(Base64.getEncoder().encodeToString(encrypted))
  }

  override fun load(): SpotifyProviderTokens? {
    val stored = values.read() ?: return null
    val encrypted = Base64.getDecoder().decode(stored)
    return decode(cipherBox.decrypt(encrypted))
  }

  override fun clear() {
    values.clear()
  }

  private fun encode(tokens: SpotifyProviderTokens): ByteArray {
    val access = tokens.accessToken.toByteArray(Charsets.UTF_8)
    val refresh = tokens.refreshToken?.toByteArray(Charsets.UTF_8)
    return ByteBuffer.allocate(8 + access.size + (refresh?.size ?: 0))
      .putInt(access.size)
      .put(access)
      .putInt(refresh?.size ?: -1)
      .apply { if (refresh != null) put(refresh) }
      .array()
  }

  private fun decode(data: ByteArray): SpotifyProviderTokens {
    val buffer = ByteBuffer.wrap(data)
    val accessLength = buffer.int
    require(accessLength in 1..buffer.remaining())
    val access = ByteArray(accessLength).also(buffer::get)
    val refreshLength = buffer.int
    require(refreshLength == -1 || refreshLength in 0..buffer.remaining())
    val refresh = if (refreshLength >= 0) {
      ByteArray(refreshLength).also(buffer::get).toString(Charsets.UTF_8)
    } else {
      null
    }
    require(!buffer.hasRemaining())
    return SpotifyProviderTokens(
      accessToken = access.toString(Charsets.UTF_8),
      refreshToken = refresh,
    )
  }
}

class SharedPreferencesTokenKeyValueStore(context: Context) : EncryptedTokenKeyValueStore {
  private val preferences = context.getSharedPreferences(FILE_NAME, Context.MODE_PRIVATE)

  override fun read(): String? = preferences.getString(TOKEN_KEY, null)

  override fun write(value: String) {
    check(preferences.edit().putString(TOKEN_KEY, value).commit())
  }

  override fun clear() {
    check(preferences.edit().remove(TOKEN_KEY).commit())
  }

  private companion object {
    const val FILE_NAME = "spotify_credentials"
    const val TOKEN_KEY = "encrypted_provider_tokens"
  }
}

class AndroidKeystoreTokenCipherBox : TokenCipherBox {
  override fun encrypt(plaintext: ByteArray): ByteArray {
    val cipher = Cipher.getInstance(TRANSFORMATION)
    cipher.init(Cipher.ENCRYPT_MODE, secretKey())
    val encrypted = cipher.doFinal(plaintext)
    val iv = cipher.iv
    require(iv.size <= UByte.MAX_VALUE.toInt())
    return ByteBuffer.allocate(2 + iv.size + encrypted.size)
      .put(FORMAT_VERSION)
      .put(iv.size.toByte())
      .put(iv)
      .put(encrypted)
      .array()
  }

  override fun decrypt(ciphertext: ByteArray): ByteArray {
    val buffer = ByteBuffer.wrap(ciphertext)
    require(buffer.get() == FORMAT_VERSION)
    val ivLength = buffer.get().toUByte().toInt()
    require(ivLength in 1 until buffer.remaining())
    val iv = ByteArray(ivLength).also(buffer::get)
    val encrypted = ByteArray(buffer.remaining()).also(buffer::get)
    val cipher = Cipher.getInstance(TRANSFORMATION)
    cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(128, iv))
    return cipher.doFinal(encrypted)
  }

  private fun secretKey(): SecretKey {
    val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
    (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }

    return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
      .apply {
        init(
          KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
          )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setRandomizedEncryptionRequired(true)
            .build(),
        )
      }
      .generateKey()
  }

  private companion object {
    const val ANDROID_KEYSTORE = "AndroidKeyStore"
    const val KEY_ALIAS = "wavepoint.spotify.provider.tokens.v1"
    const val TRANSFORMATION = "AES/GCM/NoPadding"
    const val FORMAT_VERSION: Byte = 1
  }
}
