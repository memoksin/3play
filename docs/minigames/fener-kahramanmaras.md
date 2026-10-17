# Fener: Kahramanmaras (Citizen, #123)

Replaces Fit for `data/disasters/kahramanmaras.tres` (`minigame = &"fener"`). Port of the team's HTML prototype
(kahr-proto/fener), in the 2.5D style (`docs/art/style-2.5d.md`), on a much bigger map.

## Story

6 February 2023, between the 04:17 (Mw 7.8) and 13:24 (Mw 7.5) quakes, still dark (HUD clock 04:38 to about 05:28).
Snowing, the grid is down. Your family and neighbours are scattered in the dark; you have a torch with a battery.

## Play

- Camera: the style angle (pitch -40, yaw -22, FOV 26) follows the player; the opening shows the whole slab and
  glides in (any key or click skips). Buildings that hide the player, the torch target or a found person fade out.
- Controls: WASD / arrows walk (screen-relative), the mouse aims the torch, holding the left button walks to the
  pointer (touch the same), Space / F torch on / off.
- Darkness is real light: low moon and ambient, warm practicals (camp fires, tents, the bakery oven, work lights,
  beacons) and the torch (shadowed spot: walls cut it). Gameplay "seen" = torch cone with a clear line of sight
  (`FenerMap` solids >= 2.2 m block it) or the 2.4 m circle around you.
- Time 3:30. Battery drains while the torch is on (about 80 s); two spare batteries lie in the map.
- Finding someone (the light reaches their face): a heartbeat, a short slow motion, a warm light on the face.

## People (`data/skins/kahramanmaras_fener.tres`, `FenerPerson.Kind`)

| Person | Kind | Calls | Needs |
|---|---|---|---|
| Mom, Elif (sister) | LOST | whistle | found -> follows |
| Grandpa | SLOW | whistle | follows, everyone walks slower |
| Mrs. Ayse | TRAPPED | taps | under rubble: do not dig, report her to a rescue crew (NW crew or the AFAD tent) |
| Mr. Hasan | INJURED | "help!" | first aid kit (pharmacy or the crew), then follows slowly |
| Little Can | COLD | "so cold..." | blanket, then follows |

Followers are safe once you walk into the assembly area with them. Score = safe + reported, of 6.
Spots are random per run from `FenerMap.SPOTS` (each group in several regions).

## Map (`scripts/fener_map.gd`, 112 x 80 m)

Four regions around a crossroads: collapsed apartments with the rescue crew (NW), market street (NE), old houses (SW),
tent camp with the assembly area (SE). A toppled block lies across the north cross street, a fallen pole across the
south one. Top-down check: `godot --headless --path . -s res://tools/fener_map_png.gd` -> `export/shots/fener_map.png`.

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

`Game.finish_minigame(saved, 6, extra)`, extra = `{injuries, battery, time_left, aftershocks_dodged, found}`.

## Audio hooks (Sude wires the files)

`sound_event(kind, index, pos)` on the Fener node (`pan_of(pos)`, `volume_of(pos)` for stereo / distance):

| kind | cue | notes |
|---|---|---|
| step | FN2 | every 0.7 m walked |
| lamp_on / lamp_off | FN3 | 0-1 s on, 2-3 s off |
| battery_low, battery_dead | FN4 | |
| whistle | FN5 | index = person, from `pos` |
| tap, call, cry | (new) | trapped tapping, injured "help", cold child |
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

- People: placeholder art pilot citizens. Swap per person (`FenerPerson.figure`, `figure_scale`) or the player /
  rescuers (`FenerSkin.player_scene`, `rescuer_scene`). Origin at the feet, front +Z, about 1.75 m.
- Set pieces: `FenerMap.PLACES` (model, x, z, yaw); solids from `FenerMap.FOOT`. Practical lights per model:
  `LIGHTS` in `scenes/minigames/fener/fener_world.gd`.
- Slab body: `tools/models/kahramanmaras/fener_hood_slab.py`; pickups: `fener_items.py`.

## Tools

- Tests: `godot --headless --path . -s res://tests/test_fener.gd` (bot plays 4 full runs, every mechanic).
- Frames: `godot --path . -s res://tools/fener_shots.gd` -> `export/shots/fener_*.png`.
- Frame cost: `godot --path . -s res://tools/perf.gd -- --only=fener`.
