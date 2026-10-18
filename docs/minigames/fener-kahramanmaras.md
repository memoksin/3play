# Fener: Kahramanmaras (Citizen, #123)

Replaces Fit for `data/disasters/kahramanmaras.tres` (`minigame = &"fener"`). Port of the team's HTML prototype
(kahr-proto/fener), in the 2.5D style (`docs/art/style-2.5d.md`), on a much bigger map.

## Story

6 February 2023, between the 04:17 (Mw 7.8) and 13:24 (Mw 7.5) quakes, still dark (HUD clock 04:38 to 05:18, one story minute per 6 s).
Snowing, the grid is down. Your family and neighbours are scattered in the dark; you have a torch with a battery.

## Play

- Camera: the style angle (pitch -40, yaw -22, FOV 26) follows the player; the opening shows the whole slab and
  glides in (any key or click skips). Buildings that hide the player, the torch target or a found person fade out.
- Controls: WASD / arrows walk (screen-relative), the mouse aims the torch, holding the left button walks to the
  pointer (touch the same), Space / F torch on / off.
- Darkness is real light: low moon and ambient, warm practicals (camp fires, tents, the bakery oven, work lights,
  beacons) and the torch (shadowed spot: walls cut it). Gameplay "seen" = torch cone with a clear line of sight
  (`FenerMap` solids >= 2.2 m block it) or the 2.4 m circle around you.
- Time 4:00 (a run is one of two games, a first-time player needs about 4 minutes), walk speed 5.2 m/s. Battery drains while the torch is on (about 130 s); two spare batteries are handed out in the rescue crew zones (only to a torch below `low_battery`).
- Supplies are handed out by walking into a rescue crew zone (the orange ring on the ground, the same area trapped people are reported to), not by walking up to a rescuer, and only while needed: the blanket while a cold person waits and you hold none (the same rule stands for a first aid kit and an injured person, but this skin has nobody injured, so no kit is ever put out), a battery when the torch is low. Nothing is out otherwise and the errand banner / guide row / arrow only ever name what is needed and not in hand.
- Beginner-friendly tuning (aim: a careful first run saves 4-5 of 5): slower aftershocks (first one after about 60 s, 2.5 s warning),
  4 hidden holes, long invulnerability after a hit, the light finds people 1.3 m beyond their body, crews and the
  assembly area count a little beyond their edge, followers hurry to catch up (and snap back after 22 m).
  HUD guide under the top-left panel: arrow + distance to the assembly area (and the crew when someone is trapped),
  people left to save.
- Finding someone (the light reaches their face): a heartbeat, a short slow motion, a warm light on the face.

## People (`data/skins/kahramanmaras_fener.tres`, `FenerPerson.Kind`)

| Person | Kind | Calls | Needs |
|---|---|---|---|
| Mom, Elif (sister) | LOST | whistle | found -> follows |
| Grandpa | SLOW | whistle | follows, everyone walks slower |
| Mrs. Ayse | TRAPPED | taps | under rubble: do not dig, report her to a rescue crew (NW crew or the AFAD tent) |
| Little Can | COLD | "so cold..." | blanket (handed out in a rescue crew zone once Can is found; the HUD points to the zone), then follows |

Followers are safe once you walk into the assembly area with them. Score = safe + reported, of 5.
`FenerPerson.Kind.INJURED` (first aid kit, then follows slowly; "help!") and the kit pickup stay in the rules and are tested on a copy of the skin
with an injured person added (`tests/test_fener.gd`), but the shipped skin has nobody injured (Mr. Hasan was cut to shorten the game), so there are
no injured spots in `FenerMap.SPOTS` and no kit is placed (`_place_items` skips a kit when nobody needs one). To bring one back: add the person with
a `spot_group` that has spots.
Spots are random per run from `FenerMap.SPOTS` (each group in several regions).

## Map (`scripts/fener_map.gd`, 112 x 80 m)

Four regions around a crossroads: collapsed apartments with the rescue crew (NW), market street (NE), old houses (SW),
tent camp with the assembly area (SE). A toppled block lies across the north cross street, a fallen pole across the
south one. Top-down check: `godot --headless --path . -s res://tools/fener_map_png.gd` -> `export/shots/fener_map.png`.

## Walking and collisions

The player is a circle (radius 0.35 m) on the ground plane. What stops him is `FenerMap.WALK`: per model, the part
that is higher than a step (0.4 m) and lower than nothing a person walks under (1.8 m), measured from the mesh
(`scripts/fener_footprint.gd`): boxes at the exact yaw of the place, discs for trunks and barrels. Stones, bricks,
flat debris and rubble aprons are stepped over; eaves, balconies and branches hang overhead. `FenerMap.FOOT` stays
the mass of a model for the light, the fade, the aftershock risk and the rescuers' routes.
Movement is in steps of at most 12 cm, each pushed out of what it hit (`fener.gd` `_try_move`): he slides along
walls and round corners and trunks; buildings, rubble piles, vehicles and the map edge still stop him.
After changing a model or a placement, re-measure: `godot --headless --path . -s res://tools/fener_footprints.gd`
(`-- gen=1` prints a first WALK table), then `tests/test_fener_walk.gd`. Top-down check of blockers vs models:
`godot --path . -s res://tools/fener_coll_shots.gd -- map=1` (or `-- models=a,b`) -> `export/shots/fener_coll_*.png`.

## Hazards (all warn before they hurt)

| Hazard | Warning | Hurts when |
|---|---|---|
| Live cable end | sparks + blue flash (self-lit, seen from 10 m), ring | you touch it (knock-back) |
| Hole under snow | faint dimple; revealed by the torch within ~10 m (hole + orange ring + sign) | you walk in (stunned 1 s) |
| Leaning wall / ruin | dust trickles, red-white tape once lit, "crumbling" toast after 0.9 s under it | you stay under it 2 s |
| Crack | dashed outline once lit, pulses red in a shock; slows you | you stand on it at the shock hit |
| Broken glass | glints in the torchlight | you step in it |
| Aftershock | 1.5 s warning: red screen edges, red bands round every building, cracks and walls pulse | you are within 3 m of a building, under a wall or on a crack when it hits (debris and dust fall) |

Injuries slow you. Each aftershock also changes the neighbourhood once (order random): a ruin by the old houses
falls and blocks part of the lane, a pole comes down by the market (new live cable), the avenue splits (new hole).

## Result

`Game.finish_minigame(saved, 5, extra)`, extra = `{injuries, battery, time_left, aftershocks_dodged, found}`.

## Audio hooks (Sude wires the files)

`sound_event(kind, index, pos)` on the Fener node (`pan_of(pos)`, `volume_of(pos)` for stereo / distance):

| kind | cue | notes |
|---|---|---|
| step | FN2 | every 0.7 m walked |
| lamp_on / lamp_off | FN3 | 0-1 s on, 2-3 s off |
| battery_low, battery_dead | FN4 | |
| whistle | FN5 | index = person, from `pos` |
| tap, call, cry | (new) | trapped tapping, injured "help", cold child; `pos` is always the person's real spot (also behind walls); they repeat every 1.8 s (close) to 6 s (far) |
| found | FN6 | index = person |
| heartbeat | (new) | with found |
| pickup | FN6? | index 0 battery, 1 kit, 2 blanket |
| treat, report | (new) | kit / blanket used, crew told |
| saved, all_saved | FN7 | |
| aftershock_warn | FN8a | |
| aftershock_hit, debris, collapse | FN8 | collapse index = event |
| hurt | FN9 | index 0 cable, 1 hole, 2 wall, 3 glass, 4 debris, 5 crack |
| spark | (new) | live cable, index = hazard, from `pos` |
| creak | FN8a | leaning wall warning |

Ambience: FN1 (same as D1) for the whole scene.

## Art seams

- People: the rigged Meshy characters (`assets/3d/kahramanmaras/meshy_*.glb`, clips and ground speeds in
  `tools/models/meshy/README.md`). Swap per person (`FenerPerson.figure`, `figure_scale`, `figure_speeds`) or the
  player / rescuers (`FenerSkin.player_scene` + `player_speeds`, `rescuer_scene` + `rescuer_speeds`); no code change.
  Origin at the feet, front +Z, real size (1.3 m child ... 1.8 m rescuer). `figure_speeds` = metres per second each
  moving clip covers: the clip plays at (real speed / that), so the planted foot keeps still. A clip the new art lacks
  falls back to a close one (`FenerRig.FALLBACK`); a model without an AnimationPlayer is just placed and turned.
- Clips by state (`scenes/minigames/fener/fener_rig.gd`, `fener_world.gd`): player `idle` standing, `walk` / `run` by
  real speed (5.2 m/s = `run` at 1.4x; a child follower at 2.0x, up to 2.6x when catching up, see `fener_rig.gd`); lost people `idle` (looking about), found followers
  `idle` / `walk_follow` / `run` by real speed (the old and the hurt: `walk_tired`), Ayse `trapped`
  (lying across the screen) until the crew is there (an injured person: until first aid starts), Can `shiver` until the blanket, saved
  people walk to their place and `idle`. Rescuers `dig`; on a report the nearest one of that crew `wave`s, runs
  (A* around the buildings, 4.2 m/s `run`), `dig`s by the person, who gets up. Walk <-> run switch at the geometric
  mean of the two clips' ground speeds (with hysteresis), idle below 0.12 m/s. Figures further than 46 m from the
  player are not stepped. Frames: `fener_shots.gd` states `follow`, `trapped`, `cold`, `crew*`, `area_live`
  (and `_close` twins).
- Set pieces: `FenerMap.PLACES` (model, x, z, yaw); solids from `FenerMap.FOOT`. Practical lights per model:
  `LIGHTS` in `scenes/minigames/fener/fener_world.gd`.
- Slab body: `tools/models/kahramanmaras/fener_hood_slab.py`; pickups: `fener_items.py`.

## Tools

- Tests: `godot --headless --path . -s res://tests/test_fener.gd` (bot plays 4 full runs and one with the kit-skin copy, every mechanic, the figures' clips and the crew run).
- Walking: `godot --headless --path . -s res://tests/test_fener_walk.gd` (shapes vs meshes, walks round every blocker, slides, edges).
- Frames: `godot --path . -s res://tools/fener_shots.gd` -> `export/shots/fener_*.png`.
- Frame cost: `godot --path . -s res://tools/perf.gd -- --only=fener`.
