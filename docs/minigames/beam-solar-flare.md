# Spec: Beam minigame, solar flare 3026 (#124)

Mechanic: **Beam**. Skin: solar flare, 14 March 3026. Role: State. Replaces the Fit skin of the solar flare.
Source: the team's web prototype "Işın Ağı" (Beam Grid). Rules, waves, timings, preview and result are ported 1:1;
`tests/test_beam.gd` checks the rules against the prototype's own results.

## Story beat

The Sun hurls a giant flare at Earth. It travels like one laser beam. The satellite network between them is the
only shield: turn the satellites so the beam ends in collectors. Every city it touches loses power.

## Board

A grid of cells. Above it the Sun (the flare comes down one column) and the **Parker base**; left and right the
**West / East rings**; below it the **Earth** with one city per column. Inside the grid: satellites, collectors
and habitats (stations that are cities too).

| Piece | Glyph | Rule |
|---|---|---|
| Mirror | M | Reflects: diagonal = 90 degree turn, edge-on = passes, face-on = sends it back |
| Splitter | S | Always splits in two half beams: edge-on = left + right, diagonal = straight + side, face-on = straight + back |
| Thermal | T | Like a mirror for the first beam of a shot; the second one overheats it: it locks and lets the beam pass straight |
| Collector | C | Takes the beam (its energy share counts) |
| Habitat | H | A city inside the grid |

Rotation: 8 steps of 45 degrees, the plate is symmetric (rotation r acts as r mod 4): out = (2m - in) mod 8.
The beam only ever runs straight (never diagonal), so it leaves the grid through exactly one side.
Cities per wave: columns + 3 (W, E ring, Parker) + habitats. Waves: 10, 11, 11, 12 cities = **44**.

## Flow

Title card (four rule cards without numbers, route preview toggle) > per wave: briefing (class, time, new piece diagrams, tip) > countdown
(turn satellites; solve the puzzle and the clock drops to 5 s, then the flare fires by itself) > the shot (0.58 s charge, the beam travels at 9.5 cells/s, events play on
time) > result card (saved/total, stars, lost cities, energy, time left; retry or next) > summary (sum of the best
run per wave, rank, stars, mean energy; play again or **Continue**) > `Game.finish_minigame(saved, 44,
{stars, energy, rank})` > the game's result card (`SF_CARD_SCORE`, "%d/44").

| Wave | Class | Time | New |
|---|---|---|---|
| 1 First Light | M4.2 | 45 s | mirrors |
| 2 Forking | X1.8 | 55 s | splitter |
| 3 Heat Wave | X4.7 | 65 s | thermal |
| 4 Super Flare | X28 | 80 s | everything |

Waves 3 and 4 were redesigned easier than the prototype's (10 satellites, 5 perfect setups, 10 clicks): the jury should solve
them without a struggle. Now 5 / 6 / 6 / 7 satellites, exactly one perfect setup of 4^n in every wave, 6 / 6 / 7 / 7 clicks from the
start (the start already fails by 1-2 cities), no idle satellite. Each wave forces its new piece in every perfect run: 1 a mirror reflects,
2 a splitter splits, 3 a thermal reflects, 4 splitters + a thermal that overheats (the tip: burn one out on purpose) + a mirror.
Same cities (10, 11, 11, 12 = 44), same pieces in wave 4 (3 mirrors, 2 splitters, 2 thermals, 3 collectors, 2 habitats).
`tests/test_beam.gd` `_difficulty` runs every setup through `BeamLogic` to prove it; the prototype's old waves 3 and 4 stay in that
test as parity fixtures.

Wave 4 was re-laid out once more (same pieces, new map, Sun column 3, start `6021512`, solution `3232123`) because players got lost:
the Sun beam meets a splitter at once (one half goes straight to a collector), the other half goes down a mirror to a second
splitter, whose halves meet again at one thermal satellite: the first beam passes it, the second overheats it and passes straight
into the collector behind it. An offline search (pruned depth-first search that follows the beam and
stops a branch when it reaches a city; node count = dead ends a player meets) gives 53 nodes for the new wave 4 against 161 for the old
one (waves 1-3: 21 / 81 / 25). The intro text now says "three parts" (two splitters in a row make three).

**Rush**: the moment the route turns perfect (the puzzle is solved, preview on or off) the clock drops to 5 s (`RUSH_TIME`, only if more
was left, once per countdown), the screen shakes (a spike, then a rumble), the alarm "FLARE INCOMING!" / "PATLAMA GELİYOR!"
(`SF_BEAM_RUSH`) blinks in the right column, and the flare fires by itself at 0. Because of this the **Fire button is hidden**
(`beam.gd` `show_fire_button`, false; the button and its glow stay in the scene and the `F` key still fires, a debug / test hook). The player then goes on to the next
wave without sitting out the rest of the countdown. Turning satellites away and back does not give time back.

Stars per wave: 3 with no city lost, 2 with one, 1 with two, else 0. Rank by total stars: 12 Sun Warden,
9 Shield Commander, 5 Grid Operator, else Trainee Engineer.

## Controls

- Mouse: click a satellite = +45 degrees, right-click / Shift+click = back, wheel = either way. Hover shows a ghost
  of the next position.
- Keyboard (countdown only): Tab / Shift+Tab or arrows pick a satellite, E / Space / Enter turn it, Q turns back,
  F fires (hidden shortcut, no button). Cards: Enter presses the main button.

## Route preview (on by default)

Dashed route, red cross where it reaches a city, warning ring on that city, a pulsing red "!" badge over every place
it hits (Earth city, habitat, ring, Parker base: `sf/alerts.gd`, fed by `beam.gd` from `BeamLogic.Result.hit`, so a
skin's pieces cannot leave a strike unmarked; `tests/test_beam.gd` checks every hit of every wave over random setups),
ring on reached collectors, "!" on a
thermal satellite that will overheat, forecast in the HUD ("2 AT RISK" / "SAFE") and the "ROUTE SAFE" toast once the route
is perfect (the Fire button's glow only shows when `show_fire_button` is on). Off ("blind"): none of it.

## Code

| File | What |
|---|---|
| `scripts/beam_logic.gd` | Rules, no nodes: `parse`, `simulate`, `city_keys`, `stars`, `rank`, `solve_clicks` |
| `scripts/beam_wave.gd`, `scripts/beam_skin.gd` | Data: one wave; the skin (waves, timings, text prefix, art scenes) |
| `data/skins/solar_flare_beam.tres` | The 4 waves |
| `scenes/minigames/beam.tscn` / `.gd` | Flow, input, countdown, the shot, score, HUD and cards |
| `scenes/minigames/beam/sf/alerts.gd` | The "!" badges of the preview (3D board only; a board without `set_alerts` / `alert_pos` skips them) |
| `scenes/minigames/beam/sf/*` | The 3D board and pieces the skin uses (look only, see "3D art") |
| `scenes/minigames/beam/*` | The 2D board and placeholder pieces (what a skin field left empty falls back to) |
| `tools/beam_shots.gd` | Screenshots, 1920x1080: per wave brief, plan, plan solved, shot out, result. `godot --path . -s res://tools/beam_shots.gd [-- tr]` |
| `tools/perf.gd` | Frame cost: `--only=beam` measures "beam plan", "beam fire" and "beam plan 2D" (the placeholder board) |
| `tests/test_beam.gd`, `tests/test_beam3d.gd` | Rules, flow and input; the 3D board (clicks cell by cell, plate angle, dark windows, beams, HUD clear of the Sun and the cities) |

Texts: `SF_BEAM_*` keys in `locale/strings.csv`.

## 3D art (`data/skins/solar_flare_beam.tres`)

The skin points every `*_scene` field at `scenes/minigames/beam/sf/` and the board at `sf/board.tscn`: the approved
art pilot (`scenes/art_pilot/solar_flare.tscn`, CameraPlay "Piano Tiles" lane view) is the game's board. Models are
`assets/3d/solar_flare/*.glb`, effects `assets/3d/solar_flare/fx/` (sun, beam path, orbital grid, dial, aurora, space sky).

- **Camera and layout**: `sf/layout.gd`. Cell (x, y) -> `Vector3((x + 0.5 - cols / 2) * 4, 2, (y + 0.5 - rows / 2) * 4 + z_shift)`;
  the camera, Earth and cities stay where the pilot has them (a wave with fewer than 9 rows ends nearer the Sun).
  The projection is plain math on the camera transform, so labels, clicks and beams agree with the picture.
- **Clicks**: `board.cell_at(pos)` = a ray from the camera against the plane y = 2 (the satellites' plate centres), floored to the
  cell. `board.cell_center(cell)` is the way back. Cells shrink towards the Sun; clicks are per cell, not per pixel row.
- **Pieces stay `Node2D`** (the contract below holds): the board sets `position` (screen px; city codes, habitat names and
  the satellite "!" / lock badges are drawn in 2D there) and `world` (a `Vector3`); the model is a `Node3D` child standing at
  `world`. Satellite plate: `rotation.y = -turns * PI / 4`. A dark city / habitat / station hides its `<name>_glow` meshes
  (flickering out first); `warning` pulses a red light and ring; a locked thermal swaps to `sat_thermal_hot`.
- **Beams**: `sf/beams.gd` builds one `fx/beam_path.gd` ribbon per `BeamLogic.Seg` (plus the Sun's long beam, from the emitter
  to the Parker gate, that grows during the charge). Preview = dim ribbons and a red glint on a city it reaches; shot = `fill`
  follows `fire_t`, a glint and a light where a segment ends. The 2D `fx.tscn` (bursts, rising labels) is still the effects
  layer: it works in screen px, which `board.event_pos` gives.
- **Screen shake** turns the real camera by the board's px offset; the maths above uses the unshaken camera.
- **HUD** keeps off the Sun's band and the cities: left panel top-left, hint (and the Fire button when shown) top-right, toast just under the Parker
  truss (`beam.tscn`, `TOAST_Y`). The briefing diagrams stay flat 2D (`diagram_satellite_scene` = the placeholder satellite).

## Art: replacing the placeholders

Every piece is its own scene. Set a `BeamSkin` field (`data/skins/solar_flare_beam.tres`) to a new scene; null keeps
the placeholder in `scenes/minigames/beam/`. A piece is a `Node2D` placed at its spot on screen; the board sets the
properties below before adding it and the scene updates them every frame. `tick(dt)` (game time) is called on
every piece if it has one. Pieces may ignore properties they do not show.

| Field | Placeholder | Properties |
|---|---|---|
| `satellite_scene` | `satellite.tscn` (3D: `sf/satellite.tscn`, also `world`) | `kind` (&"M", &"S", &"T"), `cell` (px), `turns` (45 degree steps, not wrapped: ease to it), `highlight`, `hover`, `heat` (0-2), `locked`, `overheat_predicted`; methods `bump()`, `flash(color)`. Draw the plate above the beams (`z_index` 2) |
| `collector_scene` | `collector.tscn` | `cell`, `charge` (0-1), `targeted` |
| `habitat_scene` | `habitat.tscn` | `cell`, `label`, `font`, `warning`, `dark` |
| `city_scene` | `city.tscn` | Earth city: `cell`, `code`, `font`, `seed_value`, `warning`, `dark` |
| `station_scene` | `station.tscn` | `kind` (&"ring_w", &"ring_e", &"parker"), `cell`, `count` (cells long), `gate` (Parker: flare column), `label`, `dark_label`, `font`, `warning`, `dark` |
| `grid_scene` | `grid.tscn` | `cols`, `rows`, `cell` (position = grid top-left) |
| `backdrop_scene` | `backdrop.tscn` | `board` (geometry: `sun_center`, `sun_radius`, `earth_center`, `earth_radius`, `sun_emitter()`...), `urgency`, `charge`, `charging`, `arrow` |
| `beams_scene` | `beams.tscn` | `board`, `sim` (BeamLogic.Result), `mode` (NONE / PREVIEW / FIRE), `fire_t`; `heads()` for sparks |
| `fx_scene` | `fx.tscn` | `cell`, `font`; `burst(pos, n, color, power)`, `spark(pos, color)`, `float_text(pos, text, color, sub)` |
| `diagram_satellite_scene` | (`satellite_scene`) | Flat satellite for the briefing diagrams when `satellite_scene` is 3D |
| `board_scene` | `board.tscn` (3D: `sf/board.tscn`) | Whole board (e.g. a 3D slab). Keep `board.gd`'s API: `build`, `cell_at`, `cell_center`, `event_pos`, `seg_points`, `sat`, `collector`, `city`, `cities`, `collectors`, `tick`, `cell`, `origin`, layers `beams`, `fx`, `backdrop`; optional `alert_pos(ev)`, `set_alerts(marks)` (the preview's "!" badges, `sf/board.gd`) |

Layout (2D board): the board fills `Beam.AREA` (between the HUD columns), one cell at most 92 px, with room for the Sun and
Parker above (1.45 cells) and the Earth below (1.85 cells).

## Audio hooks (no sounds yet)

The prototype's synth sounds were not ported. `beam.gd` emits `satellite_turned(index, dir)` and
`sound_event(kind, index)`: `ready` (route turned safe), `tick` (last 10 s; index 1 = last 3 s), `charge`,
`fire` (beam leaves the Sun), `reflect` (index = nth reflection), `split`, `overheat`, `collect`, `blackout`,
`wave_good`, `wave_bad`, `rush` (route found: clock cut to 5 s). Nothing in `scripts/audio.gd` hooks the scene yet.
