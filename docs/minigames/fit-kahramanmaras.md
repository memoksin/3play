# Spec: Fit minigame, Kahramanmaras (DRAFT)

Mechanic: **Fit** (drag items into limited space before the timer ends). Skin: Kahramanmaras, Turkey, 6 Feb 2023. Role: Citizen.
Status: draft for burcubaran22 to review. Items marked `VERIFY` need a source check before they reach the result card.

## Story beat

The 04:17 quake (Mw 7.8) just hit. The player is a parent in a damaged but standing flat. It is morning, the shaking has stopped. The task looks harmless: **tidy the hallway and put things back into the cupboard.**
The player does not know a second big quake (Mw 7.5, Elbistan) hits at **13:24**. Whatever is in the cupboard is what the family will have to grab.

## What the player sees

- Fixed side view of the hallway, 320x180 logical px (see `docs/design.md` pixel rules).
- Left: pile of fallen items on the floor. Right: the **cupboard**, a grid of **6x4 tiles** (16 px each). This is the limited space.
- Top: timer bar. Family of 5 standing in the doorway (parent, grandmother, teen, child, baby).
- Prompt text (one line, `tr()` key): "Clear the hallway before they come back."
- Nothing says "emergency kit" or "earthquake prep".

## Controls

Drag an item onto the cupboard grid. It snaps to tiles, no rotation, no overlap. Drag back out to remove. Mouse only.

## Items (pile has 14, cupboard fits about 8)

Size is tiles (w x h). Prep value is hidden from the player.

| Item | Size | Hidden role |
|---|---|---|
| Water bottles | 1x2 | Needed by everyone |
| Flashlight | 1x1 | Needed by parent |
| Phone + power bank | 1x1 | Needed by parent |
| Documents folder (ID, deeds) | 2x1 | Needed by parent |
| First aid kit | 2x1 | Needed by grandmother |
| Warm blankets | 2x2 | Needed by baby |
| Winter coat + shoes | 2x2 | Needed by teen and child |
| Baby formula + diapers | 2x1 | Needed by baby |
| Medicine box (grandmother) | 1x1 | Needed by grandmother |
| Toys box | 2x2 | Decoy |
| Photo albums | 2x1 | Decoy |
| Decorative vase | 1x2 | Decoy |
| Board games | 2x1 | Decoy |
| Slippers pile | 2x1 | Decoy (looks like shoes) |

Sum of useful items is larger than 24 tiles, so the player must choose. Decoys are emotionally tempting on purpose.

## Hidden scoring at 13:24

When the timer ends, show a short cut: clock 13:24, screen shake. Then score.

1. Each family member has a **need list** (table above).
2. A member is **safe** if every item on their list is in the cupboard. Water counts for all members and is only required once.
3. Score = `safe members / 5`, shown as "X/5 safe".
4. Optional tie-break for a nicer card: a member with half their list gets "injured" in the card text, not counted as safe.

Time over before the player stops dragging = whatever is in the cupboard now counts. No penalty for empty tiles.

## Timer

**75 s** (inside the 60-90 s budget). Tunable in the disaster `.tres` file. The bar turns red in the last 15 s.

## Result card text (draft)

- Line 1: "X/5 safe" and the 13:24 time.
- Line 2: real fact. Two major quakes hit within 9 hours; many buildings that survived the first collapsed in the second. `VERIFY` numbers and source before use.
- Line 3: what would have helped: a packed emergency bag by the door, and leaving damaged buildings after the first shock.
- Closing line: "life has dimensions we cannot see".

## Data for the `.tres` (so no code change per skin)

Cupboard size, timer, family list, item list (id, size, sprite, need ids, decoy flag), prompt text key, result text keys, real-number fields with source.

## Art needs (for sudeimete, issue #10)

Hallway background, cupboard grid, 14 item sprites (16 px tiles), 5 family characters (32 px), pile on floor, 13:24 clock cut.

## Open points for Burcu

- Is "family of 5 and 14 items" the right size for 75 s? Play it on paper first.
- Confirm real figures and source for the result card (17).
- Does the story fit the tone you want (serious, respectful, no gore)?
