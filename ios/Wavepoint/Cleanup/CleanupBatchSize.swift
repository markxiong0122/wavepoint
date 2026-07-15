import Foundation

enum CleanupBatchSize: Int, CaseIterable, Identifiable, Sendable {
  case needleDrop = 10
  case sideA = 25
  case crateDig = 50

  var id: Int { rawValue }
  var songCount: Int { rawValue }

  var title: String {
    switch self {
    case .needleDrop: "Needle Drop"
    case .sideA: "Side A"
    case .crateDig: "Crate Dig"
    }
  }

  var detail: String {
    switch self {
    case .needleDrop: "A quick cleanup hit."
    case .sideA: "The sweet spot."
    case .crateDig: "A proper deep clean."
    }
  }

  var isRecommended: Bool { self == .sideA }
}
