# Spec: Connect minigame, Indian Ocean (DRAFT)

Mechanic: **Connect** (rotate pipe tiles to link a source to targets before the timer ends). Water version: the pipes carry real water. Skin: Indian Ocean tsunami, 26 Dec 2004. Role: State.
**ON HOLD: do not code #8 yet.** burcubaran22 is revising this spec with sudeimete (water pipes, see #38). Wait until this banner is removed.
Status: draft for burcubaran22 to review. Items marked `VERIFY` need a source check before they reach the result card.

## Story beat

The player is the head of state on a coast that is about to be hit. The wave water pours in at the sea inlet. The player builds channels (pipes) that carry the water away from the towns into **safe basins**, before the wave arrives. Each basin that receives water means one community protected. In 2004 no such system existed in the Indian Ocean, and the player builds it in 60 seconds.

## What the player sees

- Top-down grid, **7 columns x 5 rows**, 16 px tiles (112x80 logical px, centred in the 320x180 world).
- Left: the **sea inlet**, the water source. Edges: **4 safe basins**, each with a town name.
- Pipes start dark and empty. When a pipe is connected to the inlet, **water fills it** (animated, flows tile by tile). Unconnected pipes stay empty.
- A wave strip along the right edge slowly moves in. It is the timer, no number needed. A small countdown number is optional.
- Prompt (one line, `tr()` key): "Channel the water into every safe basin before the wave arrives."

## Controls

Click a tile to rotate it 90 degrees clockwise. Mouse only. Rotation is instant, no animation required (a 0.1 s tween is fine).

## Tile types

| Tile | Open sides (unrotated) | Rotates | Count in level |
|---|---|---|---|
| Straight | E-W | yes | 13 |
| Corner | S-E | yes | 1 |
| T | N-E-W | yes | 1 |
| Cross | N-E-S-W | no need (same in all rotations) | 1 |
| Sea inlet (source) | E | no (fixed) | 1 |
| Safe basin (target) | one side facing the grid | no (fixed) | 4 |
| Rock | none | no (fixed, blocks) | 12 |

A pipe tile is **filled** when it is connected through matching open sides to the sea inlet. Filled pipes show water, other pipes stay empty. This gives constant feedback, no hidden rules. A basin is **reached** when a filled pipe touches its open side.

## Level layout (one fixed level for the jam)

Solved state. `#` rock, letters are safe basins, `S` is the sea inlet, pipes use box characters.

```
   c0 c1 c2 c3 c4 c5 c6
r0  #  #  ┌  ─  ─  ─  A
r1  #  #  │  #  #  #  #
r2  S  ─  ┼  ─  ─  ─  C
r3  #  #  │  #  #  #  #
r4  D  ─  ┴  ─  ─  ─  B
```

The shipped level starts with every pipe tile rotated randomly, but the **seed is fixed** so every player sees the same start. Check it is not already solved and needs at least 8 clicks.
Verified: the solved layout connects the inlet to all 4 basins (21 tiles reached: 16 pipes, 1 inlet, 4 basins).

Basin towns (west to east along the path, `VERIFY` spelling and order for the geography):

| Basin | Town |
|---|---|
| A | Banda Aceh |
| B | Meulaboh |
| C | Sabang |
| D | Lhoknga |

Put the real names in the `.tres` so they can change without code.

## Timer and fail rule

- **60 s**, inside the 60-90 s budget. Tunable in the disaster `.tres`.
- The wave strip reaches the grid at 60 s. The bar turns red in the last 15 s.
- **Win:** all 4 basins reached before the timer ends. The wave loses force and the water drains into the basins.
- **Fail:** time runs out with any basin unreached. The wave hits, screen goes white.

## Score: how X/Y is computed

- `Y = 4` (number of basins = number of coastal communities).
- `X` = basins reached **at the moment the timer ends** (or at win).
- Shown as "X/4 communities protected".
- Partial credit shows even on fail, so a fail still has a number on the card.

## Result card text (draft)

- Line 1: "X/4 communities protected".
- Line 2: real fact. The 2004 tsunami (Mw 9.1) killed roughly 230,000 people in 14 countries; there was no warning system in the Indian Ocean. `VERIFY` figures and source.
- Line 3: what would have helped: a warning system and prepared coasts. Indonesia built InaTEWS after 2004, and an Indian Ocean wide warning system followed. `VERIFY` dates and names. (Issue #17 requires the InaTEWS line.)
- Line 4 (counterfactual): "In 2004 nothing like this existed. The player did it in 60 seconds. The real cost was in lives."
- Closing line: "life has dimensions we cannot see".

## Data for the `.tres` (so no code change per skin)

Grid size, timer, tile grid (type + start rotation per cell), basin town names, prompt key, result text keys, real-number fields with source.

## Art needs (for sudeimete, issue #11)

Pipe tiles (straight, corner, T, cross) in two states: empty and water-filled (2-3 frame flow animation is enough), **sea inlet** (replaces the sensor buoy), **4 safe basin sprites** (replace the sirens; a basin that is reached shows water filling it), rock tile, wave strip, coast map background. All 16 px tiles, Resurrect 64 palette.

## Open points for Burcu

- Is one fixed level enough, or do we want an easier first level? Recommendation: one level only, jam scope.
- Is 60 s right? Try the layout on paper with a stopwatch.
- Confirm town names, real figures and source for the result card (17).
- Tone check: serious and respectful, no images of victims.
