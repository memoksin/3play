# Audio tracking

Owner: burcubaran22 (issue #18). One table per game part. Fill a row when a sound is chosen.
Only CC0 or jam-safe licenses. When a file enters the repo, add it to `assets/CREDITS.md` the same moment.

Status: `todo` (not chosen), `chosen` (found, not in repo), `in repo` (added and credited).

## How to add a chosen sound to the repo

For whoever has the game on their computer (memoksin or sudeimete).

1. Open the link in the table. Freesound needs a free account to download.
2. Check the license line on the page says Creative Commons 0 (or Public Domain). If not, stop and tell burcubaran22.
3. Download the file. For the Dark Sci-Fi Audio Pack (OpenGameArt) take only `Title.mp3`.
4. Trim it if the Notes column says so (G1 about seconds 4 to 6, G4 first 1 s). Keep the original name plus a suffix, for example `guitar_swell_trim.ogg`.
5. Put it in `assets/audio/<part>/` (proposed: `globe`, `menu`). No audio folder exists yet, so the first person to add one decides the layout.
6. Run `godot --headless --path . --import` so Godot picks the file up.
7. Add a row to `assets/CREDITS.md` (name, author, link, license, where used), then set Status to `in repo` in this table.

## Globe

| # | Sound | Plays when | File name | Author | Link | License | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| G1 | Globe appear | The globe fades in slowly at scene start | Guitar swell 1.wav | Sub-d | https://freesound.org/people/Sub-d/sounds/47021/ | CC0 | chosen | Use only about seconds 4 to 6 of the file. Trim by ear. |
| G2 | Globe spin ambience | The player rotates the globe by hand | Spaceship Ambience | nick121087 | https://freesound.org/people/nick121087/sounds/234316/ | CC0 | chosen | Loop. Starts the moment the player starts rotating the globe. |
| G3 | Coordinate typing | Coordinates are typed out letter by letter | Computer keyboard typing snippet mono [loop] | cabled_mess | https://freesound.org/people/cabled_mess/sounds/361639/ | CC0 | chosen | Needs the typing text effect from issue #66 (start and end signals). |
| G4 | Target lock | The lock reticle closes on the target | Target Lock 150 Beep | alphatone | https://freesound.org/people/alphatone/sounds/561771/ | CC0 | chosen | Use only the first 1 s of the file, matched to the lock animation. |
| G5 | Zoom to country | Camera zooms in on the country | Whoosh.wav | crackles04 | https://freesound.org/people/crackles04/sounds/369698/ | CC0 | chosen | |
| G6 | Time counter | Clock or year counter runs while time advances | | | | | no sound | Test it silent first. If it feels empty, add a short digital tick later. |
| G7 | Glitch and jump to the future | Globe glitches and jumps to year 3000+ (Tier 2) | Glitch Corruption | dotY21 | https://freesound.org/people/dotY21/sounds/348585/ | CC0 | chosen | Tier 2. |

### Still to do for the globe

- Download the chosen files from Freesound (needs a free account). Someone with the game on their computer adds them to the repo.
- Trim G1 (about seconds 4 to 6) and G4 (first 1 s).
- Add every file to `assets/CREDITS.md` the moment it enters the repo, then set Status to `in repo`.

## Main menu

| # | Sound | Plays when | File name | Author | Link | License | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| M1 | Menu music | Loop while the role select screen is open | Title.mp3 (from Dark Sci-Fi Audio Pack) | SRG774 | https://opengameart.org/content/dark-sci-fi-audio-pack | CC0 | chosen | Cold and mysterious tone. The author suggests a slight crossfade when looping. The pack has 4 more tracks and 3 UI sounds, not used. |
| M2 | Button hover | The mouse is over the "State" or "Citizen" button | UI_Hover | unfa | https://freesound.org/people/unfa/sounds/565131/ | CC0 | chosen (optional) | Not sure it is needed. Test the menu without it first. About 0.12 s. |
| M3 | Button click | The player picks State or Citizen | Soft UI Button Click | Jummit | https://freesound.org/people/Jummit/sounds/528561/ | CC0 | chosen | Soft sci-fi click. |

### Still to do for the main menu

- Download the files and add them to the repo, then to `assets/CREDITS.md`, then set Status to `in repo`.
- Re-check the license line on each page when downloading.

## Diorama

The diorama is the 3D intro (about 10 s): the camera orbits a small low-poly set while a text card types out the place, year and two lines. The scene ends when the player continues (button, Space, Enter) or after about 4 s, then the minigame starts.

| # | Sound | Plays when | File name | Author | Link | License | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| D1 | Kahramanmaras ambience | Diorama of Kahramanmaras (snow, wind) | DMP013016 HEAVY SNOW STORM MS.wav | martypinso | https://freesound.org/people/martypinso/sounds/35480/ | CC0 | chosen | Use the part from about 1:47 to 2:43 (about 56 s). Needs a soft fade at the ends if it loops. |
| D2 | Indian Ocean ambience | Diorama of the Indian Ocean (waves on the shore) | Waves crashing on shore | jamgypsy | https://freesound.org/people/jamgypsy/sounds/795445/ | CC0 | chosen | Only waves (no birds, boats or people per the description). About 2 min. Also used as the base layer of C1 (Connect), see issue #95. |
| D3 | Solar flare 3026 ambience | Diorama of the solar flare scenario | Solar Storm.wav | Puniho | https://freesound.org/s/151098/ | CC0 | chosen | Space ambience. |
| D4 | Intro text typing | The intro lines type on, one after another | Computer keyboard typing snippet mono [loop] | cabled_mess | https://freesound.org/people/cabled_mess/sounds/361639/ | CC0 | chosen | Same file as G3, so all typed text in the game sounds the same. |
| D5 | Diorama to minigame transition | The diorama ends and the minigame starts | | | | | no sound | No sound for now. Open question for the whole game: do scene transitions need a sound? See below. |

### Still to do for the diorama

- Same steps as the globe: download, trim D1, add to the repo, credit in `assets/CREDITS.md`, set Status to `in repo`.

## Open question: scene transitions

Do transitions between scenes need a sound? Decide after the game runs end to end (globe to diorama, diorama to minigame, minigame to result card, result card to menu). For now no sound on any transition. Test it silent first.

## Fit minigame (Kahramanmaras; the solar flare skin shares the code)

Timeline from `scenes/minigames/fit.gd`: aftershock hints at about 25 s and 50 s (0.5 s shake plus a creak message), the big quake at 13:24 (1.6 s shake), the collapse starts 0.3 s after the hit and lasts 1.3 s, so the quake rumble and the collapse overlap.

| # | Sound | Plays when | File name | Author | Link | License | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| F1 | Ambience | Whole minigame (cold street, snow, wind) | DMP013016 HEAVY SNOW STORM MS.wav | martypinso | https://freesound.org/people/martypinso/sounds/35480/ | CC0 | chosen | Same sound as D1, so the place sounds the same in the diorama and the minigame. |
| F2 | Select a person or item | The player clicks a person or item | Game Pickup | IENBA | https://freesound.org/people/IENBA/sounds/698768/ | CC0 | chosen | Use only the first second of the file. |
| F3 | Drop into a zone | The item lands in a zone (slide of 0.18 s) | Picking up and Putting Down Object | mrh4hn | https://freesound.org/people/mrh4hn/sounds/426631/ | CC0 | chosen | Use only seconds 5 to 6 of the file. |
| F4 | Wrong item or cannot take | The zone is full, the item snaps back | Buzzer sounds (Wrong answer / Error) | Breviceps | https://freesound.org/people/Breviceps/sounds/493163/ | CC0 | chosen | The file holds several buzzers. Use only the part from about 2.3 s to 2.7 s. |
| F5 | Building creak and quake start | Aftershock hints (about 25 s and 50 s) and the start of the big quake | | | | | not found yet | No good CC0 building crack or creak found so far. Test the game without it and decide by how it plays. Looked at: ALLANZ10D (wall cracks), Jadester64 (breaking concrete), hinchinbrook (metal groan). Plays on top of F6 if found (see the mix note). |
| F6 | Big quake | 13:24, 1.6 s of violent shaking | Cracking Earthquake | uagadugu | https://freesound.org/people/uagadugu/sounds/222521/ | CC0 | chosen | About 12 s file, trim to the shaking. Idea: layer the F5 creak on top. |
| F7 | Building collapse | Right after the quake hit, 1.3 s | building collapse / demolition | greyfeather | https://freesound.org/people/greyfeather/sounds/712918/ | CC0 | chosen | About 3 s. Starts while the F6 rumble is still playing (overlap). See the transition note. |
| F8 | Clock | The HUD clock runs | | | | | undecided | Test silent first, like G6. |

### Mix note (F5 + F6)

The building creak (F5) plays together with the quake rumble (F6) when the big quake starts: two separate players started at the same moment, the creak on top of the rumble. No need to bake them into one file. At the aftershock hints (about 25 s and 50 s) the creak plays alone. Assigned to memoksin in issue #89.

### Transition note (F6 to F7)

F6 is a low, long rumble and F7 is a short, sharp impact, so they sound different. In the game they overlap on purpose: the collapse starts 0.3 s after the hit while the shake is still going. Keep the rumble under the collapse and fade it out after, instead of cutting one sound and starting the other. Match the loudness and give the join a short (about 100 to 200 ms) crossfade.

## Connect minigame (Indian Ocean)

Timeline from `scenes/minigames/connect.gd`: a calm bay until about 6 s before the hit (the ambient motion slows and fades), the wave comes into view 15 s before the hit, the tile turn lasts 0.1 s, the wave crosses the bay and breaks on the beach (1.8 s) with a 0.6 s shake, then 0.6 s later the water flows tile by tile (0.3 s per tile), basins fill (0.4 s per step), broken lines spill (0.5 s splash, 0.3 s gush), villages flood, the water drains (1.5 s), and the banner shows the score.

| # | Sound | Plays when | File name | Author | Link | License | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| C1 | Calm bay ambience | From the start until the wave arrives | Morning Birds in a Quiet Urban Garden | WhisperingEarth | https://freesound.org/people/WhisperingEarth/sounds/798842/ | CC0 | chosen | Layer on top of the D2 wave sound (jamgypsy), which starts first and keeps playing. Two players at once. Issue #95. |
| C2 | Rotate a pipe | The player clicks a pipe (0.1 s turn) | Clank1.wav | BMacZero | https://freesound.org/people/BMacZero/sounds/94127/ | CC0 | chosen | |
| C3 | Wave rising | The wave comes into view, 15 s before the hit | | | | | later | Postponed. The first candidates were rejected, needs a new search. |
| C4 | Wave hits | The wave crosses the bay and breaks on the beach, with the shake | | | | | later | Postponed. The first candidates were rejected, needs a new search. |
| C5 | Water flows through the pipes | Water flows tile by tile after the hit | Hydrophone underwater stream close pipe gurgle.wav | JavierZumer | https://freesound.org/people/JavierZumer/sounds/422660/ | CC0 | chosen | Use the part from about 0:40 onward. |
| C6 | Basin fills | The water reaches a basin and it fills | Water Echo.wav | eeriedescence | https://freesound.org/people/eeriedescence/sounds/419741/ | CC0 | chosen | Well-like echo. |
| C7 | Broken line spills | The water spills out of a broken line | Big Water Splash | qubodup | https://freesound.org/people/qubodup/sounds/442773/ | CC0 | chosen (to test) | Repeat the same splash several times, each starting before the previous ends, to build an overflow. Try it, replace the sound if it feels fake. Issue #95. |
| C8 | Village floods | The spilled water floods the village | | | | | no sound (test) | Leave empty and test the game. Add a sound only if it feels empty. |
| C9 | Water drains | The water drains back (1.5 s) | wavesound.wav | transitking | https://freesound.org/people/transitking/sounds/11505/ | CC0 | chosen | Use only the first 4 s of the file (waves wash over the rock and drain back through a crack). |
