# Asset credits

Rules 3.4 and 4.2: missing or wrong declarations = disqualified. Add a row the moment an asset enters the repo.
Columns required per asset: name, author, link, license, where used.

## Ready-made assets in use

| Asset | Source | License |
|---|---|---|
| sprites/indian_ocean/pipe_tiles.png | original (generated in-repo by `tools/sprites/indian_ocean/pipe_tiles.py`, code written with Claude) | CC0 |
| sprites/indian_ocean/sensor_buoy.png | original (generated in-repo by `tools/sprites/indian_ocean/sensor_buoy.py`, code written with Claude) | CC0 |
| sprites/indian_ocean/siren.png | original (generated in-repo by `tools/sprites/indian_ocean/siren.py`, code written with Claude) | CC0 |
| sprites/indian_ocean/coast_bg.png | original (generated in-repo by `tools/sprites/indian_ocean/coast_bg.py`, code written with Claude) | CC0 |
| fonts/PixelifySans.ttf (Pixelify Sans, variable) | Stefie Justprince, https://github.com/google/fonts/tree/main/ofl/pixelifysans (upstream https://github.com/eifetx/Pixelify-Sans). All UI text (`ui/theme.tres`) | SIL OFL 1.1, license text in `assets/fonts/OFL.txt` |
| Palette Resurrect 64 | Kerrie Lake, https://lospec.com/palette-list/resurrect-64. All pixel art, UI colors (`ui/palette.gd`) | No formal license; author approved commercial use in a Lospec comment (22 Aug 2023). Colors only, no artwork |

## Planned third-party assets (NOT in the repo yet: move a row up and fill every column once added)

| Asset | Author | Link | License | Where used |
|---|---|---|---|---|
| Low-poly 3D kits (nature, city) | Kenney | https://kenney.nl/assets | CC0 1.0 | Diorama scenes. TODO list the exact packs used |
| Music loop | TODO | TODO | TODO (CC0 only) | TODO |
| Sound effects | TODO (Freesound) | TODO | TODO (CC0 only; check each file, some Freesound files are CC-BY) | TODO |

## AI usage declaration

One block per category: visual, audio, code, text, other. Write "None" if not used, do not leave blank.

| Category | Tool | Purpose | Where used |
|---|---|---|---|
| Visual | Claude Code (code that draws the sprites, not an image generator) | Pixel-art sprite scripts | `tools/sprites/**`, `assets/sprites/**`. TODO add any image generator if one is used |
| Audio | None so far | TODO | TODO |
| Code | Claude Code | Game code and tooling | `ui/palette.gd`, `ui/logo.tscn`, `tools/build_theme.gd` (generates `ui/theme.tres`), `tools/render_mockups.gd`. TODO add more as they land |
| Text | Claude | Drafts of design specs, intro and result card text; facts checked against sources | `docs/minigames/**`, `docs/ui.md`, `locale/strings.csv` |
| Other | Claude Code | Repo workflow, issue and PR handling | repo-wide |

Update this table when a new tool or use appears (image generator, music tool, anything).
