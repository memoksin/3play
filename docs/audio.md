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
