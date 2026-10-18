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
| G9 | Globe ambience | While the globe is shown (space or Earth feel) | Quasi Drone | bassimat | https://freesound.org/people/bassimat/sounds/840934/ | CC0 | in repo | About 10 min, calm evolving drone. Loop, quiet, under the G1 swell and G2 spin sound. Expected file: `globe/earth_ambience.ogg`. No water. |

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

## All buttons in the whole game

Burcu's rule: every button in every scene uses the same two sounds, no exceptions. Done by one generic hook in `scripts/audio.gd` (any BaseButton in the real tree, once per button). Exceptions that keep their own cue: language flags (LS1, LS2) and the intro Continue hover (D6). Keyboard focus plays nothing (menus grab focus when they open).

| # | Sound | Plays when | File name | Author | Link | License | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| UI1 | Button hover | The mouse is over any button: menus, the launch notice's "Anladım", the easter-egg card, minigame choice and card buttons, the pause menu (4 buttons), settings, result card | UI_Hover | unfa | https://freesound.org/people/unfa/sounds/565131/ | CC0 | in repo (M2) | Same as M2. Also on the pause menu opened inside a minigame. |
| UI2 | Button click | Any button is pressed, including the pause menu buttons | Soft UI Button Click | Jummit | https://freesound.org/people/Jummit/sounds/528561/ | CC0 | in repo (M3) | Same as M3. |
| UI3 | Settings panel and pause menu | Settings (language, invert Y, fullscreen, replay prologue, back) and the pause menu (Resume, Settings, Main menu, Quit) | UI1 hover and UI2 click | | | | chosen | All of these are buttons or toggles, so the global hook covers them. The language flags keep LS1 and LS2. |
| UI4 | Sliders | Master, Music, Effects volume and mouse sensitivity sliders | | | | | no sound | Burcu: no sound on sliders. |

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
| D1 | Kahramanmaras ambience | Diorama of Kahramanmaras (snow, wind) | G56-21-Winter Wind.wav | craigsmith | https://freesound.org/people/craigsmith/sounds/438876/ | CC0 | in repo | Replaces the martypinso snowstorm. Also used for FN1. Needs a soft fade at the loop ends. |
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
| C3 | Wave rising | The wave comes into view, 15 s before the hit | Rumble · fade in 10s | unfa | https://freesound.org/people/unfa/sounds/258341/ | CC0 (verify) | in repo | Low rumble that fades in over 10 s: the wave approaching. Starts when the wave comes into view. |
| C4 | Wave hits | The wave crosses the bay and breaks on the beach, with the shake | Ocean Waves.wav | Noted451 | https://freesound.org/people/Noted451/sounds/531015/ | CC0 (verify) | in repo | Use seconds 32 to 37 of the file (the big wave). |
| C5 | Water flows through the pipes | Water flows tile by tile after the hit | Hydrophone underwater stream close pipe gurgle.wav | JavierZumer | https://freesound.org/people/JavierZumer/sounds/422660/ | CC0 | in repo | Use the part from about 0:40 onward. |
| C6 | Basin fills | The water reaches a basin and it fills | Water Echo.wav | eeriedescence | https://freesound.org/people/eeriedescence/sounds/419741/ | CC0 | in repo | Well-like echo. |
| C7 | Broken line spills | The water spills out of a broken line | Big Water Splash | qubodup | https://freesound.org/people/qubodup/sounds/442773/ | CC0 | in repo (to test) | Repeat the same splash several times, each starting before the previous ends, to build an overflow. Try it, replace the sound if it feels fake. Issue #95. |
| C8 | Village floods | The spilled water floods the village | | | | | no sound (test) | Leave empty and test the game. Add a sound only if it feels empty. |
| C9 | Water drains | The water drains back (1.5 s) | wavesound.wav | transitking | https://freesound.org/people/transitking/sounds/11505/ | CC0 | in repo | Use only the first 4 s of the file (waves wash over the rock and drain back through a crack). |
| C10 | Pipeline locks | A pipeline becomes correct (inlet i reaches its own basin; nothing locks, not repeated for the same line within 1 s) | Short Success Sound Glockenspiel Treasure Video Game | FunWithSound | https://freesound.org/people/FunWithSound/sounds/456965/ | CC0 | in repo | The shared success sound (FN7, FR6, BM4, C10). Memoksin added a `locked` sound_event kind in audio.gd (#162); Sude adds the cue. |

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
| FN1 | Snowstorm ambience | Whole minigame | G56-21-Winter Wind.wav | craigsmith | https://freesound.org/people/craigsmith/sounds/438876/ | CC0 | in repo (same as D1) | The same new snowstorm sound as D1. |
| FN2 | Footsteps | The player walks | Footsteps Dirt Gravel | PotatokingXII | https://freesound.org/people/PotatokingXII/sounds/352870/ | CC0 | in repo | Normal footsteps (not snow). About 35 s, trim to a clean stride loop. |
| FN3 | Flashlight on and off | The flashlight is turned on or off | Flashlight Clicking On and Off | deleted_user_7146007 | https://freesound.org/people/deleted_user_7146007/sounds/383659/ | CC0 | in repo | 0 to 1 s = turning on. 2 to 3 s = turning off. |
| FN4 | Battery low | The flashlight battery is running out | Electronic Timer Beeping 4X | Rudmer_Rotteveel | https://freesound.org/people/Rudmer_Rotteveel/sounds/536420/ | CC0 | in repo | The file already holds 4 beeps ("bip bip"). Play it when the battery is low. |
| FN5 | Whistle | The whistle that shows the direction | metal whistle | strongbot | https://freesound.org/people/strongbot/sounds/568995/ | CC0 | in repo | First 3 seconds of the file. |
| FN6 | Found a family member | The player reaches a family member | Game Pickup | IENBA | https://freesound.org/people/IENBA/sounds/698768/ | CC0 | in repo (reuse of F2) | First second of the file. Burcu: the same Game Pickup sound also plays when the player picks up an item (battery, kit, blanket; event `pickup`). |
| FN7 | Success | The family reaches the assembly point | Short Success Sound Glockenspiel Treasure Video Game | FunWithSound | https://freesound.org/people/FunWithSound/sounds/456965/ | CC0 | in repo | One success sound for FN7, FR6 and BM4. |
| FN8 | Aftershock | The aftershock hits | Cracking Earthquake | uagadugu | https://freesound.org/people/uagadugu/sounds/222521/ | CC0 | in repo (reuse of F6) | Trim to the shaking. |
| FN8a | Building crack | Aftershock warning and the start of the aftershock | breaking_concrete | zatar | https://freesound.org/people/zatar/sounds/755522/ | CC0 (verify) | in repo | Burcu picked it: a hammer breaking concrete, for the building body cracking. Plays with FN8 (Cracking Earthquake). Trim to the first crack by ear. |
| FN9 | Hurt | The player is hurt near a building | Hurt_C_07 | cabled_mess | https://freesound.org/people/cabled_mess/sounds/350926/ | CC0 | in repo | Retro-style hurt sound, about 0.2 s. |
| FN10 | Trapped person taps | Mrs. Ayse under the rubble taps (event `tap`, repeats every 1.8 s close to 6 s far, volume and pan by distance) | Metal Knocking | BenjaminNelan | https://freesound.org/people/BenjaminNelan/sounds/410362/ | CC0 (verify) | chosen | Burcu: use only the first second of the file. Sude: add the file, the cue, and the CREDITS row, with a slight low-pass so it sounds muffled from behind the rubble. |

## Fire (Black Saturday, kangaroo farm, first person)

Spec: `docs/minigames/fire-farm.md`.

| # | Sound | Plays when | File name | Author | Link | License | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| FR1 | Fire and wind ambience | Whole minigame | digital wildfire mixed with WIND BLOWING.mp3 | vekoN + Podcapocalipsis | https://freesound.org/people/vekoN/sounds/537530/ and https://freesound.org/people/Podcapocalipsis/sounds/521696/ | CC0 (checked by Sude) | in repo | Option B approved by Burcu by ear. Wind seconds 9 to 14, 10 s seamless loop. Option A (craigsmith Large Fire Burning) dropped. |
| FR2 | Footsteps | The player walks | Footsteps Dirt Gravel | PotatokingXII | https://freesound.org/people/PotatokingXII/sounds/352870/ | CC0 | in repo | Same as FN2. Trim to a clean stride loop. |
| FR3 | Jump and landing on debris | The player jumps over the debris | Human Impact on Ground | alegemaate | https://freesound.org/people/alegemaate/sounds/364690/ | CC0 | in repo | Short clip of a person landing after a jump. |
| FR4 | Pick up the wire cutters | The player picks up the wire cutters (was the knife) | Game Pickup | IENBA | https://freesound.org/people/IENBA/sounds/698768/ | CC0 | in repo (reuse of F2) | First second of the file. A metal clank would fit the cutters better. |
| FR5 | Cut the fence (hold) | While the player holds to cut the fence ties (event `snip` is the per-tie sound below) | Sanding_a_Piece_Of_Wood.wav | CapsLok | https://freesound.org/people/CapsLok/sounds/204948/ | CC0 | in repo | Burcu: use 16 s to 19 s as a short loop while the player holds. Each tie that breaks also plays a short metal snip (FR5.2, todo). |
| FR5.2 | Snip a fence tie | Each wire tie is cut (event `snip`, 6 per fence) | Scissors Cutting Air.wav | RutgerMuller | https://freesound.org/people/RutgerMuller/sounds/51164/ | CC0 (verify) | in repo | Use only 2.8 s to 3.2 s of the file (short metal cut). No CC0 wire-cutter recording exists. |
| FR5.1 | Fence panel crashes down | The cut panel slams onto the ground (event `panel_land`, index 0), the little hop after it (index 1) | Scrap metal dropping / crashing | SamsterBirdies | https://freesound.org/people/SamsterBirdies/sounds/587443/ | CC0 (verify) | in repo | Use 2 s to 4 s of the file (index 0 crash). For the small hop (index 1) reuse a short piece of the same file. |
| FR6 | Success | A task is done (fence cut, flame out) | Short Success Sound Glockenspiel Treasure Video Game | FunWithSound | https://freesound.org/people/FunWithSound/sounds/456965/ | CC0 | in repo (same as FN7) | The same success sound as FN7 and BM4. |
| FR7.1 | Hose attached | The hose is put on the valve | Door Lock.wav | nebulasnails | https://freesound.org/people/nebulasnails/sounds/405534/ | CC0 | in repo | About 0.75 s door latch. |
| FR7.2 | Valve turn | The valve is turned | Hose Sounds | JazzyBay | https://freesound.org/people/JazzyBay/sounds/435052/ | CC0 | in repo | Use 0:58 to 1:03 of the file. |
| FR8 | Water spray | The hose sprays | Hose Sounds | JazzyBay | https://freesound.org/people/JazzyBay/sounds/435052/ | CC0 | in repo | Use 1:07 to 1:18 of the file (confirmed). |
| FR9 | Small flame | The small flame burns | fire crackling, fireplace, BBQ | AlexanderChe | https://freesound.org/people/AlexanderChe/sounds/410404/ | CC0 (checked by Sude) | in repo | Alone, no wind mix. Small wood fire, about 16 s, loop. Fades out when the flame is put out (FR10). |
| FR10 | Flame goes out | The flame is put out | | | | | decided | No separate sound: the flame sound (FR9) fades out. |
| FR11 | Kangaroos run out | 2 to 3 kangaroos run through the gap | Horse Gallop Loop.wav + Footsteps Dirt 01 | DeadxCreed + aglinder | https://freesound.org/people/DeadxCreed/sounds/322448/ and https://freesound.org/people/aglinder/sounds/264469/ | CC0 (verify both) | in repo (to test) | No kangaroo hop CC0 exists. Layer both and play the pair 2 to 3 times, each starting before the previous ends. Replace if it sounds fake. |
| FR11c | Kangaroo footsteps | 2 to 3 kangaroos run through the gap (third layer) | animal-walking-right-to-left-192403.mp3 | kuzu420 (Pixabay) | https://pixabay.com/sound-effects/film-special-effects-animal-walking-right-to-left-192403/ | Pixabay Content License | in repo | Burcu found it. Seconds 2 to 9 of the file, +8 dB, mono, file `fire/kangaroo_steps.ogg`. To wire next to FR11a (gallop) and FR11b (dirt steps). |
| FR12 | Smoke (cough, breath) | The smoke thickens | | | | | no sound | Not needed. |
| FR14 | Alert flash | An alert shows at the top of the screen (event `alert`, index 1 = urgent: "The fire front is coming!", "Get out now!" ...) | FR1 mix (digital wildfire + wind), swelled | vekoN + Podcapocalipsis | see FR1 | CC0 | in repo (FR1 reuse) | No new file. FR1 rises 5 dB (urgent) or 3 dB in 0.12 s, holds 0.6 s, settles back over 0.9 s (`audio.gd` `fire_alert`). Not during the ending (FR13 owns FR1 then). |
| FR13 | Ending shot | The camera rises out of first person over the burning farm (event `exit`), or the dark version when time runs out (event `lose`) | FR1 mix (digital wildfire + wind), raised | vekoN + Podcapocalipsis | see FR1 | CC0 | in repo (FR1 reuse) | No new file. On `exit`: raise the FR1 volume and open it up, then a held quiet before the result card. On `lose`: the same sound lowered (low-pass) and heavier. Burcu agreed. |

## Beam network (Isin Agi, solar flare 3026, #124)

Rotate satellites to route the solar beam into collectors, waves, a countdown, "X/Y cities saved".

| # | Sound | Plays when | File name | Author | Link | License | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| BM1 | Space ambience | Whole minigame | Solar Storm.wav | Puniho | https://freesound.org/s/151098/ | CC0 | in repo (reuse of D3) | |
| BM2 | Rotate a satellite | The player rotates a satellite | Servo_1_Panera.wav | sinmente0987 | https://freesound.org/people/sinmente0987/sounds/160712/ | CC0 (checked by Sude) | in repo | Burcu picked it instead of Servo motor (Burningmonkey). Use only the first 1 s to 1.5 s of the file. |
| BM3 | Beam | The beam runs through the satellites | Laser Beam Firing | SecureSubset | https://freesound.org/people/SecureSubset/sounds/783986/ | CC0 | in repo | About 0.75 s. Repeat it back to back so it becomes a continuous sound while the beam runs. |
| BM4 | Collector charged, city saved | A collector is charged | Short Success Sound Glockenspiel Treasure Video Game | FunWithSound | https://freesound.org/people/FunWithSound/sounds/456965/ | CC0 | in repo (same as FN7) | The same success sound as FN7 and FR6. |
| BM5 | City lost | A city is lost | power-down-01.wav | newagesoup | https://freesound.org/people/newagesoup/sounds/348249/ | CC0 | in repo | Use the part from 1 s onward. |
| BM6 | Wave warning | A wave is coming (briefing card, countdown start) |  |  |  |  | no sound | Burcu: silent for now. The countdown beeps (BM8) already cover it. Decide after a test in the game. |
| BM7 | Wave hits | The shot (the beam travels) |  |  |  |  | no sound | Burcu: silent. The shot is already BM3 (beam) with BM4 and BM5. Optional later: a short low boom on wave 4. |
| BM8 | Countdown | The countdown runs | Bomb Countdown Beeps | snakebarney | https://freesound.org/people/snakebarney/sounds/138108/ | CC0 | in repo |  |

## Pitch film (trailer, 59.95 s, mixed)

Source: the `SFX`, `STEMS` and `MUSIC` tables in `tools/video/film.html` (every cue tied to a picture row) and
`tools/video/mix.py` (levels, -14 LUFS master). Times are final-film seconds (the approved intro from its 2.0 s, so
6.0 s of intro, then the film). On-screen text is Turkish. Files, trims and levels: `assets/audio/trailer/README.md`.
The game clips are recorded with the game's own sound (Godot Movie Maker), so in-clip sounds (whistle, lamp, wave,
hovers, the fence, the kangaroos, the hose) come from the game itself. The intro cues keep their places on the intro
picture; the ones in its first 2.0 s are gone or start part-way.

The picture is cut to the music bed (T33, 96 BPM, a beat every 0.625 s, bars from 0.9 s): cuts, card entries, the
logo and FARK ET sit on beats or bars. Music and game sound sit about level over the film (bus report of `mix.py`:
music +0.8 LU against the effects); the bed steps back 2 to 3 dB under the key game sounds (lamp, globe lock, wave
break, fence cut, kangaroos, hose, the AAA swell, "yok yok").

| # | Time (s) | What happens | Sound | Status |
|---|---|---|---|---|
| T1 | 0 to 5.75 | Intro: the Stack logo in a storm | Rain.wav (idomusics) https://freesound.org/people/idomusics/sounds/518863/ , looped under the intro | in mix |
| T2 | 0.4 | Distant sheet lightning in the clouds | thunder.rumble.ogg (xUMR) https://freesound.org/people/xUMR/sounds/486557/ , seconds 5 to 10 | in mix |
| T3 | 0.8 and 1.4 | Two close lightning strikes, the logo flickers | Thunderclap (Fission9) https://freesound.org/people/Fission9/sounds/534023/ , then Very close lightning strike (Simon Spiers) https://freesound.org/people/Simon%20Spiers/sounds/437243/ | in mix |
| T4 | 1.9 | Final strike hits the logo | Thunder with no rain (shazzakip) https://freesound.org/people/shazzakip/sounds/398013/ , the plain file `t4_final_strike.ogg` raised in the mix (Burcu's call); the layered file is not used | in mix |
| T5 | 2.45 to 3.3 | "STACK PRESENTS" types on | Keyboard typing (G3) | in mix |
| T6 | 3.5 | Last far strike | Same as T2 | in mix |
| T7 | 4.05 to 5.65 | The camera pushes into the logo's eye | noise riser (reathance) https://freesound.org/people/reathance/sounds/503796/ | in mix |
| T8 | 5.75 to 6.0 | Pure black | The music bed's quiet opening only | in mix |
| T9 | 6.22 / 6.67, 7.32 / 7.77 | Darkness with a heartbeat glow (lub / dub) | SLOW HEARTBEAT (daandraait) https://freesound.org/s/249716/ , one lub-dub per beat | in mix |
| T10 | 6.8 to 8.0 | Echo rings of a faint voice ("Sesimi duyan var mı?") | Dropped by Burcu: no voice recording | no sound |
| T11 | 7.8 to 10.15 | "Hayatın göremediğimiz boyutları vardır" types on | Cinematic Low Pitch Impact (Jofae) https://freesound.org/people/Jofae/sounds/408141/ + typing (G3) | in mix |
| T12 | 10.275 | The darkness tears open into the snowy Kahramanmaras diorama | Winter Wind (D1) | in mix |
| T13 | 12.15 to 14.025 | Title card "TAHMİN ET" | Title card hit: low boom (T11) + the start of Glitch Corruption (G7), the same for all cards | in mix |
| T14 | 14.025, 27.775, 39.65, 42.775 | Glitch cuts: Fener, Indian Ocean, second globe, Black Saturday fire | Glitch Corruption (G7), first 0.45 s | in mix |
| T14b | 14.025 to 19.025 | Fener (Kahramanmaras) at night, five people (HUD 0/5): a whistle in the dark, the lamp clicks on (14.65), the mother is found, the family follows | Game sound of the clip: wind (FN1), footsteps (FN2), whistle (FN5), lamp (FN3), found (FN6) | in mix |
| T15 | 16.9 to 19.025 | Zoom-blur whip to the globe | Whoosh (G5), peak on the cut; the globe's own sound (G1, G9) after it | in mix |
| T16 | 19.65 to 21.85 | Title card "KEŞFET" over the spinning globe (the game's whole globe animation, one take at 1.1x, 19.025 to 25.9) | Title card hit (T13) | in mix |
| T17 | 23.4 | The crosshair locks on the Indian Ocean (a bar) | Target Lock (G4) + the clip's own sound (coordinates typing G3, zoom whoosh G5) | in mix |
| T18 | 25.55 | Zoom flash into the ocean | The clip's own zoom whoosh (G5) | in mix (game sound) |
| T19 | 25.9 to 27.775 | Title card "MÜDAHALE ET"; the music's drums come in on the same bar | Title card hit (T13) | in mix |
| T20 | 27.775 to 34.65 | Indian Ocean (Connect): the pipes lock, the sea draws back (sped up), the wall rises and breaks over the town (33.4, a bar), the town floods | Game sound of the clip (2.9x, then 1.25x): pipes lock (C10), wave rising (C3), the wave hits (C4), water + a low boom (T11) on the break; hard cut | in mix |
| T21 | 34.65 to 35.275 | Hard cut to black | The music stops for the beat; one heartbeat (lub 34.71, dub 35.16) | in mix |
| T22 | 35.275 to 39.65 | The role menu opens (eye): hover on Devlet (36.4), then Vatandaş (38.5, under TERCİH ET) | Music bed back, hovers (M2) from the menu clip | in mix |
| T23 | 35.9 to 38.45 | "Farkındalık tek taraflı değildir" types on over the menu (typed by 36.9, held to read) | Statement sting (T11, soft) + typing (G3) | in mix |
| T24 | 38.4 | Title card "TERCİH ET" | Title card hit (T13) | in mix |
| T25 | 39.65 to 42.775 | The globe spins again (1.1x), "Dünyanın dört bir yanından", "3 afet senaryosu" | Globe spin ambience (G2), typing (G3), a hover tick (M2) when the 3 settles | in mix |
| T25f | 42.775 to 47.775 | Black Saturday (Victoria, Australia), first person as the citizen: the wire cutters cut the fence (the cut on the bar at 43.4), hard cut (44.025) to the kangaroos running out, hard cut (45.275) to the hose on the flame in the way out, the flame goes out (47.15) | Game sound of the clip: fire and wind (FR1), the fence cut (FR5, FR5.2, FR6), the kangaroos (FR11), the flame (FR9), the hose spray (FR8), success (FR6) | in mix |
| T26 | 47.375 | Pixelate into the Easter bunny scene | Glitch Corruption (G7), 0.6 to 1.35 s | in mix |
| T27 | 48.29, 48.53, 49.025 | The egg cracks twice and bursts (picture sped up), the bunny pops out | Egg cracking.wav (FngerSounds) https://freesound.org/s/250133/ at normal speed, from 47.945: its cracks set the picture's | in mix |
| T28 | 48.4 | "Belki bir de easter egg, kim bilir…" | Statement sting (T11, soft) + typing (G3) | in mix |
| T29 | 50.9 to 53.4 | "AAA" with a small "GAME" under it, calm like a game label; it settles, then "yok yok" types on (52.15) into the music's half-beat break | Guitar swell (R1, from 50.7), no hit; typing (G3) | in mix |
| T29c | 53.4 to 55.9 | "3play" lands (the game's logo) on the music's strongest hit, the same small "GAME" under it, held | Low boom (T11) under the bed's own hit (T33) | in mix |
| T30 | 55.9 to 59.675 | Title card "FARK ET", held, closed by the CRT power-off | Title card hit (T13) | in mix |
| T31 | 59.025 | CRT power-off on FARK ET: the end of the film | Turning the TV off (Cloud-10) https://freesound.org/people/Cloud-10/sounds/648174/ | in mix |
| T33 | 0.9 to 59.65 | Music under the film | Music bed `t33_music_bed.ogg`, made for the film: Opening Theme [Action/Suspense] V2 (nene, OpenGameArt, CC0) opens it, on the bar at 25.9 the drums of Mountain Emperor (Kevin MacLeod, incompetech.com, CC BY 4.0) take over, a half-beat break before the logo, its strongest hit on the logo (53.4). Under the intro's storm, out on the hard cut to black for a beat, out with the CRT power-off. | in mix |
| T34 | 59.675 to 59.95 | Black | Silence | no sound |


### Notes from Burcu (pitch film and game)

- Possible later use: "8 Bit Sound - 1-Up!" (Breviceps, https://freesound.org/people/Breviceps/sounds/450613/ , CC0) as the sound when a badge (rozet) is earned on the result card. Not decided, not in the game yet.
- All typed text from the story layer (the Voice lines, prologue, any other typed line) uses the same keyboard typing sound as G3, D4 and R3.
