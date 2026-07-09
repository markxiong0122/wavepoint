# Wavepoint Project Guidance

## Product scope

The first version is a Spotify Liked Songs swipe-cleanup experience. Daily recommendation playlists are out of scope.

Optimize for one measurable outcome: confident song decisions per minute. Keep implementation small and complete across the cleanup flow.

## Design system

Always read `DESIGN.md` before making visual or UI decisions. All font choices, colors, spacing, motion, accessibility, and aesthetic direction are defined there. Do not deviate without explicit user approval. In QA, flag code that does not match `DESIGN.md`.

## Spotify language

Spotify does not expose exact lifetime play counts or a reliable per-track last-listened date. Say “outside recent rotation” when that is the evidence. Never invent precision.

Swipes stage removals. A separate review step commits the batch. Do not make the swipe itself an irreversible API call.
