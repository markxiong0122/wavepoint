# Cleanup Playback and Interaction Polish

## Goal

Keep every cleanup card and action visible on supported iPhones, recover Spotify autoplay after transient per-track failures, and add restrained tactile feedback to cleanup decisions.

## Playback

Automatic playback remains the default. If Spotify App Remote fails on a later card, that card falls back to manual playback without permanently disabling autoplay. The next card attempts automatic playback again. Choosing **Continue Without Autoplay** after the initial connection failure remains an explicit sticky manual-mode choice.

## Layout

The cleanup header, progress, card, and action controls remain in a vertical stack. The action controls receive their intrinsic fixed height first. The card fills only the remaining space. Within the card, metadata and controls retain readable intrinsic sizes while artwork flexes and crops with `scaledToFill`. Titles remain limited to two lines and artists to one line. Optional Spotify connection guidance is folded into existing playback status rather than consuming another row.

This keeps the current tactile poster-card aesthetic without introducing an internal scroll view or shrinking the entire card.

## Haptics

Use subtle, action-specific feedback:

- selection feedback once when a drag crosses the decision threshold;
- medium impact when Keep or Remove commits, whether by swipe or button;
- light impact for Undo;
- success notification after a cleanup batch commits.

Haptics stay in the UI layer and respect the system's haptic behavior. No settings surface is added in this version.

## Verification

Add coordinator regression tests for transient autoplay recovery and explicit manual mode. Add testable layout policy coverage for constrained heights and long metadata. Add a small haptic abstraction with a recording test double so actions fire exactly once. Run all iOS tests, install on iPhone 61, and visually verify the previously overlapping card.
