---
name: sprite
description: Draw consistent pixel-art sprites and animation frames in code and export PNG spritesheets for Godot. Use when the user asks for a sprite, character, icon, tile, or animation frames.
---

Sprites are drawn in code, not by an image model. Method from the cw-crew creatures.

## Method

- One script per character: `tools/sprites/<name>.py`. Rerun to regenerate. Helper: `canvas.py` here (Canvas, mix, cyc, ease, rnd, sheet).
- **Palette struct**: named slots (`body, shade, light, belly, mark, accent...`). Never inline colors. Variants (enemy, state vs citizen, era) swap the palette, not the code.
- **One geometry function**: derive every position (center, top, bottom, radii, eye line) from a single `Body` state. Every pose reuses it, so the silhouette never drifts.
- **One draw function, layered**: dark outline oval, then body oval inset (gives the rim shade), then highlight, then belly/markings, then face and limbs.
- **Poses are parameters**, not new drawings: eyes/mouth/arms as small enums (`open, closed, wide, sad...`), plus squash and offset.
- **Motion**: `cyc(f, n)` for loops, `ease` for one-shots, 1-2 px max per frame, fixed frame rate (125 ms). Breathe via small squash. `rnd` for sparkle/confetti.
- **Resolution**: draw at small logical size (e.g. 32x32), `scale=2` hi-res, export with 4x nearest-neighbor. Soft shadow ellipse under the feet.
- Keep one character sheet per file, frames in one row. State frame count and size.

## Output

- `assets/sprites/<name>.png`. Import in Godot with Filter = Nearest.
- Read the PNG after export. Check silhouette consistency across frames, fix, then show the user.
- Add `<name> | original (generated in-repo) | CC0` to `assets/CREDITS.md`.

Style, theme, and design choices are yours. The user reviews.
