# Pitch video segments

Each segment is a self-contained HTML page (`tools/video/<segment>.html`) that draws one frame with
`window.renderAt(t)`. It is a pure function of `t`: no wall clock, no requestAnimationFrame state, randomness only from
seeded PRNGs. So frame N = `renderAt(N / 60)` comes out the same on every render. Visuals only, no audio.
No Godot is involved.

| Segment | Length | Output |
|---|---|---|
| `intro_stack` | 6.5 s, 390 frames | `export/video/intro_stack.mp4` |
| `film` | 42.3 s, 2538 frames | `export/video/film.mp4` (storyboard steps 5-19, plays after the approved intro) |

## Render

```sh
python3 tools/video/key_logo.py          # only when the logo PNGs change: keyed logos + tools/video/logo_align.js
node tools/video/render.mjs intro_stack  # ~3 min: export/video/frames/intro_stack/%05d.png -> export/video/intro_stack.mp4
node tools/video/render.mjs intro_stack --still 1.35,2.5,4.2   # quick stills in export/video/stills/intro_stack/
python3 tools/video/contact_sheet.py sheet.png export/video/stills/intro_stack/*.png
```

`render.mjs` runs headless Chrome (no window) over the DevTools protocol with the viewport fixed at
1920x1080 @1x. It serves the repo on a local 127.0.0.1 http server, because WebGL refuses `file://` images. It captures
every frame as a PNG and then encodes:
`ffmpeg -framerate 60 -i frames/%05d.png -c:v libx264 -crf 16 -preset slow -pix_fmt yuv420p -r 60 <segment>.mp4`.
To preview in a browser, serve the repo root (for example `python3 -m http.server`) and open
`/tools/video/intro_stack.html?t=2.5`.

`intro_stack.html`: all timing is in the constants at the top (`STRIKES`, `T_TEXT`, `T_PUSH0`, ...).
`HURT_VARIANT = "hurt"` selects the damaged logo. Set it to `"hurt_alt"` to use the version without syrup.

## Join segments (lossless)

Every segment uses the same settings (H.264, yuv420p, 1920x1080, 60 fps, encoded by `render.mjs`), so the concat
demuxer can join them without re-encoding:

```sh
cd export/video
printf "file '%s'\n" intro_stack.mp4 next_segment.mp4 > list.txt
ffmpeg -f concat -safe 0 -i list.txt -c copy pitch.mp4
```

`intro_stack` ends on 16 frames of pure black, so the next segment can start from black.
Run `ffprobe` on each part first: codec, resolution, fps and pix_fmt must match, or `-c copy` produces a broken file.

## Freeze approved outputs

Once a segment is approved, do not re-render it for the final cut. Copy the approved mp4 under a versioned name
(for example `export/video/approved/intro_stack_v1.mp4`) and concatenate only the approved files. Re-rendering is
deterministic, but a later change to a shared asset, the font, Chrome or ffmpeg can still change the pixels. If a
segment really has to change, render it again, review it again, and save it as a new version.

## Approved intro: `intro_stack_v2_cut`

`intro_stack_v2.html` is `intro_stack` with the happy logo held 2.6 s longer (`HOLD`). The approved cut drops the
first 66 frames (happy logo stays ~2.5 s) and fades in over 0.3 s:

```sh
node tools/video/render.mjs intro_stack_v2
ffmpeg -framerate 60 -start_number 66 -i export/video/frames/intro_stack_v2/%05d.png -vf "fade=t=in:st=0:d=0.3" \
  -c:v libx264 -crf 16 -preset slow -pix_fmt yuv420p export/video/intro_stack_v2_cut.mp4
```

Frozen copy: `export/video/approved/intro_stack_v2_cut.mp4` (8.0 s, 1920x1080, 60 fps).

## Godot clips

`bash tools/video/capture.sh <clip>` plays the real scenes by scripted input (`tools/video/capture.gd`, locale tr, Movie Maker, no AUDIO) and writes `export/video/clips/<clip>/%05d.png` (1920x1080, 60 fps) + `clip.json`; clips: kahr_diorama, kahr_mini, globe_spin, globe_lock_io, io_mini, menu_roles, globe_spin2, result_card (~20 s each).

## Film body: `film.html` (storyboard steps 5-19)

`film.html` is the rest of the pitch film after the approved intro. It works like `intro_stack`, with one difference:
`renderAt(t)` returns a Promise, because it loads Godot gameplay frames on demand. `render.mjs` waits for it.
Title cards (`TAHMİN ET`, `KEŞFET`, `MÜDAHALE ET`, `TERCİH ET`, `FARK ET`) reuse the STACK PRESENTS type-on: glitch
split, white-hot arrival, block cursor, side rules. The verb is amber and the closing "ET" is teal. Statements
(`s_*` rows) are smaller, in the fg colour, and `*stars*` mark the amber words. The post pass matches the intro: bloom,
chromatic aberration, grain, vignette. On top of that it adds glitch cuts, zoom blur, pixelation and a CRT power-off.

```sh
node tools/video/render.mjs film --still 4.85,16.6,33.9,41.3     # stills in export/video/stills/film/
node tools/video/render.mjs film                                 # ~30 min: export/video/film.mp4 (+ export/video/film_cues.json)
node tools/video/render.mjs film --clips /abs/path/to/clips      # clips from another folder (served at /__clips/)
bash tools/video/assemble.sh                                     # approved intro + film -> export/video/pitch_film.mp4
INTRO=/abs/path/intro_stack_v2_cut.mp4 bash tools/video/assemble.sh   # when approved/ lives in another checkout
```

`assemble.sh` never writes into `approved/`. It joins the two parts by stream copy when their codec, profile, size,
pix_fmt and fps match and the joined file decodes cleanly. Otherwise, or with `MODE=reencode`, it re-encodes once with
the render settings (H.264 crf 16 slow, yuv420p, 60 fps, no audio). It fails if the result is longer than 60 s.

### Timeline table

All timing lives in the `TL` table at the top of `film.html`. Times are film-local seconds. In the final film add
8.0 s (`INTRO_LEN`). Each row has `step`, `id`, `start`, `len`, and either `clip` + `in` (clip in-point in seconds) or
`text`. Effects read their times from the rows, so changing a row retimes everything tied to it. `SCENARIO_COUNT`
(step 16) is a single constant.

| Step | Row | Film s | Final s | Len | Content |
|---|---|---|---|---|---|
| 5 | `dark`, `s_hayat` | 0.00 | 8.00 | 4.4 | near-black, heartbeat glow, voice echo rings; "Hayatın göremediğimiz boyutları vardır" at 2.0 |
| 6 | `diorama` | 4.40 | 12.40 | 4.2 | eye-shaped tear of light opens on `kahr_diorama`, extra snow, place caption |
| 7 | `c_tahmin` | 6.30 | 14.30 | 2.3 | TAHMİN ET over the diorama |
| 8 | `kahr_mini` | 8.60 | 16.60 | 2.9 | glitch cut in, zoom-blur whip out |
| 9 | `globe`, `c_kesfet` | 11.50 | 19.50 | 3.0 | `globe_spin`, KEŞFET at 12.2 |
| 10 | `lock` | 14.50 | 22.50 | 3.6 | `globe_lock_io` from 1.6 s at 1.5x: the game's own crosshair + readout + zoom to Sumatra; our corner brackets converge and lock with it (+2.05), extra push + teal flash from +3.2 |
| 11 | `c_mudahale` | 18.10 | 26.10 | 1.9 | MÜDAHALE ET on dark water (no diorama) |
| 12 | `io_mini` | 20.00 | 28.00 | 3.0 | glitch cut in, hard cut out |
| 13 | `black` | 23.00 | 31.00 | 0.7 | black, two faint heartbeats |
| 14 | `menu`, `s_fark`, `c_tercih` | 23.70 | 31.70 | 4.6 | `menu_roles` opens like the eye; statement 24.25, TERCİH ET 26.3 |
| 15-16 | `globe2`, `s_dunya`, `s_count` | 28.30 | 36.30 | 3.8 | `globe_spin2`; "Dünyanın dört bir yanından" + "3 afet senaryosu" (digit slot-roll) |
| 17-18 | `bunny`, `s_easter` | 32.10 | 40.10 | 3.7 | pixelate into the pixel-art egg; it cracks, the bunny pops out; "Belki bir de easter egg, kim bilir…" |
| 19 | `result`, `c_fark`, `end` | 35.80 | 43.80 | 6.5 | `result_card` (glitch cut in), it sinks to dark, FARK ET, CRT power-off at 41.1, black from 41.8 |

Final film: 8.0 s intro + 42.3 s film = 50.3 s.

### Silent beats for the team's audio

The film has no audio. The cue sheet is generated at `export/video/film_cues.json` on every render (final-film seconds =
film seconds + 8.0). Current values:

| Final s | Film s | Cue |
|---|---|---|
| 8.22 / 8.50 | 0.22 / 0.50 | heartbeat lub / dub (the vignette and a dim red glow pulse on each beat) |
| 8.80 - 10.00 | 0.80 - 2.00 | voice, echoing: "Sesimi duyan var mı?" (three faint rings) |
| 9.22 / 9.50 | 1.22 / 1.50 | heartbeat lub / dub |
| 10.00 | 2.00 | statement types on: "Hayatın göremediğimiz boyutları vardır" |
| 12.40 | 4.40 | darkness tears open (light slit, then the lids part), snowy Kahramanmaraş |
| 14.30 | 6.30 | title card TAHMİN ET |
| 16.60 | 8.60 | glitch cut: Kahramanmaraş minigame |
| 19.20 | 11.20 | zoom-blur whip to the globe |
| 20.20 | 12.20 | title card KEŞFET |
| 24.55 | 16.55 | target lock (Indian Ocean) |
| 25.75 | 17.75 | zoom flash into the ocean |
| 26.10 | 18.10 | title card MÜDAHALE ET |
| 28.00 | 20.00 | glitch cut: Indian Ocean minigame |
| 31.00 | 23.00 | hard cut to black |
| 31.12 / 31.40 | 23.12 / 23.40 | heartbeat lub / dub (fainter) |
| 31.70 | 23.70 | menu opens |
| 32.25 | 24.25 | statement: "Farkındalık tek taraflı değildir" |
| 34.30 | 26.30 | title card TERCİH ET |
| 36.30 | 28.30 | glitch cut: second globe spin |
| 36.60 | 28.60 | statement: "Dünyanın dört bir yanından" |
| 37.90 | 29.90 | statement: "3 afet senaryosu" |
| 39.70 | 31.70 | pixelate into the bunny scene |
| 41.50 | 33.50 | egg bursts, bunny pops out (egg wobbles at 40.4 and 41.0) |
| 41.60 | 33.60 | statement: "Belki bir de easter egg, kim bilir…" |
| 43.80 | 35.80 | glitch cut: result card |
| 47.40 | 39.40 | title card FARK ET |
| 49.10 | 41.10 | CRT power-off |
| 49.80 - 50.30 | 41.80 - 42.30 | black |

### Godot clips and swapping one

Clips live in `export/video/clips/<name>/%05d.png` (1920x1080, 60 fps) with `clip.json` `{ "frames": N }`. Numbering
may start at 00000 or 00001; the page detects which. A clip with no `clip.json` draws a labelled PLACEHOLDER, so the
film always renders. A clip that is too short holds its last frame. Frame shown = `in + (t - start) * speed`, in
seconds × 60.

To swap a clip, for example if the Kahramanmaraş minigame becomes "Fener":
1. Capture it as `export/video/clips/fener_mini/` (PNG sequence + `clip.json`).
2. In `TL`, change the `kahr_mini` row to `clip: "fener_mini"` and set `in` to the best moment. Change `len` only if
   the cut needs to be longer; later rows do not shift by themselves, so move their `start` too.
3. If the place changes, also edit the caption in `drawScene` (`KAHRAMANMARAŞ, TÜRKİYE`, coordinates) and the card text.
4. Render stills around the cut, then the full film, then `assemble.sh`.

For `globe_lock_io`, set `in`/`speed` so that the game's crosshair closes `lock` seconds after the row start (now:
clip 4.67 s = 1.6 + 1.5 × 2.05). Set `target` to the Indian Ocean's screen position in the locked frame (frame
centre). `hud: "brackets"` draws only corner brackets and a lock pulse, because the clip has the game's own crosshair
and readout. `hud: "full"` adds our own crosshair, rings and a typed readout (HEDEF KİLİTLENDİ, coordinates) for a
clip without the game's lock UI.

Current in-points: the diorama starts at 0.9 s (after the game's fly-in). `kahr_mini` starts at 2.6 s, so two drags
land in the cut. `io_mini` starts at 6.5 s at 1.1x: the last rotations, "Dalga geldi!", water flowing. In
`menu_roles`, "Devlet" is hovered right under TERCİH ET. In `result_card`, the closing line types on at 36.4-37.9.
