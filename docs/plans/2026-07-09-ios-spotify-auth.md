# iOS Spotify Authentication Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build an iOS 17 SwiftUI app shell that signs a user into Spotify through Supabase Auth, securely retains Spotify provider tokens, and renders explicit signed-out, authorizing, signed-in, and error states.

**Architecture:** The app owns one `@Observable` session model at its root. A small `SpotifyAuthenticating` adapter wraps Supabase Swift and `ASWebAuthenticationSession`; a separate `SpotifyTokenStoring` adapter wraps Keychain so state transitions can be tested without network or UI. Supabase handles the HTTPS Spotify callback and redirects to `ai.mapier.swipe://login-callback`; the app captures the returned provider tokens and stores them locally.

**Tech Stack:** Swift 6, SwiftUI, Observation, AuthenticationServices, Security/Keychain, Supabase Swift 2.46.0, XCTest, XcodeGen, iOS 17+

---

### Task 1: Native project scaffold

**Files:**
- Create: `ios/project.yml`
- Create: `ios/Config/Shared.xcconfig`
- Create: `ios/Wavepoint/App/WavepointApp.swift`
- Create: `ios/Wavepoint/App/AppConfiguration.swift`
- Create: `ios/Wavepoint/Features/AppRootView.swift`

**Step 1: Add the XcodeGen specification**

Define an iOS 17 application target with bundle ID `ai.mapier.swipe`, a unit-test target, the custom callback URL scheme `ai.mapier.swipe`, and an exact Supabase Swift `2.46.0` package pin.

**Step 2: Add non-secret configuration**

Set `SUPABASE_URL=https://pvlykxebusgsgrtrkrqh.supabase.co` and `OAUTH_CALLBACK_URL=ai.mapier.swipe://login-callback`. Leave `SUPABASE_PUBLISHABLE_KEY` as a visible development placeholder until the project key is available. Never add a secret/service-role key.

**Step 3: Generate and build the empty app**

Run: `cd ios && xcodegen generate`

Run: `xcodebuild -project Wavepoint.xcodeproj -scheme Wavepoint -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`

Expected: project generation and simulator build succeed.

**Step 4: Commit**

```bash
git add ios
git commit -m "build: scaffold native iOS app"
```

### Task 2: Keychain-backed Spotify provider tokens

**Files:**
- Create: `ios/Wavepoint/Auth/SpotifyProviderTokens.swift`
- Create: `ios/Wavepoint/Auth/SpotifyTokenStore.swift`
- Create: `ios/WavepointTests/SpotifyTokenStoreTests.swift`

**Step 1: Write the failing round-trip and deletion tests**

```swift
func testSaveThenLoadReturnsProviderTokens() throws {
  let expected = SpotifyProviderTokens(accessToken: "access", refreshToken: "refresh")
  try store.save(expected)
  XCTAssertEqual(try store.load(), expected)
}

func testDeleteRemovesProviderTokens() throws {
  try store.save(.init(accessToken: "access", refreshToken: "refresh"))
  try store.delete()
  XCTAssertNil(try store.load())
}
```

**Step 2: Run tests and verify RED**

Run: `xcodebuild test -project ios/Wavepoint.xcodeproj -scheme Wavepoint -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:WavepointTests/SpotifyTokenStoreTests`

Expected: FAIL because the token model and store do not exist.

**Step 3: Implement the minimum Keychain store**

Use a generic-password Keychain item scoped to service `ai.mapier.swipe.spotify` and account `provider-tokens`. Encode the value with `JSONEncoder`; update an existing item or add a new item. Treat item-not-found as `nil`.

**Step 4: Run tests and verify GREEN**

Run the same `xcodebuild test` command.

Expected: PASS.

**Step 5: Commit**

```bash
git add ios/Wavepoint/Auth ios/WavepointTests
git commit -m "feat: store Spotify tokens in Keychain"
```

### Task 3: Testable authentication state machine

**Files:**
- Create: `ios/Wavepoint/Auth/SpotifyAuthenticating.swift`
- Create: `ios/Wavepoint/Auth/AppSessionModel.swift`
- Create: `ios/WavepointTests/AppSessionModelTests.swift`

**Step 1: Write failing state-transition tests**

Cover these single behaviors:

- `restore()` yields signed-out when no Supabase session exists.
- `signIn()` moves through authorizing to signed-in and saves provider tokens.
- `signIn()` yields a recoverable error when Spotify supplies no provider access token.
- `signOut()` clears both Supabase state and Keychain tokens.

Use a small fake `SpotifyAuthenticating` and in-memory `SpotifyTokenStoring`; do not mock Supabase types.

**Step 2: Run tests and verify RED**

Run: `xcodebuild test -project ios/Wavepoint.xcodeproj -scheme Wavepoint -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:WavepointTests/AppSessionModelTests`

Expected: FAIL because `AppSessionModel` does not exist.

**Step 3: Implement the minimum state model**

Create a `@MainActor @Observable` model with one enum state: `.restoring`, `.signedOut`, `.authorizing`, `.signedIn`, `.failed(String)`. Keep network and Keychain logic behind the two protocols.

**Step 4: Run tests and verify GREEN**

Run the same focused test command, then the full test scheme.

Expected: all tests PASS.

**Step 5: Commit**

```bash
git add ios/Wavepoint/Auth ios/WavepointTests
git commit -m "feat: model Spotify authentication state"
```

### Task 4: Supabase Spotify adapter and web authentication session

**Files:**
- Create: `ios/Wavepoint/Auth/SupabaseSpotifyAuthenticator.swift`
- Create: `ios/Wavepoint/Auth/WebAuthenticationSession.swift`
- Create: `ios/WavepointTests/WebAuthenticationSessionTests.swift`
- Modify: `ios/Wavepoint/App/WavepointApp.swift`

**Step 1: Write the failing configuration test**

Assert that the Spotify authorization request uses:

```text
provider: spotify
redirect: ai.mapier.swipe://login-callback
scopes: user-read-email user-library-read user-library-modify user-read-recently-played
```

**Step 2: Run the focused test and verify RED**

Expected: FAIL because the request definition does not exist.

**Step 3: Implement the adapter**

Create a Supabase client with PKCE flow, request the exact scope string, present `ASWebAuthenticationSession`, exchange the callback with `supabase.auth.session(from:)`, and map `providerToken` / `providerRefreshToken` into the app-owned token model. Keep the presentation-session wrapper injectable.

**Step 4: Run tests and verify GREEN**

Run the focused test and then the full unit-test scheme.

Expected: PASS without opening a browser during tests.

**Step 5: Commit**

```bash
git add ios/Wavepoint ios/WavepointTests
git commit -m "feat: connect Supabase Spotify OAuth"
```

### Task 5: Cut Record sign-in UI and authenticated shell

**Files:**
- Create: `ios/Wavepoint/Design/Theme.swift`
- Create: `ios/Wavepoint/Features/Authentication/SpotifyLoginView.swift`
- Create: `ios/Wavepoint/Features/Cleanup/CleanupPlaceholderView.swift`
- Modify: `ios/Wavepoint/Features/AppRootView.swift`

**Step 1: Write a failing UI-state assertion**

Add accessibility identifiers for `spotify-login-button`, `auth-progress`, `auth-error`, and `cleanup-home`, then assert the root-state mapping in a unit test.

**Step 2: Run and verify RED**

Expected: FAIL because the view-state mapping does not exist.

**Step 3: Implement the approved visual direction**

Use the existing Cut Record dark shell, warm paper foreground, coral destructive accent, acid-lime keep accent, 24-point card radius, and spring button feedback. The login screen has one primary action and plain-language privacy copy; the signed-in placeholder confirms Spotify is connected and exposes Sign Out.

**Step 4: Build and test**

Run:

```bash
xcodebuild test -project ios/Wavepoint.xcodeproj -scheme Wavepoint -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild -project ios/Wavepoint.xcodeproj -scheme Wavepoint -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Expected: all tests pass and build succeeds without warnings introduced by Wavepoint code.

**Step 5: Commit**

```bash
git add ios
git commit -m "feat: add Spotify sign-in experience"
```

### Task 6: Configuration and handoff verification

**Files:**
- Create: `ios/README.md`
- Modify: `DESIGN.md`

**Step 1: Document external setup**

Document the Supabase callback, Supabase redirect allowlist entry, bundle ID, physical-device requirement for Spotify App Remote, and where the publishable key belongs. Explicitly prohibit client-secret/service-role keys in the app.

**Step 2: Verify repository and Supabase state**

Run:

```bash
git diff --check
git status --short
xcodebuild test -project ios/Wavepoint.xcodeproj -scheme Wavepoint -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Use the project-scoped MCP after tool reload to confirm project URL and zero unexpected Edge Functions.

**Step 3: Physical-device checkpoint**

Open `ios/Wavepoint.xcodeproj` in Xcode. Real Spotify login is complete only after an iPhone receives the Supabase callback and the app captures a non-empty provider access token. App Remote playback is a later slice.
