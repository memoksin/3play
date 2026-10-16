# 3play: Jam Design (48h)

Theme: disaster awareness. Engine: Godot. Source of truth for the agreed design.

## Flow (max 3 min from globe spin to end of minigame)

1. Player picks **State** or **Citizen**.
2. Globe spins (4D: time).
3. Disaster + country assigned. Predetermined table, but the player thinks it is random.
4. Citizen gets one of: storm, flood, earthquake.
5. State gets one of: solar flare, tsunami, wildfire.
6. 3D diorama intro (camera orbit, place, year, 2 lines of context), then 2D minigame, then result card.
7. Closing line on the last result card: "life has dimensions we cannot see".

Dimensions: globe = 4D, diorama = 3D, minigame = 2D.

## Time budget

| Part | Time |
|---|---|
| Globe spin + zoom to country | 15-20 s |
| Diorama intro | 10 s |
| Minigame | 60-90 s |
| Result card (score, one real fact, what would have helped) | 20-30 s |

## Scope rule: 3 mechanics x 2 skins = 6 minigames

| Mechanic | Verb | Citizen skin | State skin |
|---|---|---|---|
| Reaction | click/dodge appearing targets in time | Earthquake: falling objects, drop-cover-hold | Wildfire: dispatch crews to flare-ups |
| Fit | drag items into limited space before timer ends | Storm: prep home, fill go-bag | Solar flare: protect grid/satellites on a budget |
| Route | drag people onto the right path | Flood: family route to high ground | Tsunami: route population to safe zones |

One scene per mechanic. Skins are data + art swaps, not new code.

## Disaster table (proposal, not final)

| Disaster | Country | Real event |
|---|---|---|
| Earthquake | Turkey | Golcuk 1999 |
| Flood | Pakistan | 2022 |
| Storm | Philippines | Haiyan 2013 |
| Tsunami | Japan | Tohoku 2011 |
| Wildfire | Australia | 2019-20 |
| Solar flare | Canada (Quebec) | 1989 blackout |

## Tiers

- **Tier 1 (by hour 24):** role select, globe, Reaction mechanic with both skins, result card, closing line.
- **Tier 2:** Fit, then Route, each with both skins.
- **Tier 3 (cut):** globe glitch easter egg, settings, extra audio, save/load.

## Open questions

- Confirm disaster/country table.
- Team size and roles.
- Does the jam allow AI-generated art/audio? Until known: Kenney CC0 + hand drawing + Freesound, all logged in `assets/CREDITS.md`.
- Move repo out of OneDrive (git + Godot `.godot` cache conflict with sync).
