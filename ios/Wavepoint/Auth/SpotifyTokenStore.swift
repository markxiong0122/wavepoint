import Foundation
import Security

protocol SpotifyTokenStoring: Sendable {
  func save(_ tokens: SpotifyProviderTokens) throws
  func load() throws -> SpotifyProviderTokens?
  func delete() throws
}

struct KeychainSpotifyTokenStore: SpotifyTokenStoring {
  let service: String
  let account: String

  init(
    service: String = "ai.mapier.swipe.spotify",
    account: String = "provider-tokens"
  ) {
    self.service = service
    self.account = account
  }

  func save(_ tokens: SpotifyProviderTokens) throws {
    let data = try JSONEncoder().encode(tokens)
    let status = SecItemUpdate(
      baseQuery as CFDictionary,
      [kSecValueData: data] as CFDictionary
    )

    if status == errSecItemNotFound {
      var item = baseQuery
      item[kSecValueData as String] = data
      item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
      try requireSuccess(SecItemAdd(item as CFDictionary, nil))
      return
    }

    try requireSuccess(status)
  }

  func load() throws -> SpotifyProviderTokens? {
    var query = baseQuery
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    query[kSecReturnData as String] = true

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound {
      return nil
    }

    try requireSuccess(status)
    guard let data = result as? Data else {
      throw SpotifyTokenStoreError.invalidStoredValue
    }
    return try JSONDecoder().decode(SpotifyProviderTokens.self, from: data)
  }

  func delete() throws {
    let status = SecItemDelete(baseQuery as CFDictionary)
    guard status != errSecItemNotFound else { return }
    try requireSuccess(status)
  }

  private var baseQuery: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }

  private func requireSuccess(_ status: OSStatus) throws {
    guard status == errSecSuccess else {
      throw SpotifyTokenStoreError.keychain(status)
    }
  }
}

enum SpotifyTokenStoreError: Error, Equatable {
  case invalidStoredValue
  case keychain(OSStatus)
}
