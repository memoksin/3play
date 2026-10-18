# Spec: Connect minigame, Indian Ocean (final plan)

Mechanic: **Connect** (rotate pipe tiles to link a source to targets before the timer ends). Skin: Indian Ocean tsunami, 26 Dec 2004. Role: State.
Status: final plan from burcubaran22 (replaces the sensor and siren version). Items marked `VERIFY` need a source check before they reach the result card.

## Story beat

The player is the head of state on a coast that is about to be hit. Water will come from the ocean on the left. The player must save the bay communities from being flooded by sending the incoming water into **underground pipelines** that end in **safe basins**. Each basin protects one community. In 2004 nothing like this existed.

## What the player sees (one screen, two views, both from the side)

**Top half: the bay (side view).** Ocean on the left, beach, then 4 communities (villages) along the bay to the right. The sea level rises during the countdown. At the end the tsunami wave comes in from the left.
Reference art: the first coast sprite (`assets/sprites/indian_ocean/coast_bg.png` at commit `4b37a35`, side view, ocean left, village right).

**Bottom half: underground (cross section, side view).** A grid of pipe tiles under the bay. Each of the **4 pipelines** starts at an **inlet** on the left (water comes in from the ocean) and ends at a **basin** on the right, under one community. Basin 1 belongs to community 1, and so on.

Prompt (one line, `tr()` key): "Send the water into the basins before the wave hits."

## Controls

Click a tile to rotate it 90 degrees clockwise. Mouse only. Rotation is instant (a 0.1 s tween is fine).

**Pairing rule.** A line is correct only when it reaches its own basin: inlet i (from the top) must end in basin i. A line that ends in another basin is wrong: no success sound, no glint, not saved, and at the hit its water stops at the last pipe and spills like an open line. Nothing is ever locked: correct lines can still be turned (that breaks them). Each time a line becomes correct it plays the success sound (`locked` sound_event, C10) and a short gold glint (`LOCK_FLASH`); the same line does not repeat either within 1 s (`LOCK_REPEAT`). **Rush:** when all 4 lines are correct the clock drops to 5 s (only if more is left); it starts only then, and once started it never lengthens, even if the player breaks a line afterwards.

## Grid and tiles

**7 columns x 6 rows**, 16 px tiles (112x96 logical px).

| Tile | Open sides (unrotated) | Rotates | Count |
|---|---|---|---|
| Straight | E-W | yes | 12 |
| Corner | S-E | yes | 16 |
| Inlet (ocean side) | E | no (fixed) | 4 |
| Basin (target) | W | no (fixed) | 4 |
| Rock / soil | none | no (fixed) | 6 |

A pipe tile is **filled** when connected through matching open sides to an inlet. Filled pipes show water, other pipes stay empty. The player sees the result live once the water flows (see Timer).

## Level layout (one fixed level)

Solved state. `I` inlet, `B` basin (B1 to B4 top to bottom), `#` rock, pipes use box characters.

```
    c0 c1 c2 c3 c4 c5 c6
r0  I  ┐  ┌  ─  ─  ─  B1
r1  #  └  ┘  #  ┌  ┐  #
r2  I  ─  ─  ─  ┘  └  B2
r3  I  ┐  ┌  ─  ─  ─  B3
r4  #  └  ┘  #  ┌  ┐  #
r5  I  ─  ─  ─  ┘  └  B4
```

Each line is separate: water from an inlet only reaches its own basin. Verified with a script: every inlet reaches exactly its own basin through 9 tiles, no cross connections.
The shipped level starts with every pipe tile rotated randomly. The **seed is fixed** so every player sees the same start. Check it is not already solved and needs at least 10 clicks.

## Timer and what happens

- **60 s** total, tunable in the disaster `.tres`. The sea level in the top view rises during the 60 s. The bar or water mark turns red in the last 15 s.
- The player rotates tiles during the 60 s. Pipes stay empty while the player works.
- At 60 s the **tsunami hits**. Water pours into the 4 inlets and flows along the pipelines.
- A **correct line** carries the water to its own basin. The basin fills.
- An **incomplete or wrong line** stops at the break (for a wrong basin: at the last pipe before it) and the water spills out.
- Only when every line is complete does the town stay dry. One open line and the wave floods the **whole town** (the picture); the score still counts the completed lines.
- After the flow, the wave drains back to the ocean (short animation), then the result card.

## Score: how X/Y is computed

- `Y = 4` (one line, one basin, one community each).
- `X` = number of correct lines (each inlet in its own basin) at the moment the wave hits. A line in the wrong basin does not count.
- Shown as "X/4 communities saved". Example: 3 lines done, 1 not = "3/4 saved" (the town is still shown flooded; the lost community's name is red).
- No separate win or lose line.

## Result card text (draft)

- Line 1: "X/4 communities saved".
- Line 2: real fact. The 2004 tsunami (Mw 9.1) killed roughly 230,000 people in 14 countries; there was no warning system in the Indian Ocean. `VERIFY` figures and source.
- Line 3: what would have helped: a warning system. Indonesia built InaTEWS after 2004, and an Indian Ocean wide warning system followed. `VERIFY` dates and names. (Issue #17 requires the InaTEWS line.)
- Line 4 (counterfactual): "In 2004 nothing like this existed. The player did it in 60 seconds. The real cost was in lives."
- Closing line: "life has dimensions we cannot see".

## Basin and community names

Put the real names in the `.tres` so they can change without code. `VERIFY` spelling and geography.

| Line | Community |
|---|---|
| 1 | Banda Aceh |
| 2 | Sabang |
| 3 | Meulaboh |
| 4 | Lhoknga |

## Data for the `.tres` (so no code change per skin)

Grid size, timer, tile grid (type + start rotation per cell), community names, prompt key, result text keys, real-number fields with source.

## Art (2.5D, #122)

The 2D sprite art below is replaced by the 2.5D style (`docs/art/style-2.5d.md`): the coast is a world slab (`scenes/minigames/connect/connect_world.tscn`), the sea cut in section on the left, the grid in the slab's front cut, the four communities on top. It opens on the 3/4 hero view and glides into the play view, which looks square at the front cut from a little above (16° down), so the grid reads as a flat board like the 2D layout. Water: the tsunami is the sea itself, one height field in `water.gdshader` on one water body (the sea surface and its front/left sections, continued over the land), driven by `connect_wave.gd` from the hit time: the drawback pulls the sea off the beach, the swell comes in from the left cut and stands up over the reef, breaks on the beach (spray, a light lens splash, a camera kick), runs as a muddy bore over the whole town and then the sea settles, so the communities the player saved stay dry and the lost ones stay under water. Boats ride the field and are left stranded in the town, palms bend with the current. No drawn edges on any water. Pipes, basins, spills and the village floods use `fluid.gdshader`. Models: `tools/models/indian_ocean/`. How far the bore runs inland follows the result (`connect_wave.gd` reach): every line complete -> it breaks and runs up the beach only, the water goes through the pipes into the basins and the town stays dry; one line open -> the bore runs over and floods the whole town (the score and the names still show the real per-line result). A lost town does not dry out: after the peak the sea settles but the flood over the land stands still (`ts_hold`) until the result card; only a fully solved run-up runs back to the sea. Rules, timing and layout above are unchanged.

## Art needs (2D version, superseded; for sudeimete, issue #11)

- **Top view (side):** bay background (ocean left, beach, village). 4 community spots. Rising sea level and a tsunami wave. A flooded version of each community (or a water overlay).
- **Underground view (side):** soil background, rock tile.
- **Pipes:** straight and corner, two states each: empty and water-filled (2-3 frame flow loop).
- **Inlet** (open E, ocean side) and **basin** (open W): empty and filled states.
All 16 px tiles, Resurrect 64 palette.

## Open points for Burcu

- Is 60 s right? Try the layout on paper with a stopwatch.
- Confirm community names, real figures and source for the result card (17).
- Tone check: serious and respectful, no images of victims.
