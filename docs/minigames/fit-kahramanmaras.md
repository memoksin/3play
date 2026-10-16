# Fit minigame: Kahramanmaras (Citizen)

Mechanic: Fit (`minigames/fit`). Design: `docs/design.md`. Issue #15.

Approved prototype (HTML, reference for feel + numbers): https://claude.ai/artifact/TjbftKKFP1PgAMNf92BFWf

## Real event

- 6 Feb 2023, 04:17: Mw 7.8 Pazarcik quake.
- 13:24 same day: Mw 7.7 Elbistan quake, ~9 h later.
- Snow, below zero. Many people went back into damaged buildings for warmth or belongings, and died in the second quake.
- Lesson: after a big quake, stay out of damaged buildings. A second big quake can come.

## What the player sees

- Time: morning after the 04:17 quake. Place: in front of a cracked apartment block, snow.
- Player is a family member. Neighbors and family stand around.
- Task text (the harmless framing): "Keep everyone warm and comfortable until help arrives."
- Nothing says "second quake". The real goal is hidden.

## Zones

| Zone | Slots | Warm |
|---|---|---|
| Building (cracked) | unlimited | yes |
| Car | 4 | yes |
| Tent / open area | 6 | only with a stove, or 2+ blankets inside |

## Items

| Item | Count | Slots each | Role |
|---|---|---|---|
| Person | 8 | 1 | scored |
| Stove | 1 | 2 | warms tent |
| Blanket | 3 | 1 | 2 in tent = warm |
| Water | 1 | 1 | distractor (Tier 1) |
| Medicine | 1 | 1 | distractor (Tier 1) |

- Start: everything is in the Building. Doing nothing = everyone stays inside.
- Drag any item between any zones, back into the Building too.
- Drop on a full zone = rejected, item snaps back.
- 8/8 warm is possible: Car 4 people; Tent 4 people + 2 blankets (or 4 people + stove).

## Timer

- 75 s real time.
- HUD clock runs 05:00 -> 13:24 (~400x). No countdown bar.
- Aftershock hints at ~25 s and ~50 s: 0.5 s screen shake, building crack grows, text "The building creaks...". Nothing is lost.
- At 13:24: Elbistan quake hits without warning. Building collapses.

## Scoring at 13:24

- Person in Building = not saved.
- Person outside = saved (counts in X). Y = 8.
- Person outside in a cold zone = still saved, but counted as "N people left in the cold".
- Result card: "X/8 safe", "N people left in the cold" (if N > 0), real-event fact (second quake 9 h later), one line: never go back into a damaged building.
- Tier 1: result card also gets one line warning that a stove in a closed car/tent can cause CO poisoning.

## Tier 2

- CO rule: stove in Car = everyone in Car not saved.
- Water/medicine get a use.
- Grid shapes instead of slot counts (only if time).

## Data (`.tres` skin)

Zones (name, slots, warm rule), items (name, count, slots, sprite), start zone, clock start/end, timer seconds, aftershock times, result texts. Solar flare reuses the same shape with seats.
