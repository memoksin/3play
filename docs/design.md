# 3play: Jam Design (48h)

Theme: disaster awareness. Engine: Godot. Source of truth for the agreed design.

Jam: Civil Game Jam 2026 (ODTÜ KALTEV). Deadline: Sun 18 Oct 2026, 18:00. AI assets fully allowed.

Hour 0 = theme reveal, Fri 16 Oct 18:00. Rules: `CIVIL_GAME_JAM_Kural_Kitapcigi_v09.pdf` on https://game.ktimo.com.tr/kurallar

| Checkpoint | Time |
|---|---|
| Tier 1 done (hour 24) | Sat 18:00 |
| Feature freeze, polish only | Sun 10:00 |
| Submission phase starts | Sun 14:00 |
| Deadline (upload must start on server) | Sun 18:00 |

## Submission (rules 3-6)

- Platform: Windows build (ZIP). No web build. Test the exe on a real Windows PC before upload.
- Video: max 1 min MP4, mandatory (no receipt without it).
- Public repo link. Repo must stay public (private = disqualified). Build must match repo source.
- Run instructions: platform, how to start, controls, known issues.
- Declarations, 5 categories each (visual, audio, code, text, other): ready-made assets (source, author, link, license, use) and AI (tool, purpose, where used). Missing/wrong = disqualified. Log everything in `assets/CREDITS.md` as we go.
- Presentation: 3 min incl. video, jury plays during it, no Q&A.
- Judging: playability 25, theme 25, creativity 20, audio-visual 15, technical 15.

## Team

| Member | Area |
|---|---|
| memoksin | Core code: flow, `Game` autoload, globe, Fit + Connect mechanics, builds |
| sudeimete | Sprites and characters; diorama scene (small code) |
| iremaltunsgt | UI design; role select, HUD timer, result card scenes (small code) |
| burcubaran22 | Cloud session only, no game runs: game design specs, text content, asset hunt, credits/AI log, video script, pitch |

Tasks: GitHub Issues, label `role:*`.

## Flow (one run = one disaster = one minigame, max 3 min from globe spin to minigame end)

1. Player picks **State** or **Citizen**.
2. Globe spins (4D: time) and sends the player to one disaster of that role:
   - State: Indian Ocean tsunami or solar flare. Solar flare = globe glitches and jumps to year 3000+.
   - Citizen: Black Saturday or Kahramanmaras.
3. Pick rule: first run random, then alternate per role. Stored in `user://` (IndexedDB on web), so a replay always shows the other disaster. Per browser only; spread across judges is ~50/50, no server.
4. 3D diorama intro (camera orbit, place, year, 2 lines of context), then 2D minigame, then result card.
5. Closing line on the result card: "life has dimensions we cannot see".

Dimensions: globe = 4D, diorama = 3D, minigame = 2D.

## Time budget

| Part | Time |
|---|---|
| Globe spin + zoom to country | 15-20 s |
| Diorama intro | 10 s |
| Minigame | 60-90 s |
| Result card (score, one real fact, what would have helped) | 20-30 s |

## Disasters

| Disaster | Place, year | Role | Mechanic | Minigame (details TBD) |
|---|---|---|---|---|
| Wildfire | Black Saturday, Victoria, Australia, 7 Feb 2009 | Citizen | Reaction | Adult tone, played during the fire. Player defends the house. Near the end an escape chance appears. Escape = win. Miss it = card says the right move was to leave hours earlier ("stay or go" lesson). |
| Earthquake | Kahramanmaras, Turkey, 6 Feb 2023 | Citizen | Fit | Played after the 04:17 quake. Looks like harmless tidying; really prep for the 13:24 Elbistan quake, which the player does not expect. Prep is scored when it hits. |
| Tsunami | Indian Ocean, Indonesia, 26 Dec 2004 | State | Connect | Head of state builds a Japan-style warning system as a pipe puzzle (rotate tiles to connect sensor to sirens). Time limit; over time = fail. Counterfactual: InaTEWS was built after 2004; result card says so. |
| Solar flare | Year 3000+ | State | Fit (skin) | News: flare hits Earth in 8 min (fast countdown). Pick a crew for limited seats to save humanity. |

## Scope rule: 3 mechanics, skins are data + art

| Mechanic | Verb | Skins |
|---|---|---|
| Fit | drag items into limited space/budget before timer ends | Kahramanmaras, solar flare |
| Reaction | click/act on appearing targets in time | Black Saturday |
| Connect | rotate pipe tiles to link source to targets before timer ends | Indian Ocean |

One scene per mechanic. A new disaster = new data + art, not new code.

## Decisions

- Historical events included. One disaster per country.
- Style: low-poly 3D (globe, diorama, Kenney CC0) + pixel art 2D (minigames, `sprite` skill).
- Globe: real 3D `SphereMesh` + equirectangular earth texture (NASA, public domain). Camera tweens to target country.
- Score: people saved, "X/Y safe". Result card compares it with the real event's numbers.
- Language: English first. Turkish is Tier 2. All player-facing text goes through `tr()` with keys in `locale/strings.csv` from day one, so TR = one CSV column.
- Scenes: `main` (role select), `globe`, `diorama`, `minigames/fit`, `minigames/connect`, `result`. One owner per scene (`.tscn` merges conflict).
- Shared state: `Game` autoload (role, disaster, score). No other singletons.
- Disaster data: one `.tres` Resource per disaster (place, year, intro lines, real numbers + source, result text, minigame skin data). Content without code.
- Pixel art: `sprite` skill. 16 px tiles, 32 px characters, exported 4x nearest. 1 logical px = 4 screen px, minigame world 320x180 logical = 1280x720. One palette: Resurrect 64 (Lospec). Fallback: hand drawn, same palette and grid.
- Texture filter: project default Nearest.

## Tiers

- **Tier 1 (by hour 24):** role select, globe, Kahramanmaras (Fit), Indian Ocean (Connect), result card, closing line. Until Tier 2 lands, each role always gets its Tier 1 disaster.
- **Tier 2:** solar flare (Fit skin + globe glitch), then Black Saturday (Reaction), pick rotation.
- **Tier 3 (cut):** 3D Black Saturday variant, settings, extra audio, save/load.

## Open questions

- Later: game name (by Sat night), font, audio, result card sources, CI export to itch.io.
