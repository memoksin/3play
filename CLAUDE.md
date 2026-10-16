# 3play

Game jam. Theme: disaster awareness. Engine: Godot (latest stable).

## Concept

- 3D globe start screen. Picks place + era, drops player into a real disaster (1999 Gölcük, Black Death...).
- Two perspectives: state, citizen. Finish state first. Citizen only if time allows.
- Some disasters give no warning. Some give warning + prep time.
- Easter egg: globe glitches once, jumps 1000-2000 years ahead, futuristic disaster.
- Dimensions: globe = 4D (time), player = 3D, scenarios/minigames = 2D.
- Closing line: "life has dimensions we cannot see".

## Defaults

- Jam workflow: `game-jam-mode` skill (`.claude/skills/game-jam-mode/`). Use by default for planning and scope calls.
- Godot work: `gd` plugin (`gd@godot-gamedev`, from `Zate/cc-godot`). Use by default. Approve the marketplace prompt on first open.
- Crew: `cw-crew` plugin (`cw-crew@cw-crew`, from `memoksin/cw-crew`). Enabled for everyone. Same prompt on first open.
- Sprites: `sprite` skill (`.claude/skills/sprite/`).

## Git

- `main`: always playable, polished. Protected. Merge from `dev` only, owner approval.
- `dev`: integration. PRs from `feat/*`.
- PRs to `dev` auto-merge on open (`.github/workflows/automerge.yml`, non-draft only). Open one only when the task is done and verified (tests pass, screenshots checked). Work in progress: push the branch or open a draft PR.
- Never push to `main` or `dev` directly.
- Never add Claude as co-author or collaborator: no `Co-Authored-By` trailer, no "Generated with Claude" line in commits or PRs.
- Sync: `git pull --rebase` at session start. Push + update issue when a task is done.

## Tasks

- GitHub Issues only. Labels: `status:todo|doing|done`, `role:*`.
- Agent messaging: issue comments. `SessionStart` hook names each agent and arms the inbox. Send only via `.claude/hooks/send.sh`.
- Roles: TBD.

## Assets

- Only CC0 or jam-safe licenses.
- Every asset needs a line in `assets/CREDITS.md`: source + license.
- Jam rule: every ready-made source and every AI use must be declared, or we are disqualified. Log it in `assets/CREDITS.md` the moment you use it, not at submission.
  - Ready-made: category, what, author, link, license, where used. Includes references (data, palettes, photos used as reference).
  - AI: category, tool, purpose, where used.
  - Categories: visual, audio, code, text, other.
