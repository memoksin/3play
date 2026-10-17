# Run instructions (rule A.3) - DRAFT

Owner: burcubaran22 (issue #19). Items marked `CHECK` need a person with the game to confirm before upload (Sun 12:00).

## Platform

- Windows 10 or 11, 64-bit. Download the ZIP, extract it, double-click `3play.exe`. No installer, no internet needed.
- A graphics card with Vulkan or OpenGL 3.3 support (any laptop from the last 8 years). `CHECK` minimum spec on a real Windows PC.
- Window opens maximized (1280x720 base size). F11 toggles fullscreen (also in Settings). `CHECK` the key.
- Mouse and keyboard. Sound on is recommended.

## How to start and what happens

1. Pick a language on the first launch.
2. Pick a role: **State** or **Citizen**.
3. The globe spins and locks on a real disaster. Click or Space skips the spin.
4. A short intro scene shows the place and year, then the minigame starts.
5. A result card shows the score and the real facts. Play again or return to the menu.

A run takes about 3 minutes. Which disaster you get depends on your role and on what you played before (it alternates).

## Controls

| Where | Controls |
|---|---|
| Menus and cards | Mouse. Enter presses the main button. |
| Globe | Drag to turn the globe. Click or Space skips to the lock. |
| Pause (any time in a run) | Esc opens the pause menu (4 buttons). |
| Indian Ocean (Connect) | Click a pipe tile to rotate it 90 degrees. Mouse only. |
| Solar flare 3026 (Beam) | Click a satellite = turn +45 degrees. Right-click or Shift+click = back. Mouse wheel turns either way. Countdown phase keyboard: Tab / Shift+Tab or arrows pick, E / Space / Enter turn, Q turns back, F fires. |
| Black Saturday (Fire, first person) | W A S D or arrows move, mouse looks (arrow keys Left/Right also turn), Shift run, Space jump, E / F / Enter interact (pick up, cut, attach, turn). |
| Kahramanmaras (Fener) | `CHECK` controls of the new Fener build (memoksin). |
| Settings (main menu) | Mouse sensitivity, invert Y, volumes, fullscreen, language. |

## Known issues

`CHECK` with memoksin and sudeimete. Candidates seen during development:

- The window is large on first start; resize or use fullscreen if the result card looks cut off (issue #165, solar flare result card clipped on the left in a maximized window).
- Some sounds are still being added (audio PR #173).
- The first run may take a few seconds to load.

## Source and licences

- Source code: the public repository (link in the submission form). The build matches the repo source.
- Assets and AI usage: `assets/CREDITS.md` (ready-made assets and the AI declaration).
