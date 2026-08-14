Color palette test artifacts live here.

Purpose

- Store committed baseline artifacts for color regression tests.
- Keep generated visual standards out of temp files and in a stable, reviewable location.

Current baseline targets

- color-palettes/dark2-40-seed10-colors.txt
- color-palettes/dark2-40-seed10-wheel.png

How to create or refresh the baseline

Run the color palette tests with the environment variable below set to true:

OMIX_UPDATE_COLOR_ARTIFACTS=true

This will write the current 40-color palette baseline and its wheel image into this folder.

Notes

- The text file is the primary standard because it is less brittle than image-only comparison.
- The PNG is a visual artifact for review and an optional byte-level check when present.
- Commit updated artifacts only when the palette behavior is intentionally changed.