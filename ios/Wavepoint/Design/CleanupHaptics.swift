import CoreHaptics
import UIKit

enum CleanupHapticEvent: Equatable {
  case threshold
  case keep
  case remove
  case undo
  case success
}

struct SwipeThresholdFeedback: Equatable {
  private(set) var didTrigger = false

  mutating func update(distance: CGFloat, threshold: CGFloat) -> Bool {
    guard !didTrigger, abs(distance) >= threshold else { return false }
    didTrigger = true
    return true
  }

  mutating func reset() {
    didTrigger = false
  }
}

@MainActor
final class CleanupHaptics {
  typealias Action = @MainActor () -> Void

  static let live: CleanupHaptics = {
    let selection = UISelectionFeedbackGenerator()
    let keep = UIImpactFeedbackGenerator(style: .medium)
    let remove = UIImpactFeedbackGenerator(style: .heavy)
    let undo = UIImpactFeedbackGenerator(style: .light)
    let notification = UINotificationFeedbackGenerator()

    selection.prepare()
    keep.prepare()
    remove.prepare()
    undo.prepare()
    notification.prepare()

    return CleanupHaptics(
      isEnabled: CHHapticEngine.capabilitiesForHardware().supportsHaptics,
      selection: {
        selection.selectionChanged()
        selection.prepare()
      },
      mediumImpact: {
        keep.impactOccurred()
        keep.prepare()
      },
      heavyImpact: {
        remove.impactOccurred()
        remove.prepare()
      },
      lightImpact: {
        undo.impactOccurred()
        undo.prepare()
      },
      success: {
        notification.notificationOccurred(.success)
        notification.prepare()
      }
    )
  }()

  private let isEnabled: Bool
  private let selection: Action
  private let mediumImpact: Action
  private let heavyImpact: Action
  private let lightImpact: Action
  private let success: Action

  init(
    isEnabled: Bool,
    selection: @escaping Action,
    mediumImpact: @escaping Action,
    heavyImpact: @escaping Action,
    lightImpact: @escaping Action,
    success: @escaping Action
  ) {
    self.isEnabled = isEnabled
    self.selection = selection
    self.mediumImpact = mediumImpact
    self.heavyImpact = heavyImpact
    self.lightImpact = lightImpact
    self.success = success
  }

  func play(_ event: CleanupHapticEvent) {
    guard isEnabled else { return }
    switch event {
    case .threshold:
      selection()
    case .keep:
      mediumImpact()
    case .remove:
      heavyImpact()
    case .undo:
      lightImpact()
    case .success:
      success()
    }
  }
}
