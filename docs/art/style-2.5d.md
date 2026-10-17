# 3play 2.5D style (#121)

One look for every minigame. Pilot: `scenes/art_pilot/kahramanmaras_street.tscn` (Kahramanmaras, 6 Feb 2023, night after 04:17).
Shots: `godot --path . -s res://tools/art_pilot_shots.gd -- [cam=CameraPlay]` -> `export/shots/`.

## 1. The world slab
- Every minigame is played on a **world slab**: a block of the place, cut out of the Earth, floating in the void. It continues the globe dive: the player zooms from the globe into a piece of it.
- The cut faces show the ground in section (scenario's own strata, pipes, stones, roots), rocks hang under it, 3-5 small earth chunks drift around it (`earth_chunk.glb`, slow bob).
- The disaster marks the slab itself where it can (Kahramanmaras: the fault runs through the slab, right piece dropped 0.35 m).
- Size: set by each game's playfield, not by the style (the pilot's 36 x 26 m is only a style test). 1 unit = 1 m, people 1.75 m.

## 2. Camera (fixed, never orbits in play)
- Perspective, **FOV 26 (vertical)**: telephoto = miniature feel. Never orbits.
- Hero framing (intro, opening shot, result, art shots): **pitch -40, yaw -22** (3/4 view: front cut + left cut visible), whole slab + void margin. This is the shared look across games.
- Play angle is chosen per game, for readability first. Default: the hero angle, closer (`CameraPlay`); a big slab may pan/follow at that angle.
- Looking square at the puzzle surface is allowed. Connect (#122) plays square to the front cut, where the grid lives (yaw 0 against the slab), from a little above and tilted 16° down (`play_pitch`): the grid reads as a flat board with a light perspective (rows about 8 % smaller from top to bottom), while the slab top and the village show a little. The game opens on the hero angle and glides into the play view (`scenes/minigames/connect/connect_world.gd`). Play distance: the slab fills the screen width and its deep body (`coast_slab.py` ZB) runs out of the bottom edge, so there is no void beside or under the board; in the hero view the body sinks into height fog. No floating chunks or hanging rocks there: the coast reads as part of the Earth. Light, sky and fog come from `Disaster.atmosphere`, shared with the diorama set, so the cut from the diorama keeps the same world. The play camera is a `Camera3D` frustum projection (`frustum_offset` = optional lens shift for framing); project/unproject with the same math as the render (`screen_of` / `_ray_dir` there), not `Camera3D.unproject_position`.
- Playfield on a cut face: turn that cut square to the camera yaw (slab node at yaw -22) and keep the side cuts on the world axes, so the footprint is a parallelogram; the hero view then shows the cut without a row tilt and the left cut still shows. Models on top keep world yaw 0. See `tools/models/indian_ocean/coast_slab.py`.
- No coplanar surfaces: cut pieces that share the front plane must not overlap (overlaps z-fight in game and bake dark AO patches), pieces whose top is the land surface drop their top and back faces (`open_top` in `coast_slab.py`), and nothing may run inside the slab body (it shows through the bevel grooves of the cut): clip water planes to where they lie over the land.
- Keep the HUD over void or background: frame the play view so gameplay things (here the four communities) stay clear of it.
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
