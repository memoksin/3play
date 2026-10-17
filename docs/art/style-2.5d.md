# 3play 2.5D style (#121)

One look for every minigame. Pilot: `scenes/art_pilot/kahramanmaras_street.tscn` (Kahramanmaras, 6 Feb 2023, night after 04:17).
Shots: `godot --path . -s res://tools/art_pilot_shots.gd -- [cam=CameraPlay]` -> `export/shots/`.

## 1. The world slab
- Every minigame is played on a **world slab**: a block of the place, cut out of the Earth, floating in the void. It continues the globe dive: the player zooms from the globe into a piece of it.
- The cut faces show the ground in section (scenario's own strata, pipes, stones, roots), rocks hang under it, 3-5 small earth chunks drift around it (`earth_chunk.glb`, slow bob).
- The disaster marks the slab itself where it can (Kahramanmaras: the fault runs through the slab, right piece dropped 0.35 m).
- Size: set by each game's playfield, not by the style (the pilot's 36 x 26 m is only a style test). 1 unit = 1 m, people 1.75 m.

## 2. Camera (fixed, never orbits in play)
- Perspective, **FOV 26 (vertical), pitch -40, yaw -22** (3/4 view: front cut + left cut visible). Telephoto = miniature feel.
- Hero framing (intro/result): whole slab + void margin. Play framing: same angle, closer (`CameraPlay`). Angle never changes; distance does.
- A big slab is fine: in play the camera may pan/follow at the same angle to cover it.
- Model fronts face Godot +Z (Blender -Y).

## 3. Models (`tools/models/`, Blender, headless)
- Built from code only: `python3 tools/models/build.py [name]`. Shared kit `tools/models/lib.py`, one script per model in `tools/models/<set>/`.
- Chunky low-poly, **every edge bevelled** (catches light like a painted miniature), slightly exaggerated details that tell the place (kiremit roofs, solar water heaters, stove pipes, kepenk shutters, TR plates, Toplanma Alani sign).
- Colour = palette entry (`lib.PAL`), never free colours. Albedo between ~6% and ~85% value.
- One baked texture set per model: palette x ambient occlusion x convex edge highlight x weather dust (snow on up faces). Roughness baked into metallicRoughness. **Light is never baked**: a model works under any scene light.
- Glowing parts (fire, lamps, lit windows, torch lens) are separate unbaked emissive materials.
- Budget: buildings ~40k tris / 2048 tex, vehicles ~12k / 1024, people ~3.5k / 512, slab ~30k / 4096.
- Textures ship as JPEG inside the GLB. Set `gltf/embedded_image_handling=2` (Basis Universal) in each new `.glb.import`: no extracted PNGs in the repo, VRAM-compressed at runtime. Never `3` (uncompressed: the 4096 slab alone is ~100 MB VRAM). When a slab enters the game flow, rerun `tools/perf.gd` on its transition.
- Damage is shown, not gore: shear X cracks, spalled plaster showing brick, pancaked slabs, rebar, household things in the rubble.

## 4. Light
- Key: one directional (moon/sun) with soft shadows. Night: cool blue-white 0.3. Ambient: flat colour (sky-tinted), low (0.22 night).
- **Story lights carry the scene**: warm practicals (fire 1.0/0.52/0.18, torch, headlights, lit windows) make the pools the player reads. Gameplay-relevant things are the brightest and warmest things on screen.
- One accent colour light per scene (here the red/blue emergency beacon).
- Fake volumetric beams (`scenes/style/light_beam.gdshader`) for torches and headlights.
- Compatibility renderer: max 8 omni/spot lights touching one mesh (the slab). Plan lights inside that.

## 5. Image
- Tonemap AgX, glow on (threshold 0.9, bloom 0.04), contrast 1.08, saturation 1.1, depth fog into the void colour.
- Void: `scenes/style/void_sky.gdshader` (dark gradient + soft radial glow behind the slab so its silhouette separates).
- Post pass `scenes/style/post_25d.gdshader` on a CanvasLayer: tilt-shift blur at top/bottom, vignette, cool-shadow/warm-light split tone, fine grain.
- Particles: `scenes/style/soft_particle.gdshader` (lit soft dots: snow, smoke, sparks, catch the scene lights).

## 6. Per-scenario knobs (keep everything else)
Palette subset, void colour, key light colour/time of day, weather dust (snow / ash / sand / wet), strata of the cut. Example: Indian Ocean = morning, warm key, wet dust, sand + coral strata, water cut in section.
