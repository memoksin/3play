# Pitch video segments

Each segment is a self-contained HTML page (`tools/video/<segment>.html`) that draws one frame with
`window.renderAt(t)`. It is a pure function of `t`: no wall clock, no requestAnimationFrame state, randomness only from
seeded PRNGs. So frame N = `renderAt(N / 60)` comes out the same on every render. The pages draw pictures only; the
sound is mixed afterwards by `mix.py` from the cue tables in `film.html`.

| Segment | Length | Output |
|---|---|---|
| `intro_stack` | 6.5 s, 390 frames | `export/video/intro_stack.mp4` |
| `film` | 53.95 s, 3237 frames | `export/video/film.mp4` (storyboard steps 5-19, plays after the approved intro) |

## The whole pitch film, start to finish

```sh
for c in kahr_diorama fener_mini globe_full io_mini menu_roles globe_spin2 fire_mini; do
  bash tools/video/capture.sh $c                 # Godot clips + their game sound (~2-6 min each)
done
node tools/video/render.mjs film                 # ~1 h: export/video/film.mp4 + film_cues.json + film_audio.json
bash tools/video/assemble.sh                     # approved intro (first 2 s cut) + film -> export/video/pitch_film.mp4
python3 tools/video/mix.py --mux --web           # sound -> pitch_audio.wav, pitch.mp4 and the web copy pitch_web.mp4
```

`export/video/pitch.mp4` is the deliverable: H.264 1920x1080 60 fps + AAC 48 kHz, 59.95 s, -14 LUFS (~45 Mb/s).
`export/video/pitch_web.mp4` is the same film for the web: same picture and sound, 2-pass x264 at 5.8 Mb/s + AAC
192 kb/s, about 45 MB (`WEB_KBPS` in `mix.py`).
After a change late in the film, `render.mjs film --resume` keeps the frames already in `export/video/frames/film/`
and renders only the missing ones: delete the frames from the first changed one on, then resume.
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

Frozen copy: `export/video/approved/intro_stack_v2_cut.mp4` (8.0 s, 1920x1080, 60 fps). The pitch film plays it from
2.0 s (`INTRO_CUT` in `film.html` and `assemble.sh`): `assemble.sh` writes the trimmed copy, with a 0.3 s fade-in,
to `export/video/intro_cut.mp4` and leaves the approved file untouched.

## Godot clips

`bash tools/video/capture.sh <clip>` plays the real scenes by scripted input (`tools/video/capture.gd`, locale tr, Movie
Maker) and writes `export/video/clips/<clip>/%05d.png` (1920x1080, 60 fps), `clip.json` and `clip.wav`: the game's own
sound of exactly those frames (48 kHz stereo, the Music bus muted: the film has one music bed of its own). Clips:

| Clip | Length | What is played |
|---|---|---|
| `kahr_diorama` | 7.5 s | the Kahramanmaras diorama, the intro card hidden, framed closer |
| `fener_mini` | 8.7 s | Fener at night, staged on the avenue (seed 2): lamp off, the mother's whistle, the lamp clicks on at 1.25 s, the beam finds her (the game's slow motion and name), she, the sister and the grandfather follow the player across the street to the ambulance |
| `globe_full` | 8.4 s | the game's whole globe animation in one take: the spin through the years, the lock on the Indian Ocean (crosshair closes at ~4.95 s), the zoom to Sumatra and the fade |
| `io_mini` | 19.4 s | Connect from 13 s before the wave: the pipes turned (they lock at 1.1 and 2.4 s), one line left open; the sea draws back, the swell rises into a wall and breaks over the whole town at ~13.15 s, the flood fills the pipes |
| `menu_roles` | 7.0 s | the role menu: prompt, hover on Devlet (~2.8 s), then Vatandaş (~4.8 s) |
| `globe_spin2` | 5.0 s | a second spin from another angle |
| `fire_mini` | 5.5 s | Black Saturday as the citizen, first person, the hands as they are now: the wire cutters cut the fence ties (cut at 1.25 s), step back, the kangaroos run out through the gap (~3.6-5.0 s) |

`globe_spin`, `globe_lock_io` and `title` can still be captured (older cut); the film no longer uses them.

## Film body: `film.html` (storyboard steps 5-19)

`film.html` is the rest of the pitch film after the approved intro. It works like `intro_stack`, with one difference:
`renderAt(t)` returns a Promise, because it loads Godot gameplay frames on demand. `render.mjs` waits for it.
Title cards (`TAHMİN ET`, `KEŞFET`, `MÜDAHALE ET`, `TERCİH ET`, `FARK ET`) reuse the STACK PRESENTS type-on: glitch
split, white-hot arrival, block cursor, side rules. The verb is amber and the closing "ET" is teal. `AAA` is the same
card with `calm: true`: all amber, a soft arrival, no jitter, no chroma split, no shake, and no cursor (so it does not
look like another letter is coming). The side rules sit at the same distance left and right of the text. A small
teal "GAME" (`GAME`) sits under "AAA" and stays, unchanged, under "3play". Statements (`s_*` rows) are
smaller, in the fg colour, and `*stars*` mark the amber words. The `logo` row draws the game's logo (`ui/logo.tscn`:
VT323 "3play", a red copy left and a blue copy right) landing with a soft flash. The film has no developers part: it
ends on FARK ET, which does not fade but is closed by the CRT power-off. The post pass matches the intro: bloom,
chromatic aberration, grain, vignette. On top of that it adds glitch cuts, zoom blur, pixelation and the CRT power-off
that ends the film (`CRT`, the last 0.65 s of FARK ET).

```sh
node tools/video/render.mjs film --still 9.5,19.0,28.8,33.6,39.6,51.5   # stills in export/video/stills/film/
node tools/video/render.mjs film                                 # ~1 h: export/video/film.mp4 (+ film_cues.json, film_audio.json)
node tools/video/render.mjs film --resume                        # only the frames missing in export/video/frames/film/
node tools/video/render.mjs film --clips /abs/path/to/clips      # clips from another folder (served at /__clips/)
bash tools/video/assemble.sh                                     # approved intro + film -> export/video/pitch_film.mp4
INTRO=/abs/path/intro_stack_v2_cut.mp4 bash tools/video/assemble.sh   # when approved/ lives in another checkout
python3 tools/video/mix.py --mux --web                           # the sound -> export/video/pitch.mp4 + pitch_web.mp4
python3 tools/video/contact_sheet.py export/video/stills/pitch_sheet.png export/video/stills/film/*.png
```

`assemble.sh` never writes into `approved/`. It cuts the intro's first `INTRO_CUT` s (default 2.0) into
`export/video/intro_cut.mp4`, then joins the two parts by stream copy when their codec, profile, size,
pix_fmt and fps match and the joined file decodes cleanly. Otherwise, or with `MODE=reencode`, it re-encodes once with
the render settings (H.264 crf 16 slow, yuv420p, 60 fps, no audio). It fails if the result is longer than 60 s.

### Timeline table

All timing lives in the `TL` table at the top of `film.html`. Times are film-local seconds. In the final film add
6.0 s (`INTRO_LEN`: the 8.0 s approved intro minus `INTRO_CUT` 2.0). Each row has `step`, `id`, `start`, `len`, and
either `clip` + `in` (clip in-point in seconds, optional `speed`) or `text`. Effects and sounds read their times from
the rows, so changing a row retimes everything tied to it. `SCENARIO_COUNT` (step 16) is a single constant.

| Step | Row | Film s | Final s | Len | Content |
|---|---|---|---|---|---|
| - | intro | - | 0.00 | 6.0 | the approved intro from 2.0 s: rain, lightning, STACK PRESENTS, push into the eye |
| 5 | `dark`, `s_hayat` | 0.00 | 6.00 | 4.2 | near-black, heartbeat glow, voice echo rings; "Hayatın göremediğimiz boyutları vardır" at 7.8 |
| 6 | `diorama` | 4.20 | 10.20 | 3.9 | eye-shaped tear of light opens on `kahr_diorama`, extra snow, place caption |
| 7 | `c_tahmin` | 5.90 | 11.90 | 2.2 | TAHMİN ET over the diorama |
| 8 | `fener` | 8.10 | 14.10 | 6.8 | `fener_mini` from 0.45 s (glitch cut in): a whistle in the dark, the lamp clicks on at 14.9, "ANNE" found, the family follows to the ambulance; zoom-blur whip out |
| 9 | `globe`, `c_kesfet` | 14.90 | 20.90 | 3.8 | `globe_full` from 0.15 s at 1.1x: the spin; KEŞFET at 21.5 |
| 10 | `lock` | 18.70 | 24.70 | 3.0 | the same take, no cut (clip 4.33 s on, 1.1x): the game's crosshair locks on the Indian Ocean at 25.24 (our brackets lock with it), the zoom to Sumatra, extra push + teal flash from +2.6 |
| 11 | `c_mudahale` | 21.70 | 27.70 | 1.8 | MÜDAHALE ET on dark water |
| 12 | `io_a` | 23.50 | 29.50 | 2.5 | `io_mini` from 2.2 s at 2.9x (glitch cut in), slow push to the beach: the pipes lock, the sea draws back |
| 12 | `io_b` | 26.00 | 32.00 | 5.1 | the same take from 9.45 s at 1.25x: the wall rises, breaks over the town at 34.96 (`hit`), the town floods; hard cut out |
| 13 | `black` | 31.10 | 37.10 | 0.6 | black, one faint heartbeat |
| 14 | `menu`, `s_fark`, `c_tercih` | 31.70 | 37.70 | 4.3 | `menu_roles` from 1.7 s opens like the eye; "Farkındalık tek taraflı değildir" at 38.0 (typed by 39.0, held to 40.5); TERCİH ET at 40.45 ("Devlet" hovered at 38.8, "Vatandaş" at 40.8) |
| 15-16 | `globe2`, `s_dunya`, `s_count` | 36.00 | 42.00 | 3.2 | `globe_spin2` at 1.1x (glitch cut in); "Dünyanın dört bir yanından" + "3 afet senaryosu" (digit slot-roll) |
| 16 | `fire_a`, `fire_b` | 39.20 | 45.20 | 2.2 | `fire_mini` (glitch cut in): the cutters cut the fence (from 0.35 s at 1.15x), hard cut to the kangaroos running out (from 3.55 s at 1.15x) at 46.2; caption VICTORIA, AVUSTRALYA · 2009 |
| 17-18 | `bunny`, `s_easter` | 41.40 | 47.40 | 3.1 | pixelate into the pixel-art egg; it cracks faster than before (its cracks on the normal-speed sound), the bunny pops out (48.37); "Belki bir de easter egg, kim bilir…" |
| 19 | `c_aaa`, `s_yok` | 44.50 | 50.50 | 2.45 | "AAA" with a small "GAME" under it, calm; it settles, then "yok yok" types on (51.95) |
| 19 | `logo` | 46.95 | 52.95 | 2.9 | "3play" lands, the same "GAME" under it, held |
| 19 | `c_fark`, `end` | 49.85 | 55.85 | 4.1 | FARK ET, held; CRT power-off at 58.8, black from 59.45 |

Final film: 6.0 s intro + 53.95 s film = 59.95 s.

### Sound

`film.html` also holds the mix plan, next to the picture it belongs to: `MUSIC` (one bed: the menu music M1 from
129.8 s, so its own swells land on Fener's lamp and at 51.3 under "yok yok", with a dB curve), `STEMS` (the game sound recorded
with a clip, placed under its row) and `SFX` (one row per cue, T numbers as in `docs/audio.md`). Every time is derived
from the `TL` rows. `render.mjs` writes the plan in final-film seconds to `export/video/film_audio.json` (also on a
`--still` run). `mix.py` cuts every sound (trim, loop, tempo for the sped-up clips, fades), measures it (EBU R128)
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

For the globe, `globe` and `lock` play one take (`globe_full`) back to back: `lock.in` = `globe.in` +
`globe.len` × `speed`, so there is no cut. Set `lock` so that the game's crosshair closes `lock` seconds after the row
start (now: clip 4.92 s = 4.33 + 1.1 × 0.54). Set `target` to the Indian Ocean's screen position in the locked frame
(frame centre). `hud: "brackets"` draws only corner brackets and a lock pulse, because the clip has the game's own
crosshair and readout. `hud: "full"` adds our own crosshair, rings and a typed readout (HEDEF KİLİTLENDİ, coordinates)
for a clip without the game's lock UI.

Current in-points: the diorama starts at 0.9 s (after the game's fly-in). `fener_mini` starts at 0.45 s, so the
whistle is heard in the dark before the lamp clicks on. `io_mini` plays twice from one take: `io_a` 2.2-9.45 s fast,
`io_b` from 9.45 s near real speed; the wave breaks at clip 13.15 s (`hit: 2.96`). In `menu_roles` (from 1.7 s),
"Devlet" is hovered under the statement and "Vatandaş" under TERCİH ET.

The fire shot is one capture, `fire_mini`, so it can be swapped alone (for example once the first-person hands are
improved): `bash tools/video/capture.sh fire_mini`, check that the fence cut is still in `fire_a` (clip 0.35-1.5 s)
and the kangaroos in `fire_b` (clip 3.55-4.93 s), adjust the two `in` values if not, delete frames 02340-02483 of
`export/video/frames/film/` (film 39.0-41.4 s: the glitch cut in to the pixelate out), render with `--resume`, then
`assemble.sh` and `mix.py --mux --web`.

The 3026 solar flare stays out of the film: it is the easter egg the bunny step teases.
