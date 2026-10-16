# References and AI declarations

Jam rules 3-6: declare every ready-made source and every AI use. Missing or wrong = disqualified.
Add a row the moment you use something. Categories: visual, audio, code, text, other.

## Ready-made sources

| Category | What | Author | Link | License | Where used |
|---|---|---|---|---|---|
| visual | Blue Marble Next Generation, December 2004 (`world.200412.3x5400x2700.jpg`) | NASA Earth Observatory (Reto Stöckli, NASA GSFC) | https://assets.science.nasa.gov/content/dam/science/esd/eo/images/bmng/bmng-base/december/world.200412.3x5400x2700.jpg | Public domain | Globe texture + water mask (`scenes/globe`); 21600² tiles C1, C2, D1, D2 (same dataset) for the zoom detail patches |
| visual | Resurrect 64 palette | Kerrie Lake (Lospec) | https://lospec.com/palette-list/resurrect-64 | Free to use (Lospec palette list) | All pixel art, globe palette pass |

## AI use

| Category | Tool | Purpose | Where used |
|---|---|---|---|
| code | Claude (Anthropic) | Writing game code and asset generator scripts | `scenes/`, `scripts/`, `data/`, `tests/`, `tools/` |
| visual | Claude (Anthropic) | Writing the Python scripts that draw the pixel sprites | `tools/sprites/`, `sprites/` |
| text | Claude (Anthropic) | Drafting design docs and minigame specs | `docs/` |
| other | Claude (Anthropic) | Globe style prototype (three.js page, not shipped) | Design decision for issue #6 |
