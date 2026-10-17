# Project memory

Shared by every agent. Loaded via CLAUDE.md. Hard cap 40 lines; one line per fact.

## Contracts
- Flow: scenes end with `Game.next()`; minigames end with `Game.finish_minigame(saved, total, extra)`; a scene run alone (F6) calls `Game.ensure_disaster(&"citizen"|&"state")` first.
- Data: disaster facts in `data/disasters/*.tres`; minigame rules + textures in its skin `.tres` (`Disaster.skin`). New art = set a skin field, no code change.
- Pick: `Game.POOL` per role; `start()` takes the disaster least played on this machine (`user://played.cfg`, ties random). F6 `ensure_disaster` uses fixed `Game.PICK`. Tests set `Game.store_path = ""`. 2.5D reform (#128): State: Indian Ocean (Connect, 2.5D art #122 in `scenes/minigames/connect/`) or solar flare 3026 (Beam #124: `scenes/minigames/beam.tscn`, swap placeholder pieces via `BeamSkin` *_scene fields); citizen: Kahramanmaras (Fener #123: `scenes/minigames/fener.tscn`, map `scripts/fener_map.gd`, swap placeholder people via `FenerSkin`/`FenerPerson` figure fields; the old Fit skin stays for Fit tests only). Fire: Black Saturday (`black_saturday.tres`, minigame `fire`, first person, #125).
- Beam (#124) plays the art pilot's lane view in 3D: skin `solar_flare_beam.tres` -> `scenes/minigames/beam/sf/` (pieces stay Node2D, model = Node3D child at `world`; clicks = ray vs plane y=2, `sf/layout.gd`). Keep the HUD off the Sun band and the cities (`tests/test_beam3d.gd`).
- Owners (#128): minigames, art reform, globe, `Game` = memoksin; UI/UX polish, theme, result card = iremaltunsgt; sound integration, diorama = sudeimete; assets, sounds, card text, submission = burcubaran22; fire minigame design = burcubaran22 + sudeimete. Ask on the issue before editing another owner's scene.

- 2.5D art: models only from `tools/models/` (headless Blender, `python3 tools/models/build.py`); camera, light, palette rules in `docs/art/style-2.5d.md` (#121).
- Fener people: `assets/3d/kahramanmaras/meshy_<name>.glb` (Meshy mesh, Quaternius UAL clips, in place); clip list and the move speed per clip (else feet slide) in `tools/models/meshy/README.md`.
- Story progress (#127): Story.record() on the result card writes user://progress.cfg (done, best, badge = saved >= half); tests/tools that reach result.tscn set load("res://scripts/story.gd").progress_path = "". Badge = Disaster.badge (PackedScene, models in tools/models/badges/, 3026 = scenes/badges/badge_solar_flare.tscn).
- Voice autoload (scripts/voice.gd): Voice.say(key) types a prologue-style line; on the glitch run it holds the globe (globe.paused) after the 3026 lock (coords_typing_finished + globe.future > 0), agreed with memoksin on #128.
## Gotchas
- PRs to `dev` auto-merge and `Closes #N` never fires there: close the issue by hand after merge.
- After adding assets or editing `locale/strings.csv`, run `godot --headless --path . --import`, or new keys show raw.
- Test scripts (`tests/*.gd`) must `quit(1)` on every failure path and have a frame cap; a missed `quit()` leaves Godot hanging.
- Window opens maximized: screenshot tools save at window size (not 1280x720). Compare shots by downscaling.
- The editor rewrites `project.godot` (header, drops default values) and may switch `assets/globe/*` imports to VRAM compression: keep `compress/mode=0`, don't commit that churn.
- Weather/time of a place = `Disaster.atmosphere` (scripts/atmosphere.gd: sun, ambient, sky, haze/fog, exposure): diorama.gd and the minigame world both apply it (Indian Ocean: diorama + Connect). Change the look there, not in the set or world scenes.
- Globe sun comes from `Disaster.utc` (real event time): Kahramanmaras locks at night, Sumatra in the morning. Intended.
- Cloud sessions (claude.ai/code, e.g. Burcu on tablet): `gh` GraphQL commands (`gh issue/pr/repo ...`) get HTTP 403. Use `gh api` REST; the hooks already do.
- Night shift: memoksin hands tasks to sleeping teammates' sessions on #115. Work in a worktree from origin/dev (never the owner's tree), DRAFT PRs only, report ACK/PROGRESS/QUESTION/DONE there with send.sh.
- After editing `locale/strings.csv`, run `godot --headless --path . --import` then `godot --headless --path . -s tools/audit_strings.gd` (exit 1 on a missing key, empty text, duplicate or %s mismatch). Always append a row on a new line: the file has no final newline.
- Fener lights (#123): Compatibility lights a mesh with 8 omni + 8 spot max, paired by AABB (`scripts/fener_lights.gd`); a new light or big mesh must keep `tests/test_fener_lights.gd` green (ground splits itself into tiles, the slab is 8 m tiles via `tile=` in `tools/models/lib.py`).
- Fener collision (#123): the player is blocked by `FenerMap.WALK` (per-model body-height shapes measured from the mesh, exact yaw), not by `FOOT` (mass for light/fade/shock/routes). New or moved model: `tools/fener_footprints.gd` (`gen=1` drafts the entry), keep `tests/test_fener_walk.gd` green.
