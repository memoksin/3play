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

## Git

- `main`: always playable, polished. Protected. Merge from `dev` only, owner approval.
- `dev`: integration. PRs from `feat/*`.
- Never push to `main` or `dev` directly.
- Sync: `git pull --rebase` at session start. Push + update issue when a task is done.

## Tasks

- GitHub Issues only. Labels: `status:todo|doing|done`, `role:*`.
- Roles: TBD.

## Assets

- Only CC0 or jam-safe licenses.
- Every asset needs a line in `assets/CREDITS.md`: source + license.
