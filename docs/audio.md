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
| G1 | Globe appear | The globe fades in slowly at scene start | Guitar swell 1.wav | Sub-d | https://freesound.org/people/Sub-d/sounds/47021/ | CC0 | in repo | Use only about seconds 4 to 6 of the file. Trim by ear. |
| G2 | Globe spin ambience | The player rotates the globe by hand | Spaceship Ambience | nick121087 | https://freesound.org/people/nick121087/sounds/234316/ | CC0 | in repo | Loop. Starts the moment the player starts rotating the globe. |
| G3 | Coordinate typing | Coordinates are typed out letter by letter | Computer keyboard typing snippet mono [loop] | cabled_mess | https://freesound.org/people/cabled_mess/sounds/361639/ | CC0 | in repo | Needs the typing text effect from issue #66 (start and end signals). |
| G4 | Target lock | The lock reticle closes on the target | Target Lock 150 Beep | alphatone | https://freesound.org/people/alphatone/sounds/561771/ | CC0 | in repo | Use only the first 1 s of the file, matched to the lock animation. |
| G5 | Zoom to country | Camera zooms in on the country | Whoosh.wav | crackles04 | https://freesound.org/people/crackles04/sounds/369698/ | CC0 | in repo | |
| G6 | Time counter | Clock or year counter runs while time advances | | | | | no sound | Test it silent first. If it feels empty, add a short digital tick later. |
| G7 | Glitch and jump to the future | Globe glitches and jumps to year 3000+ (Tier 2) | Glitch Corruption | dotY21 | https://freesound.org/people/dotY21/sounds/348585/ | CC0 | in repo | Tier 2. |
| G8 | Riser, main menu to globe | The player leaves the menu and the globe appears |  |  |  |  | keep current | No riser for now: the current transition sound (the G1 swell, which plays when the globe appears) stays as it is. |
| G9 | Globe ambience | While the globe is shown (space or Earth feel) | Quasi Drone | bassimat | https://freesound.org/people/bassimat/sounds/840934/ | CC0 | chosen | About 10 min, calm evolving drone. Loop, quiet, under the G1 swell and G2 spin sound. Expected file: `globe/earth_ambience.ogg`. No water. |

### Still to do for the globe

- Download the chosen files from Freesound (needs a free account). Someone with the game on their computer adds them to the repo.
- Trim G1 (about seconds 4 to 6) and G4 (first 1 s).
- Add every file to `assets/CREDITS.md` the moment it enters the repo, then set Status to `in repo`.

## Main menu

| # | Sound | Plays when | File name | Author | Link | License | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| M1 | Menu music | Loop while the role select screen is open | Title.mp3 (from Dark Sci-Fi Audio Pack) | SRG774 | https://opengameart.org/content/dark-sci-fi-audio-pack | CC0 | in repo | Cold and mysterious tone. The author suggests a slight crossfade when looping. The pack has 4 more tracks and 3 UI sounds, not used. |
| M2 | Button hover | The mouse is over the "State" or "Citizen" button | UI_Hover | unfa | https://freesound.org/people/unfa/sounds/565131/ | CC0 | in repo (optional) | Not sure it is needed. Test the menu without it first. About 0.12 s. |
| M3 | Button click | The player picks State or Citizen | Soft UI Button Click | Jummit | https://freesound.org/people/Jummit/sounds/528561/ | CC0 | in repo | Soft sci-fi click. |
| M4 | Prompt typing | The line "Who are you when disaster strikes?" types out | Computer keyboard typing snippet mono [loop] | cabled_mess | https://freesound.org/people/cabled_mess/sounds/361639/ | CC0 | in repo (reuse of G3) | Same typing sound as everywhere else. |

### Still to do for the main menu

- Download the files and add them to the repo, then to `assets/CREDITS.md`, then set Status to `in repo`.
- Re-check the license line on each page when downloading.

## Language screen (flag select)

First screen at the first launch, with the flags. It reuses the main menu sounds.

| # | Sound | Plays when | File name | Author | Link | License | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| LS1 | Flag hover | The mouse is over a flag | UI_Hover | unfa | https://freesound.org/people/unfa/sounds/565131/ | CC0 | in repo (reuse of M2) | Same as the main menu hover. |
| LS2 | Flag click | A language is chosen | Soft UI Button Click | Jummit | https://freesound.org/people/Jummit/sounds/528561/ | CC0 | in repo (reuse of M3) | Same as the main menu click. |
| LS3 | Music | The language screen is open | | | | | no sound | The menu music (M1) starts at the main menu. To confirm. |

## Diorama

The diorama is the 3D intro (about 10 s): the camera orbits a small low-poly set while a text card types out the place, year and two lines. The scene ends when the player continues (button, Space, Enter) or after about 4 s, then the minigame starts.

| # | Sound | Plays when | File name | Author | Link | License | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| D1 | Kahramanmaras ambience | Diorama of Kahramanmaras (snow, wind) | G56-21-Winter Wind.wav | craigsmith | https://freesound.org/people/craigsmith/sounds/438876/ | CC0 | chosen | Replaces the martypinso snowstorm. Also used for FN1. Needs a soft fade at the loop ends. |
| D2 | Indian Ocean ambience | Diorama of the Indian Ocean (waves on the shore) | Waves crashing on shore | jamgypsy | https://freesound.org/people/jamgypsy/sounds/795445/ | CC0 | in repo | Only waves (no birds, boats or people per the description). About 2 min. Also used as the base layer of C1 (Connect), see issue #95. |
| D3 | Solar flare 3026 ambience | Diorama of the solar flare scenario | Solar Storm.wav | Puniho | https://freesound.org/s/151098/ | CC0 | in repo | Space ambience. |
| D4 | Intro text typing | The intro lines type on, one after another | Computer keyboard typing snippet mono [loop] | cabled_mess | https://freesound.org/people/cabled_mess/sounds/361639/ | CC0 | in repo | Same file as G3, so all typed text in the game sounds the same. |
| D5 | Diorama to minigame transition | The diorama ends and the minigame starts | | | | | no sound | No sound for now. Open question for the whole game: do scene transitions need a sound? See below. |
| D6 | Continue prompt hover | The mouse is over the "Continue" prompt | UI_Hover | unfa | https://freesound.org/people/unfa/sounds/565131/ | CC0 | in repo (reuse of M2) | A bit louder than in the menu. |

### Still to do for the diorama

- Same steps as the globe: download, trim D1, add to the repo, credit in `assets/CREDITS.md`, set Status to `in repo`.

## Open question: scene transitions

Do transitions between scenes need a sound? Decide after the game runs end to end (globe to diorama, diorama to minigame, minigame to result card, result card to menu). For now no sound on any transition. Test it silent first.

## Fit minigame (Kahramanmaras) - OBSOLETE, replaced by Fener (#123), see the Fener section

(Kept for reference until the new sections are final.)

Timeline from `scenes/minigames/fit.gd`: aftershock hints at about 25 s and 50 s (0.5 s shake plus a creak message), the big quake at 13:24 (1.6 s shake), the collapse starts 0.3 s after the hit and lasts 1.3 s, so the quake rumble and the collapse overlap.

| # | Sound | Plays when | File name | Author | Link | License | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| F1 | Ambience | Whole minigame (cold street, snow, wind) | DMP013016 HEAVY SNOW STORM MS.wav | martypinso | https://freesound.org/people/martypinso/sounds/35480/ | CC0 | in repo | Same sound as D1, so the place sounds the same in the diorama and the minigame. |
| F2 | Select a person or item | The player clicks a person or item | Game Pickup | IENBA | https://freesound.org/people/IENBA/sounds/698768/ | CC0 | in repo | Use only the first second of the file. |
| F3 | Drop into a zone | The item lands in a zone (slide of 0.18 s) | Picking up and Putting Down Object | mrh4hn | https://freesound.org/people/mrh4hn/sounds/426631/ | CC0 | in repo | Use only seconds 5 to 6 of the file. |
| F4 | Wrong item or cannot take | The zone is full, the item snaps back | Buzzer sounds (Wrong answer / Error) | Breviceps | https://freesound.org/people/Breviceps/sounds/493163/ | CC0 | in repo | The file holds several buzzers. Use only the part from about 2.3 s to 2.7 s. |
| F5 | Building creak and quake start | Aftershock hints (about 25 s and 50 s) and the start of the big quake | | | | | not found yet | No good CC0 building crack or creak found so far. Test the game without it and decide by how it plays. Looked at: ALLANZ10D (wall cracks), Jadester64 (breaking concrete), hinchinbrook (metal groan). Plays on top of F6 if found (see the mix note). |
| F6 | Big quake | 13:24, 1.6 s of violent shaking | Cracking Earthquake | uagadugu | https://freesound.org/people/uagadugu/sounds/222521/ | CC0 | in repo | About 12 s file, trim to the shaking. Idea: layer the F5 creak on top. |
| F7 | Building collapse | Right after the quake hit, 1.3 s | building collapse / demolition | greyfeather | https://freesound.org/people/greyfeather/sounds/712918/ | CC0 | in repo | About 3 s. Starts while the F6 rumble is still playing (overlap). See the transition note. |
| F8 | Clock | The HUD clock runs | | | | | undecided | Test silent first, like G6. |

### Mix note (F5 + F6)

The building creak (F5) plays together with the quake rumble (F6) when the big quake starts: two separate players started at the same moment, the creak on top of the rumble. No need to bake them into one file. At the aftershock hints (about 25 s and 50 s) the creak plays alone. Assigned to memoksin in issue #89.

### Transition note (F6 to F7)

F6 is a low, long rumble and F7 is a short, sharp impact, so they sound different. In the game they overlap on purpose: the collapse starts 0.3 s after the hit while the shake is still going. Keep the rumble under the collapse and fade it out after, instead of cutting one sound and starting the other. Match the loudness and give the join a short (about 100 to 200 ms) crossfade.

## Connect minigame (Indian Ocean)

Timeline from `scenes/minigames/connect.gd`: a calm bay until about 6 s before the hit (the ambient motion slows and fades), the wave comes into view 15 s before the hit, the tile turn lasts 0.1 s, the wave crosses the bay and breaks on the beach (1.8 s) with a 0.6 s shake, then 0.6 s later the water flows tile by tile (0.3 s per tile), basins fill (0.4 s per step), broken lines spill (0.5 s splash, 0.3 s gush), villages flood, the water drains (1.5 s), and the banner shows the score.

| # | Sound | Plays when | File name | Author | Link | License | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| C1 | Calm bay ambience | From the start until the wave arrives | Morning Birds in a Quiet Urban Garden | WhisperingEarth | https://freesound.org/people/WhisperingEarth/sounds/798842/ | CC0 | in repo | Layer on top of the D2 wave sound (jamgypsy), which starts first and keeps playing. Two players at once. Issue #95. |
| C2 | Rotate a pipe | The player clicks a pipe (0.1 s turn) | Clank1.wav | BMacZero | https://freesound.org/people/BMacZero/sounds/94127/ | CC0 | in repo | |
| C3 | Wave rising | The wave comes into view, 15 s before the hit | Rumble · fade in 10s | unfa | https://freesound.org/people/unfa/sounds/258341/ | CC0 (verify) | chosen | Low rumble that fades in over 10 s: the wave approaching. Starts when the wave comes into view. |
| C4 | Wave hits | The wave crosses the bay and breaks on the beach, with the shake | Ocean Waves.wav | Noted451 | https://freesound.org/people/Noted451/sounds/531015/ | CC0 (verify) | chosen | Use seconds 32 to 37 of the file (the big wave). |
| C5 | Water flows through the pipes | Water flows tile by tile after the hit | Hydrophone underwater stream close pipe gurgle.wav | JavierZumer | https://freesound.org/people/JavierZumer/sounds/422660/ | CC0 | in repo | Use the part from about 0:40 onward. |
| C6 | Basin fills | The water reaches a basin and it fills | Water Echo.wav | eeriedescence | https://freesound.org/people/eeriedescence/sounds/419741/ | CC0 | in repo | Well-like echo. |
| C7 | Broken line spills | The water spills out of a broken line | Big Water Splash | qubodup | https://freesound.org/people/qubodup/sounds/442773/ | CC0 | in repo (to test) | Repeat the same splash several times, each starting before the previous ends, to build an overflow. Try it, replace the sound if it feels fake. Issue #95. |
| C8 | Village floods | The spilled water floods the village | | | | | no sound (test) | Leave empty and test the game. Add a sound only if it feels empty. |
| C9 | Water drains | The water drains back (1.5 s) | wavesound.wav | transitking | https://freesound.org/people/transitking/sounds/11505/ | CC0 | in repo | Use only the first 4 s of the file (waves wash over the rock and drain back through a crack). |
| C10 | Pipeline locks | A pipeline is correct and locks (no more rotation) | Short Success Sound Glockenspiel Treasure Video Game | FunWithSound | https://freesound.org/people/FunWithSound/sounds/456965/ | CC0 | chosen (same as FN7) | The shared success sound (FN7, FR6, BM4, C10). Memoksin added a `locked` sound_event kind in audio.gd (#162); Sude adds the cue. |

## Result card

What happens on the card (`scenes/result.gd`): the card fades in, the score lands 0.3 s later, the buttons (Play again, Main menu) come at 0.6 s, and the closing line types on last.

| # | Sound | Plays when | File name | Author | Link | License | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| R1 | Card appears | The card fades in | Guitar swell 1.wav | Sub-d | https://freesound.org/people/Sub-d/sounds/47021/ | CC0 | chosen (reuse of G1) | Same soft swell as the globe appearing (about seconds 4 to 6). |
| R2 | Score lands | The score appears | | | | | no sound | Not needed. |
| R3 | Closing line typing | The closing line types on | Computer keyboard typing snippet mono [loop] | cabled_mess | https://freesound.org/people/cabled_mess/sounds/361639/ | CC0 | in repo | Same as G3 and D4. Needs typing start and finish signals, issue #99. |
| R4 | Button hover and click | Play again and Main menu | UI_Hover (unfa) and Soft UI Button Click (Jummit) | unfa, Jummit | see M2 and M3 | CC0 | in repo | Same sounds as the main menu (M2, M3). |
| R5 | Result music | While the card is open, calm and thoughtful | Title.mp3 (from Dark Sci-Fi Audio Pack) | SRG774 | https://opengameart.org/content/dark-sci-fi-audio-pack | CC0 | in repo (may change) | Same as the main menu music (M1): the game starts and ends with the same music. May change after listening in the game; then try another track from the same pack (Sector, Airy) or another calm track. |

### Typed text everywhere (G3, D4, R3)

All text that types on letter by letter uses the same keyboard typing sound, started with the first letter and stopped with the last one, like the globe coordinates. Each typing effect needs start and finish signals: diorama intro text and the result closing line. Tracked in issue #99 (assigned to iremaltunsgt, who owns intro text and the result card; memoksin did the globe in #66).

## Solar flare (Fit minigame, year 3026) - OBSOLETE, replaced by Isin Agi (#124), see the beam network section

(Kept for reference until the new sections are final.)

Same code as the Kahramanmaras Fit, with a flare ending instead of the quake. From `data/skins/solar_flare_fit.tres`: 75 s timer, radio messages at 20 s, 42 s and 60 s (`SF_FIT_RADIO_1..3`), the flare hits at the end (white flash, `SF_FIT_IMPACT`, "14:00 - flare impact"), the HUD clock runs from 13:52 to 14:00. No shake and no collapse in this skin.

| # | Sound | Plays when | File name | Author | Link | License | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| S1 | Ambience | Whole minigame | Solar Storm.wav | Puniho | https://freesound.org/s/151098/ | CC0 | in repo (reuse of D3) | Same sound as the solar flare diorama. |
| S2 | Select a person or item | The player clicks a person or item | Game Pickup | IENBA | https://freesound.org/people/IENBA/sounds/698768/ | CC0 | in repo (reuse of F2) | First second of the file only. |
| S3 | Drop into a zone | The item lands in a zone | Picking up and Putting Down Object | mrh4hn | https://freesound.org/people/mrh4hn/sounds/426631/ | CC0 | in repo (reuse of F3) | Seconds 5 to 6 of the file. |
| S4 | Wrong item or cannot take | The zone is full, the item snaps back | Buzzer sounds (Wrong answer / Error) | Breviceps | https://freesound.org/people/Breviceps/sounds/493163/ | CC0 | in repo (reuse of F4) | About 2.3 s to 2.7 s of the file. |
| S5a | Radio call beep | Right before a radio message, and again right after it | Walkie Talkie Beep | SoundBiterSFX | https://freesound.org/people/SoundBiterSFX/sounds/732209/ | CC0 | chosen | Plays at the start and at the end of each of the 3 radio messages (about 20 s, 42 s, 60 s). Issue #107. |
| S5b | Radio static bed | While a radio message is on screen | Radio Static | JovianSounds | https://freesound.org/people/JovianSounds/sounds/524204/ | CC0 | chosen | Quiet, under the message. Stops when the message ends. Issue #107. |
| S5c | Last call alarm | The third message ("last call, seal the doors") | Emergency alarm with reverb | Rvgerxini | https://freesound.org/people/Rvgerxini/sounds/463690/ | CC0 | chosen | Looped alarm, only for the third message, with the radio (S5a, S5b) still playing. Issue #107. |
| S6 | Flare hit | The white flash at 14:00 | | | | | later | Decide after seeing the flash in the game. |
| S7 | Clock | The HUD clock runs (13:52 to 14:00) | | | | | no sound | Test it silent first. |

### Radio message sequence (S5)

For each of the three radio messages: the call beep (S5a), then the message with the static (S5b) quietly underneath, then the same beep (S5a) again. The third message also plays the alarm (S5c) on top while the radio is still heard. Assigned to memoksin in issue #107.

## Fener (Kahramanmaras, #123)

Dark snowy street, a flashlight with a battery, a whistle that shows the direction, three family members to find and bring to the assembly point, an aftershock that hurts near buildings.

| # | Sound | Plays when | File name | Author | Link | License | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| FN1 | Snowstorm ambience | Whole minigame | G56-21-Winter Wind.wav | craigsmith | https://freesound.org/people/craigsmith/sounds/438876/ | CC0 | chosen (same as D1) | The same new snowstorm sound as D1. |
| FN2 | Footsteps | The player walks | Footsteps Dirt Gravel | PotatokingXII | https://freesound.org/people/PotatokingXII/sounds/352870/ | CC0 | chosen | Normal footsteps (not snow). About 35 s, trim to a clean stride loop. |
| FN3 | Flashlight on and off | The flashlight is turned on or off | Flashlight Clicking On and Off | deleted_user_7146007 | https://freesound.org/people/deleted_user_7146007/sounds/383659/ | CC0 | chosen | 0 to 1 s = turning on. 2 to 3 s = turning off. |
| FN4 | Battery low | The flashlight battery is running out | Electronic Timer Beeping 4X | Rudmer_Rotteveel | https://freesound.org/people/Rudmer_Rotteveel/sounds/536420/ | CC0 | chosen | The file already holds 4 beeps ("bip bip"). Play it when the battery is low. |
| FN5 | Whistle | The whistle that shows the direction | metal whistle | strongbot | https://freesound.org/people/strongbot/sounds/568995/ | CC0 | chosen | First 3 seconds of the file. |
| FN6 | Found a family member | The player reaches a family member | Game Pickup | IENBA | https://freesound.org/people/IENBA/sounds/698768/ | CC0 | chosen (reuse of F2) | First second of the file. |
| FN7 | Success | The family reaches the assembly point | Short Success Sound Glockenspiel Treasure Video Game | FunWithSound | https://freesound.org/people/FunWithSound/sounds/456965/ | CC0 | chosen | One success sound for FN7, FR6 and BM4. |
| FN8 | Aftershock | The aftershock hits | Cracking Earthquake | uagadugu | https://freesound.org/people/uagadugu/sounds/222521/ | CC0 | chosen (reuse of F6) | Trim to the shaking. |
| FN8a | Building creak | Aftershock warning and the start of the aftershock |  |  |  |  | not found | No usable building creak was found. Left empty for now, test the game without it. |
| FN9 | Hurt | The player is hurt near a building | Hurt_C_07 | cabled_mess | https://freesound.org/people/cabled_mess/sounds/350926/ | CC0 | chosen | Retro-style hurt sound, about 0.2 s. |

## Fire (Black Saturday, kangaroo farm, first person)

Spec: `docs/minigames/fire-farm.md`.

| # | Sound | Plays when | File name | Author | Link | License | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| FR1 | Fire and wind ambience | Whole minigame | digital wildfire mixed with WIND BLOWING.mp3 | vekoN + Podcapocalipsis | https://freesound.org/people/vekoN/sounds/537530/ and https://freesound.org/people/Podcapocalipsis/sounds/521696/ | CC0 (checked by Sude) | chosen | Option B approved by Burcu by ear. Wind seconds 9 to 14, 10 s seamless loop. Option A (craigsmith Large Fire Burning) dropped. |
| FR2 | Footsteps | The player walks | Footsteps Dirt Gravel | PotatokingXII | https://freesound.org/people/PotatokingXII/sounds/352870/ | CC0 | chosen | Same as FN2. Trim to a clean stride loop. |
| FR3 | Jump and landing on debris | The player jumps over the debris | Human Impact on Ground | alegemaate | https://freesound.org/people/alegemaate/sounds/364690/ | CC0 | chosen | Short clip of a person landing after a jump. |
| FR4 | Pick up the wire cutters | The player picks up the wire cutters (was the knife) | Game Pickup | IENBA | https://freesound.org/people/IENBA/sounds/698768/ | CC0 | chosen (reuse of F2) | First second of the file. A metal clank would fit the cutters better. |
| FR5 | Cut the fence (hold) | While the player holds to cut the fence ties (event `snip` is the per-tie sound below) | Sanding_a_Piece_Of_Wood.wav | CapsLok | https://freesound.org/people/CapsLok/sounds/204948/ | CC0 | chosen | Burcu: use 16 s to 19 s as a short loop while the player holds. Each tie that breaks also plays a short metal snip (FR5.2, todo). |
| FR5.2 | Snip a fence tie | Each wire tie is cut (event `snip`, 6 per fence) | Scissors Cutting Air.wav | RutgerMuller | https://freesound.org/people/RutgerMuller/sounds/51164/ | CC0 (verify) | chosen | Use only 2.8 s to 3.2 s of the file (short metal cut). No CC0 wire-cutter recording exists. |
| FR5.1 | Fence panel crashes down | The cut panel slams onto the ground (event `panel_land`, index 0), the little hop after it (index 1) | Scrap metal dropping / crashing | SamsterBirdies | https://freesound.org/people/SamsterBirdies/sounds/587443/ | CC0 (verify) | chosen | Use 2 s to 4 s of the file (index 0 crash). For the small hop (index 1) reuse a short piece of the same file. |
| FR6 | Success | A task is done (fence cut, flame out) | Short Success Sound Glockenspiel Treasure Video Game | FunWithSound | https://freesound.org/people/FunWithSound/sounds/456965/ | CC0 | chosen (same as FN7) | The same success sound as FN7 and BM4. |
| FR7.1 | Hose attached | The hose is put on the valve | Door Lock.wav | nebulasnails | https://freesound.org/people/nebulasnails/sounds/405534/ | CC0 | chosen | About 0.75 s door latch. |
| FR7.2 | Valve turn | The valve is turned | Hose Sounds | JazzyBay | https://freesound.org/people/JazzyBay/sounds/435052/ | CC0 | chosen | Use 0:58 to 1:03 of the file. |
| FR8 | Water spray | The hose sprays | Hose Sounds | JazzyBay | https://freesound.org/people/JazzyBay/sounds/435052/ | CC0 | chosen | Use 1:07 to 1:18 of the file (confirmed). |
| FR9 | Small flame | The small flame burns | fire crackling, fireplace, BBQ | AlexanderChe | https://freesound.org/people/AlexanderChe/sounds/410404/ | CC0 (checked by Sude) | chosen | Alone, no wind mix. Small wood fire, about 16 s, loop. Fades out when the flame is put out (FR10). |
| FR10 | Flame goes out | The flame is put out | | | | | decided | No separate sound: the flame sound (FR9) fades out. |
| FR11 | Kangaroos run out | 2 to 3 kangaroos run through the gap | Horse Gallop Loop.wav + Footsteps Dirt 01 | DeadxCreed + aglinder | https://freesound.org/people/DeadxCreed/sounds/322448/ and https://freesound.org/people/aglinder/sounds/264469/ | CC0 (verify both) | chosen (to test) | No kangaroo hop CC0 exists. Layer both and play the pair 2 to 3 times, each starting before the previous ends. Replace if it sounds fake. |
| FR12 | Smoke (cough, breath) | The smoke thickens | | | | | no sound | Not needed. |
| FR13 | Ending shot | The camera rises out of first person over the burning farm (event `exit`), or the dark version when time runs out (event `lose`) | FR1 mix (digital wildfire + wind), raised | vekoN + Podcapocalipsis | see FR1 | CC0 | chosen | No new file. On `exit`: raise the FR1 volume and open it up, then a held quiet before the result card. On `lose`: the same sound lowered (low-pass) and heavier. Burcu agreed. |

## Beam network (Isin Agi, solar flare 3026, #124)

Rotate satellites to route the solar beam into collectors, waves, a countdown, "X/Y cities saved".

| # | Sound | Plays when | File name | Author | Link | License | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| BM1 | Space ambience | Whole minigame | Solar Storm.wav | Puniho | https://freesound.org/s/151098/ | CC0 | chosen (reuse of D3) | |
| BM2 | Rotate a satellite | The player rotates a satellite | Servo motor | Burningmonkey | https://freesound.org/people/Burningmonkey/sounds/322021/ | CC0 | chosen | Use seconds 3 to 4 of the file. |
| BM3 | Beam | The beam runs through the satellites | Laser Beam Firing | SecureSubset | https://freesound.org/people/SecureSubset/sounds/783986/ | CC0 | chosen | About 0.75 s. Repeat it back to back so it becomes a continuous sound while the beam runs. |
| BM4 | Collector charged, city saved | A collector is charged | Short Success Sound Glockenspiel Treasure Video Game | FunWithSound | https://freesound.org/people/FunWithSound/sounds/456965/ | CC0 | chosen (same as FN7) | The same success sound as FN7 and FR6. |
| BM5 | City lost | A city is lost | power-down-01.wav | newagesoup | https://freesound.org/people/newagesoup/sounds/348249/ | CC0 | chosen | Use the part from 1 s onward. |
| BM6 | Wave warning | A wave is coming | | | | | later | Empty for now, to search later. |
| BM7 | Wave hits | The wave hits | | | | | later | Empty for now. |
| BM8 | Countdown | The countdown runs | Bomb Countdown Beeps | snakebarney | https://freesound.org/people/snakebarney/sounds/138108/ | CC0 | chosen |  |

## Pitch film (trailer, about 50 s, silent render, sounds added by the team)

Source: `tools/video/film.html` cue sheet and `tools/video/intro_stack_v2.html` (memoksin, tools/video/README.md). The renders have no audio. Times are final-film seconds (intro 8.0 s first, then the film). Language of the on-screen text is Turkish. Game clips are recorded silent, so game sounds (ambience, clicks, water) are layered from the game files.

| # | Time (s) | What happens | Sound needed | Status |
|---|---|---|---|---|
| T1 | 0 to 8 | Intro: the Stack logo in a storm | Rain loop and low wind, under the whole intro | todo |
| T2 | about 2.4 | Distant sheet lightning in the clouds | Far soft thunder | todo |
| T3 | 2.8 and 3.4 | Two close lightning strikes, the logo flickers | Two thunder cracks | todo |
| T4 | 3.9 | Final strike hits the logo (2 frames silhouette, 1 inverted) | Big thunder crack and impact, then silence for a beat | todo |
| T5 | 4.45 to 5.3 | "STACK PRESENTS" types on | Letter-by-letter type-on blips with a glitch feel | todo |
| T6 | 5.5 | Last far strike | Far thunder | todo |
| T7 | 6.05 to 7.65 | The camera pushes into the logo's eye | Riser, low and building, ends in a cut | todo |
| T8 | 7.75 | Pure black | Silence | no sound |
| T9 | 8.2, 8.5, 9.2, 9.5 | Darkness with a heartbeat glow | Heartbeat lub-dub (two beats, twice) | todo |
| T10 | 8.8 to 10.0 | A faint voice echoes: "Sesimi duyan var mı?" | The line spoken by a team member, with echo (if text-to-speech is used it must be declared as AI) | todo |
| T11 | 10.0 to 12.35 | "Hayatın göremediğimiz boyutları vardır" | Soft sting for a statement | todo |
| T12 | 12.4 | The darkness tears open into the Kahramanmaras diorama | Rip or whoosh, then the D1 Winter Wind from the game | todo (D1 exists) |
| T13 | 14.3 to 16.6 | Title card "TAHMİN ET" | Title card hit (glitch plus low boom), the same for all 5 cards | todo |
| T14 | 16.6, 28.0, 36.3, 43.8 | Four glitch cuts between clips | Short glitch or digital stutter (G7 style) | todo |
| T15 | 19.2 | Zoom-blur whip to the globe | Whoosh (G5 exists) | reuse G5 |
| T16 | 20.2 to 22.5 | Title card "KEŞFET" | Title card hit (T13) | todo |
| T17 | 24.55 | The crosshair locks on the Indian Ocean | Target Lock (G4 exists) | reuse G4 |
| T18 | 25.75 | Zoom flash into the ocean | Flash whoosh | todo |
| T19 | 26.1 to 28.0 | Title card "MÜDAHALE ET" | Title card hit (T13) | todo |
| T20 | 28 to 31 | Indian Ocean minigame clip | Game sounds: wave, water flow (C5, C6) | reuse game files |
| T21 | 31.0 | Hard cut to black | Cut to silence with two heartbeats (T9) at 31.12 and 31.40 | todo |
| T22 | 31.7 | The role menu opens | Menu music M1 and hover (M2) | reuse M1, M2 |
| T23 | 32.25 | "Farkındalık tek taraflı değildir" | Statement sting (T11) | todo |
| T24 | 34.3 | Title card "TERCİH ET" | Title card hit (T13) | todo |
| T25 | 36.3 to 40 | The globe spins again, "Dünyanın dört bir yanından", "3 afet senaryosu" | Globe spin G2, statement stings | reuse G2 |
| T26 | 39.7 | Pixelate into the Easter bunny scene | Pixelate or 8-bit sweep | todo |
| T27 | 41.5 | The egg bursts and the bunny pops out | 8-bit pop or burst | todo |
| T28 | 41.6 | "Belki bir de easter egg, kim bilir…" | Statement sting | todo |
| T29 | 43.8 to 47.4 | Result card, the closing line types on (44.4 to 45.9) | Card swell (R1), typing (G3) | reuse R1, G3 |
| T30 | 47.4 | Title card "FARK ET" | Title card hit (T13) | todo |
| T31 | 49.1 | CRT power-off | TV or CRT switch-off sound | todo |
| T32 | 49.8 to 50.3 | Black | Silence | no sound |
| T33 | whole film | Music under the film | One music bed. To decide: the menu music M1 (Title.mp3) or a new track. | to decide |
