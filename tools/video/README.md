# Pitch video segments

Each segment is a self-contained HTML page (`tools/video/<segment>.html`) that draws one frame with
`window.renderAt(t)`. It is a pure function of `t`: no wall clock, no requestAnimationFrame state, randomness only from
seeded PRNGs. So frame N = `renderAt(N / 60)` comes out the same on every render. The pages draw pictures only; the
sound is mixed afterwards by `mix.py` from the cue tables in `film.html`.

| Segment | Length | Output |
|---|---|---|
| `intro_stack` | 6.5 s, 390 frames | `export/video/intro_stack.mp4` |
| `film` | 50.4 s, 3024 frames | `export/video/film.mp4` (storyboard steps 5-20, plays after the approved intro) |

## The whole pitch film, start to finish

```sh
for c in kahr_diorama fener_mini globe_spin globe_lock_io io_mini title menu_roles globe_spin2; do
  bash tools/video/capture.sh $c                 # Godot clips + their game sound (~2-6 min each)
done
node tools/video/render.mjs film                 # ~1 h: export/video/film.mp4 + film_cues.json + film_audio.json
bash tools/video/assemble.sh                     # approved intro + film -> export/video/pitch_film.mp4 (picture)
python3 tools/video/mix.py --mux                 # sound -> export/video/pitch_audio.wav + export/video/pitch.mp4
```

`export/video/pitch.mp4` is the deliverable: H.264 1920x1080 60 fps + AAC 48 kHz, 58.4 s, -14 LUFS.
`export/` is not in git. After a picture-only change of the cue tables (`SFX`, `STEMS`, `MUSIC`) a still render is
enough to rewrite `film_audio.json`: `node tools/video/render.mjs film --still 1`, then `mix.py --mux` again.

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

`bash tools/video/capture.sh <clip>` plays the real scenes by scripted input (`tools/video/capture.gd`, locale tr, Movie
Maker) and writes `export/video/clips/<clip>/%05d.png` (1920x1080, 60 fps), `clip.json` and `clip.wav`: the game's own
sound of exactly those frames (48 kHz stereo, the Music bus muted: the film has one music bed of its own). Clips:

| Clip | Length | What is played |
|---|---|---|
| `kahr_diorama` | 7.5 s | the Kahramanmaras diorama, the intro card hidden, framed closer |
| `fener_mini` | 6.3 s | Fener at night, staged on the avenue (seed 2): lamp off, the mother's whistle, the lamp clicks on at 1.25 s, the beam finds her (the game's slow motion and name), she joins the sister and the grandfather behind the player |
| `globe_spin` | 6.0 s | the globe spinning (speed driven) |
| `globe_lock_io` | 7.5 s | the real spin, lock on the Indian Ocean (crosshair closes at 4.67 s) and the start of the zoom |
| `io_mini` | 15.4 s | Connect from 11 s before the wave: two pipes turned (both lines lock), one line left open; the sea draws back, the swell rises into a wall and breaks over the whole town at 11.0 s (all or nothing), the flood |
| `title` | 3.5 s | the title screen; its tagline is hidden (the film types it there) |
| `menu_roles` | 7.0 s | the role menu: prompt, hover on Devlet (~3.0 s), then Vatandaş (~5.1 s) |
| `globe_spin2` | 5.0 s | a second spin from another angle |

## Film body: `film.html` (storyboard steps 5-20)

`film.html` is the rest of the pitch film after the approved intro. It works like `intro_stack`, with one difference:
`renderAt(t)` returns a Promise, because it loads Godot gameplay frames on demand. `render.mjs` waits for it.
Title cards (`TAHMİN ET`, `KEŞFET`, `MÜDAHALE ET`, `TERCİH ET`, `FARK ET`) reuse the STACK PRESENTS type-on: glitch
split, white-hot arrival, block cursor, side rules. The verb is amber and the closing "ET" is teal. `AAA` is the same
card with `calm: true`: all amber, a soft arrival, no jitter, no chroma split, no shake. Statements (`s_*` rows) are
smaller, in the fg colour, and `*stars*` mark the amber words. The `logo` row draws the game's logo (`ui/logo.tscn`:
VT323 "3play", a red copy left and a blue copy right) landing with a soft flash. The `team` row is the developers part:
the four portraits from `assets/sprites/ui/team/` with the names exactly as in `scenes/credits.gd` (`TEAM`). The post
pass matches the intro: bloom, chromatic aberration, grain, vignette. On top of that it adds glitch cuts, zoom blur,
pixelation and a CRT power-off.

```sh
node tools/video/render.mjs film --still 9.3,24.3,28.3,40.2,41.2,49     # stills in export/video/stills/film/
node tools/video/render.mjs film                                 # ~1 h: export/video/film.mp4 (+ film_cues.json, film_audio.json)
node tools/video/render.mjs film --clips /abs/path/to/clips      # clips from another folder (served at /__clips/)
bash tools/video/assemble.sh                                     # approved intro + film -> export/video/pitch_film.mp4
INTRO=/abs/path/intro_stack_v2_cut.mp4 bash tools/video/assemble.sh   # when approved/ lives in another checkout
python3 tools/video/mix.py --mux                                 # the sound -> export/video/pitch.mp4
python3 tools/video/contact_sheet.py export/video/stills/pitch_sheet.png export/video/stills/film/*.png
```

`assemble.sh` never writes into `approved/`. It joins the two parts by stream copy when their codec, profile, size,
pix_fmt and fps match and the joined file decodes cleanly. Otherwise, or with `MODE=reencode`, it re-encodes once with
the render settings (H.264 crf 16 slow, yuv420p, 60 fps, no audio). It fails if the result is longer than 60 s.

### Timeline table

All timing lives in the `TL` table at the top of `film.html`. Times are film-local seconds. In the final film add
8.0 s (`INTRO_LEN`). Each row has `step`, `id`, `start`, `len`, and either `clip` + `in` (clip in-point in seconds) or
`text`. Effects and sounds read their times from the rows, so changing a row retimes everything tied to it.
`SCENARIO_COUNT` (step 16) is a single constant.

| Step | Row | Film s | Final s | Len | Content |
|---|---|---|---|---|---|
| 5 | `dark`, `s_hayat` | 0.00 | 8.00 | 4.2 | near-black, heartbeat glow, voice echo rings; "Hayatın göremediğimiz boyutları vardır" at 1.8 |
| 6 | `diorama` | 4.20 | 12.20 | 3.9 | eye-shaped tear of light opens on `kahr_diorama`, extra snow, place caption |
| 7 | `c_tahmin` | 5.90 | 13.90 | 2.2 | TAHMİN ET over the diorama |
| 8 | `fener` | 8.10 | 16.10 | 4.6 | `fener_mini` from 0.45 s (glitch cut in): a whistle in the dark, the lamp clicks on at 8.9, "ANNE" found, the family follows; zoom-blur whip out |
| 9 | `globe`, `c_kesfet` | 12.70 | 20.70 | 2.9 | `globe_spin`, KEŞFET at 13.3 |
| 10 | `lock` | 15.60 | 23.60 | 3.6 | `globe_lock_io` from 1.6 s at 1.5x: the game's own crosshair + readout + zoom to Sumatra; our corner brackets converge and lock with it (+2.05), extra push + teal flash from +3.2 |
| 11 | `c_mudahale` | 19.20 | 27.20 | 1.8 | MÜDAHALE ET on dark water |
| 12 | `io_mini` | 21.00 | 29.00 | 5.4 | `io_mini` from 8.0 s (glitch cut in), slow push to the beach: the wall rises, breaks over the town at 24.0 (`hit`), the flood; hard cut out |
| 13 | `black` | 26.40 | 34.40 | 0.6 | black, one faint heartbeat |
| 14 | `title`, `s_fark` | 27.00 | 35.00 | 1.9 | `title` opens like the eye; "Farkındalık tek taraflı değildir" types where the game's tagline sits (27.25) |
| 14 | `menu`, `c_tercih` | 28.90 | 36.90 | 2.5 | glitch cut to `menu_roles` from 2.4 s ("Devlet" hovered at 29.4); TERCİH ET at 29.3 |
| 15-16 | `globe2`, `s_dunya`, `s_count` | 31.40 | 39.40 | 3.5 | `globe_spin2`; "Dünyanın dört bir yanından" + "3 afet senaryosu" (digit slot-roll) |
| 17-18 | `bunny`, `s_easter` | 34.90 | 42.90 | 3.5 | pixelate into the pixel-art egg; it cracks, the bunny pops out (36.3); "Belki bir de easter egg, kim bilir…" |
| 19 | `c_aaa`, `s_yok`, `logo` | 38.40 | 46.40 | 4.2 | "AAA" big and calm like a game label; "yok yok" types on (39.55); "3play" lands (40.7) |
| 19 | `c_fark` | 42.60 | 50.60 | 2.4 | FARK ET, CRT power-off at 44.3, black from 45.0 |
| 20 | `team`, `end` | 45.30 | 53.30 | 5.1 | EMEĞİ GEÇENLER, the four portraits and names (Mehmet Yiğit Keskin, Sude İlayda Mete, Burcu Baran, İrem Altunsöğüt); fade to black at 49.8, black to 50.4 |

Final film: 8.0 s intro + 50.4 s film = 58.4 s.

### Sound

`film.html` also holds the mix plan, next to the picture it belongs to: `MUSIC` (one bed: the menu music M1 from
134.35 s, so its own swells land on the diorama and on the logo, with a dB curve), `STEMS` (the game sound recorded
with a clip, placed under its row) and `SFX` (one row per cue, T numbers as in `docs/audio.md`). Every time is derived
from the `TL` rows. `render.mjs` writes the plan in final-film seconds to `export/video/film_audio.json` (also on a
`--still` run). `mix.py` cuts every sound (trim, loop, tempo for the 1.5x lock clip, fades), measures it (EBU R128)
and sets its gain to the planned loudness (`lu`) or peak (`peak`), caps hard transients per layer (`ceil`), sums them
and masters to -14 LUFS integrated with a 4x oversampled -2.5 dBTP limiter (no compressor; about -1.9 dBTP after AAC). It prints the loudness of
each cue and of the master. Files, trims and levels: `assets/audio/trailer/README.md`; cue list: `docs/audio.md`
("Pitch film").

The visual cue sheet (heartbeats, cuts, cards) is still written to `export/video/film_cues.json` on every render.

### Godot clips and swapping one

Clips live in `export/video/clips/<name>/%05d.png` (1920x1080, 60 fps) with `clip.json` `{ "frames": N }` and
`clip.wav`. Numbering may start at 00000 or 00001; the page detects which. A clip with no `clip.json` draws a labelled
PLACEHOLDER, so the film always renders. A clip that is too short holds its last frame. Frame shown =
`in + (t - start) * speed`, in seconds × 60; `mix.py` cuts the clip's sound the same way.

To swap a clip:
1. Add its scripted play to `capture.gd` and capture it with `capture.sh` (PNG sequence + `clip.json` + `clip.wav`).
2. In `TL`, point the row at it and set `in` to the best moment. Later rows do not shift by themselves: move their
   `start` too (their sounds follow).
3. If the place changes, also edit the caption in `drawScene` and the card text.
4. Render stills around the cut, then the full film, `assemble.sh` and `mix.py --mux`.

For `globe_lock_io`, set `in`/`speed` so that the game's crosshair closes `lock` seconds after the row start (now:
clip 4.67 s = 1.6 + 1.5 × 2.05). Set `target` to the Indian Ocean's screen position in the locked frame (frame
centre). `hud: "brackets"` draws only corner brackets and a lock pulse, because the clip has the game's own crosshair
and readout. `hud: "full"` adds our own crosshair, rings and a typed readout (HEDEF KİLİTLENDİ, coordinates) for a
clip without the game's lock UI.

Current in-points: the diorama starts at 0.9 s (after the game's fly-in). `fener_mini` starts at 0.45 s, so the
whistle is heard in the dark before the lamp clicks on. `io_mini` starts at 8.0 s: the wall is already rising, it
breaks at clip 11.0 s (`hit: 3.0`). `title` starts at 0.6 s (logo in, buttons fading in). In `menu_roles` (from 2.4 s),
"Devlet" is hovered right under TERCİH ET.

The 3026 solar flare stays out of the film: it is the easter egg the bunny step teases.
