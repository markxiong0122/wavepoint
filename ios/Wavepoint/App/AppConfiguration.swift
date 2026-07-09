import Foundation

struct AppConfiguration: Equatable {
  let supabaseURL: URL
  let supabasePublishableKey: String
  let spotifyClientID: String
  let callbackURL: URL
}
