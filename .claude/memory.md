# Project memory

Shared by every agent. Loaded via CLAUDE.md. Hard cap 40 lines; one line per fact.

## Contracts
- Flow: scenes end with `Game.next()`; minigames end with `Game.finish_minigame(saved, total, extra)`; a scene run alone (F6) calls `Game.ensure_disaster(&"citizen"|&"state")` first.
- Data: disaster facts in `data/disasters/*.tres`; minigame rules + textures in its skin `.tres` (`Disaster.skin`). New art = set a skin field, no code change.
- Pick: `Game.POOL` per role; `start()` takes the disaster least played on this machine (`user://played.cfg`, ties random). F6 `ensure_disaster` uses fixed `Game.PICK`. Tests set `Game.store_path = ""`. State: Indian Ocean (Connect, spec in `docs/minigames/`) or solar flare 3026 (Fit skin); citizen: Kahramanmaras (Fit).
- Owners: globe, Fit, Connect, `Game` = memoksin; theme, result card, intro text = iremaltunsgt; sprites, diorama = sudeimete; specs, card text = burcubaran22. Ask on the issue before editing another owner's scene.

## Gotchas
- PRs to `dev` auto-merge and `Closes #N` never fires there: close the issue by hand after merge.
- After adding assets or editing `locale/strings.csv`, run `godot --headless --path . --import`, or new keys show raw.
- Test scripts (`tests/*.gd`) must `quit(1)` on every failure path and have a frame cap; a missed `quit()` leaves Godot hanging.
- Window opens maximized: screenshot tools save at window size (not 1280x720). Compare shots by downscaling.
- The editor rewrites `project.godot` (header, drops default values) and may switch `assets/globe/*` imports to VRAM compression: keep `compress/mode=0`, don't commit that churn.
- Globe sun comes from `Disaster.utc` (real event time): Kahramanmaras locks at night, Sumatra in the morning. Intended.
- Cloud sessions (claude.ai/code, e.g. Burcu on tablet): `gh` GraphQL commands (`gh issue/pr/repo ...`) get HTTP 403. Use `gh api` REST; the hooks already do.
- Night shift: memoksin hands tasks to sleeping teammates' sessions on #115. Work in a worktree from origin/dev (never the owner's tree), DRAFT PRs only, report ACK/PROGRESS/QUESTION/DONE there with send.sh.
