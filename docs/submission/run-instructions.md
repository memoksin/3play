# Run instructions (rule A.3) - DRAFT

Owner: burcubaran22 (issue #19). Items marked `CHECK` need a person with the game to confirm before upload (Sun 12:00).

## Platform

- Windows 10 or 11, 64-bit. Download the ZIP, extract it, double-click `3play.exe`. No installer, no internet needed.
- A graphics card with Vulkan or OpenGL 3.3 support (any laptop from the last 8 years). `CHECK` minimum spec on a real Windows PC.
- The game opens in fullscreen on the first start (1280x720 base size, scaled with the aspect kept). Fullscreen can be turned off in Settings. The language is Turkish by default and can be changed on the first screen or in Settings.
- Mouse and keyboard. Sound on is recommended.

## How to start and what happens

1. Pick a language on the first launch (Turkish or English).
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
| Kahramanmaras (Fener) | W A S D or arrows walk, the mouse aims the torch, hold the left mouse button to walk to the pointer, Space or F turns the torch on and off. |
| Settings (main menu) | Language, master / music / effects volume, mouse sensitivity, invert Y, fullscreen, replay the prologue, Back, Quit. |

## Known issues

`CHECK` with memoksin and sudeimete before upload. Current list:

- The first start may take a few seconds to load the globe and scenes.
- The Kahramanmaras (Fener) minigame was still being tuned at the time of writing. `CHECK` its final state.
- Not tested on every graphics card. `CHECK` the result of the Windows test (issues #51, #9).

## Source and licences

- Source code: the public repository (link in the submission form). The build matches the repo source.
- Assets and AI usage: `assets/CREDITS.md` (ready-made assets and the AI declaration).
