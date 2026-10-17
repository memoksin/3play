# Pitch video segments

Each segment is a self-contained HTML page (`tools/video/<segment>.html`) that draws one frame with
`window.renderAt(t)`. It is a pure function of `t`: no wall clock, no requestAnimationFrame state, randomness only from
seeded PRNGs. So frame N = `renderAt(N / 60)` comes out the same on every render. Visuals only, no audio.
No Godot is involved.

| Segment | Length | Output |
|---|---|---|
| `intro_stack` | 6.5 s, 390 frames | `export/video/intro_stack.mp4` |

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
