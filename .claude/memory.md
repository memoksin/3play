# Project memory

Shared by every agent. Loaded via CLAUDE.md. Hard cap 40 lines; one line per fact.

## Contracts
- Flow: scenes end with `Game.next()`; minigames end with `Game.finish_minigame(saved, total, extra)`; a scene run alone (F6) calls `Game.ensure_disaster(&"citizen"|&"state")` first.
- Data: disaster facts in `data/disasters/*.tres`; minigame rules + textures in its skin `.tres` (`Disaster.skin`). New art = set a skin field, no code change.
- Tier 1: citizen → Kahramanmaras (Fit), state → Indian Ocean (Connect: underground pipelines, final spec in `docs/minigames/`).
- Owners: globe, Fit, Connect, `Game` = memoksin; theme, result card, intro text = iremaltunsgt; sprites, diorama = sudeimete; specs, card text = burcubaran22. Ask on the issue before editing another owner's scene.

## Gotchas
- PRs to `dev` auto-merge and `Closes #N` never fires there: close the issue by hand after merge.
- After adding assets or editing `locale/strings.csv`, run `godot --headless --path . --import`, or new keys show raw.
- Test scripts (`tests/*.gd`) must `quit(1)` on every failure path and have a frame cap; a missed `quit()` leaves Godot hanging.
- Window opens maximized: screenshot tools save at window size (not 1280x720). Compare shots by downscaling.
- The editor rewrites `project.godot` (header, drops default values) and may switch `assets/globe/*` imports to VRAM compression: keep `compress/mode=0`, don't commit that churn.
- Globe sun comes from `Disaster.utc` (real event time): Kahramanmaras locks at night, Sumatra in the morning. Intended.
