import CoreGraphics

struct CleanupCardLayout: Equatable {
  let artworkHeight: CGFloat
  let cardHeight: CGFloat
  let bottomClearance: CGFloat

  init(
    availableSize: CGSize,
    detailHeight: CGFloat,
    shadowDepth: CGFloat
  ) {
    let availableHeight = max(0, availableSize.height)
    bottomClearance = min(max(0, shadowDepth), availableHeight)

    let contentHeight = max(0, availableHeight - bottomClearance)
    let reservedDetailHeight = min(max(0, detailHeight), contentHeight)
    artworkHeight = min(
      max(0, availableSize.width),
      max(0, contentHeight - reservedDetailHeight)
    )
    cardHeight = artworkHeight + reservedDetailHeight
  }
}
