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
| globe/earth_4k.jpg | NASA Blue Marble Next Generation, Dec 2004 (`world.200412.3x5400x2700.jpg`, resized to 4096x2048) | Public domain |
| globe/patch_indian_ocean.jpg, globe/patch_kahramanmaras.jpg | NASA Blue Marble Next Generation, Dec 2004, 21600² tiles, cut by `tools/globe/patches.py` | Public domain |

## Planned third-party assets (NOT in the repo yet: move a row up and fill every column once added)

| Asset | Author | Link | License | Where used |
|---|---|---|---|---|
| Low-poly 3D kits (nature, city) | Kenney | https://kenney.nl/assets | CC0 1.0 | Diorama scenes. TODO list the exact packs used |
| Music loop | TODO | TODO | TODO (CC0 only) | TODO |
| Sound effects | TODO (Freesound) | TODO | TODO (CC0 only; check each file, some Freesound files are CC-BY) | TODO |
| Font | TODO | TODO | TODO | UI |
| Palette Resurrect 64 | Kerrie Lake | https://lospec.com/palette-list/resurrect-64 | free to use, TODO confirm wording | All pixel art |

## AI usage declaration

One block per category: visual, audio, code, text, other. Write "None" if not used, do not leave blank.

| Category | Tool | Purpose | Where used |
|---|---|---|---|
| Visual | Claude Code (code that draws the sprites, not an image generator) | Pixel-art sprite scripts | `tools/sprites/**`, `assets/sprites/**`. TODO add any image generator if one is used |
| Audio | None so far | TODO | TODO |
| Code | Claude Code | Game code and tooling | `scenes/**`, `scripts/**`, `data/**`, `tests/**`, `tools/**` (incl. `scenes/globe*`, `tools/globe/**`) |
| Text | Claude | Drafts of design specs, intro and result card text; facts checked against sources | `docs/minigames/**`, `locale/strings.csv` |
| Other | Claude Code | Repo workflow, issue and PR handling | repo-wide |
| Other | Claude Code | Globe look prototypes (three.js web pages, not shipped) used to pick the globe style | Design decision for issue #6 |

Update this table when a new tool or use appears (image generator, music tool, anything).
