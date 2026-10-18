# Spec: Fire minigame, kangaroo farm (DRAFT)

Issue #125. Design by burcubaran22 (with sudeimete), built by memoksin after the spec.
Event: Black Saturday, Victoria, Australia, 7 Feb 2009 (place and tone to confirm). Role: Citizen.
Score, timer (90 s) and lose rule are decided. Items marked `OPEN` are not decided yet. Do not state anything in a result card text as a real fact until it is checked (`VERIFY`).

## Idea in one line

First person. You are on a fenced farm with a kangaroo pen while a bushfire comes. You go through a few marked tasks (exclamation marks), each one prepares the farm or opens an escape for the kangaroos, then you leave through the broken gate. Every task is a simple hands-on action.

## What the player sees and does, in order

1. **Opening shot (5.4 s):** the farm from above in the style's hero view, then the camera comes down to the farmer (the player) and into his eyes: first person. Space or a click skips it. See "Opening shot, task plate, markers" below.
2. **First person.** The player looks around. Two **exclamation marks** show the tasks.
3. **Task A, the fence:**
   - Run to the first exclamation mark. There are **wire cutters** (long-handled bolt cutters) on a chopping block: pick them up. (Was a knife; changed after the team playtest.)
   - A **fence** stands at the side: cut its wire ties. The panel falls into the yard, a gap opens, so the kangaroos have a way out.
   - Success sound (the player did it).
4. **Look around again.** Another exclamation mark.
5. **Task B, the hose and the fire:**
   - Run to it. A **hose** lies free on the ground, a **valve** is on the wall.
   - Attach the hose to the valve, turn the valve: water flows.
   - Look to the other side: a **small flame** has started **on the path to the exit**. Put it out with the hose so the way out stays open.
   - Success sound when it is out.
6. **Exit.** When all exclamation marks are done, the **exit gate** shows. The gate is broken, with a **pile of debris** in front. The player **jumps over the pile** (jump key) and leaves. End of the minigame.

## Lesson link (decided with memoksin, from sudeimete's note)

Black Saturday's main lesson is "leave early", not "stay and defend". So the tasks are about **opening ways out**, not about defending the farm: the fence opens a way out for the kangaroos, and the flame is put out only because it blocks the player's own way out. The card says: leave early, do not fight a fire you can leave.

## Controls (first person)

Move, look with the mouse, an **interact** key (pick up, cut, attach, turn), a **jump** key. Mouse and keyboard.

## Props (3D, simple)

Farm yard, fences on four sides, kangaroo pen with kangaroos, 2 exclamation markers, wire cutters, cuttable fence section, hose, wall with a valve, a small flame (and no flame afterwards), broken gate with a debris pile, sky and smoke.

## Score and ending (decided by burcubaran22)

- **Score = the tasks completed, plus leaving successfully.** Shown as "X/3 done": the fence cut, the flame put out, and the player got out through the gate (the third counts only if the player leaves in time). `OPEN`: exact wording on the card.
- **Time pressure = the view gets worse.** The total time is **90 s** (decided; the minigame budget is 60 to 90 s, and a first-time player in first person needs time to find the tasks). The smoke follows the clock: the first **10 s are clear**, then the smoke **thickens gradually**, and in the **last 10 s it is very dense**. The debris pile at the gate does **not** get worse. The pressure is that you see less and less, so leaving late is hard. This carries the "leave early" lesson of Black Saturday.
- **Lose:** the time runs out before the player has left (the view is almost gone). The tasks done before that still count in the score. Timer: 90 s total, decided.
- **Kangaroos:** after the player cuts the fence, **two or three kangaroos run out through the gap** (a visible payoff).
- **Result card:** the real event, numbers and the "leave early" lesson, with sources (`VERIFY`).

## Sounds this game needs (to add to `docs/audio.md`)

Footsteps, picking up the wire cutters, snipping the fence ties, the fence panel crashing down, kangaroos hopping out, **success sound** for the fence, hose attach and valve turn, water flow, the flame, putting it out, **success sound** for the fire, fire and wind ambience, jump and landing on debris, the exit. Voice: none.

## Art and build notes

- First person 3D scene, small: one yard, a few props. The 2.5D style guide (#121) applies to the look.
- Mechanics are few: move, look, interact, jump. No steering of animals.
- Memoksin (#125): a small first-person 3D scene is feasible and will not take long; built in parallel with the 2.5D reform (done around 16:00 on Sat), then polish until Sun 18:00.

## Build (art in the game, #125)

- The world is the look-dev farm `scenes/art_pilot/fire_farm.tscn`: `FireSkin.farm_model` = `scenes/minigames/fire/art/farm.tscn` (same slab, house, shed, windmill, pen, gums, grass, fire front, sky, light, post pass). Every task prop is a skin model from `scenes/minigames/fire/art/`; `tools/fire_gen.gd` builds the scene (colliders, anchors, placeholders) on the same layout.
- Layout: pen in the south-west corner, its yard-side wall has the cuttable section (post, panel and six flagged wire ties: `scenes/minigames/fire/art/fence_cut.tscn`). Wire cutters on a chopping block by the pen. The flame is a strip of burning grass across the track right inside the broken gate (it closes the gate's mouth; out = `scorch_patch`). The valve moved off the shed wall (13 m from the flame there) to a standpipe by the track, ~5 m from the flame, hose coil next to it.
- Kangaroos: out through the cut, across the yard, over the low boundary fence (they clear it, people cannot) and away south, from the fire.
- `smoke` (the 90 s clock) drives fog, sky smoke, sun, ambient, the fire front creeping to the back fence (two more stretches catch later), smoke drift and flame haze.
- Shots: `godot --path . -s res://tools/fire_shots.gd` (first person through the tasks, `export/shots/fire_*.png`). Frame time: `godot --path . -s res://tools/perf.gd -- --only=fire`.

## Playtest changes (wire cutters, falling panel, ending shot)

- **Wire cutters** instead of the knife: `tools/models/fire/cutters.py` (`cutters` on the block; `cutters_view_r/_l`, the two halves in gloved hands, first person). Texts `FIRE_HINT_CUTTERS`, `FIRE_USE_CUTTERS`, `FIRE_NEED_CUTTERS` (TR "tel kesme makası"), `FIRE_HINT_FENCE` / `FIRE_USE_FENCE` say wire. Code ids: `cutters` (`FireLogic.pick_cutters`, `FireSkin.cutters_model` / `hand_cutters_model`, sound `cutters`).
- **The cut**: the panel is lashed with six galvanised wire ties flagged with orange tape (`fence.py` `pen_fence_tie`). While the player holds, the ties snip one by one (`set_cut`, sound `snip`) and the cutters' jaws close at each. On the cut the panel goes slack, drops onto its edge, topples into the yard, slams down (dust cloud, sparks off the corner that hits first, sound `panel_land`), hops a little and lies still; the wire mesh rings after the hit (`panel_bow.gdshader`).
- The fall is a small hand-written rigid-body simulation (`scenes/minigames/fire/art/panel_fall.gd`): one box against the ground and the two posts, sequential impulses, fixed 240 Hz steps on game time (pauses, seeks and runs headless with the game). It sleeps when still (about 1.8 s); at 4 s it eases into the nearest lying-flat pose whatever happened, a broken state does the same, and one call never steps more than the whole fall, so a seek just finishes it. The kangaroos wait in the pen until it is down (`ROO_DELAY` 1.4 s).
- **Ending shot** (`FireSkin.escape_seconds` 8.5, `lose_seconds` 7.5): out of the gate, the camera leaves the head, rises over the player and pulls back on a curve into the style's hero angle (pitch -40, yaw -22, FOV 26; `fire.gd` `hero_transform()`), the whole floating slab in view. The player is a small figure (`tools/models/fire/farmer.py`, blue shirt and gloves of the first-person hands, wide-brimmed hat; a four-pose run cycle) running down the track the way the kangaroos went, slowing into a held stride while the fire front runs over the farm on the north-westerly (`farm.gd` `set_engulf`: ember edge, char, roofs, hay, pen and gums catching, smoke columns; it stops just behind the runner). A held moment, then a fade into the result card's colour (`Palette.BG`), so the card fades in seamlessly.
- **Time up**: the darker version. The smoke stays thick, sun and ambient go down, the vignette closes, "The smoke took over." stays up; the figure crouches where the player stood, an arm over the mouth; the fire takes everything, kangaroos still in the pen go under it.
- Rules and score are unchanged (`finish_minigame` gets the same values, only later). A key after 1 s cuts the ending to its fade.
- Shots: `fire_shots.gd` also saves `fire_snip`, `fire_cut`, `fire_slam`, `fire_panel_down`, `fire_end_*`, `fire_lose_*`. Perf: `perf.gd -- --only=fire` has `fire ending escape` / `fire ending lose` (about 10 ms a frame on an M4 Max).

## Opening shot, task plate, markers (playtest, #125)

- **Opening shot** (`FireSkin.overview_seconds` 5.4; `fire.gd` `_pose_overview`, shares `INTRO_*`): the hero view (pitch -40, FOV 26) holds a moment; the camera cranes up over the gums and the farmhouse while it swings round to the farmer's front, comes down to his face (a telephoto portrait, FOV 30, about 1.2 m) and holds there with a slow push-in; then it turns half way round his head, rising a little over it, the FOV opening to 75, and ends in his eyes on the first-person camera's exact transform. The farmer (`farmer.tscn`, standing where the player starts, facing the way the player looks) dissolves where he comes nearer the camera than 0.75 m (pixel dither on his own materials, `_own_farmer_materials`) and is hidden once the camera is behind his eyes; the first-person arms node comes in at that moment. Clock and task plate fade in at the end, the mouse is caught when play starts (`_begin_play`), as before. Space or a click goes straight to first person.
- **Task plate** (Fener's errand banner): `Hud/Info` (step line and task line) sits on a dark plate with an amber edge at the bottom centre, above the controls line and clear of the crosshair and the "E ..." prompt; it wraps to two lines at most and is laid out on the HUD's 1280x720 (the game's `canvas_items` stretch scales it). A new step flashes the edge and the step line white. The task line goes with the controls line (after 12 s of play), then the plate is the step line alone. The done banner uses the same plate with a green edge (red for "The smoke took over.").
- **Markers**: the 3D exclamation marks are off; `_draw_markers` draws them on the HUD over each open task (2.7 m above the marker): a dark disc and halo with a gold edge and a gold "!", a pointer down, a slow ping ring, the distance under it past 6 m. Constant size at any distance; the current task's pin is full size, the other one smaller and dimmer; it fades out within 3 m (the prompt takes over) and over the crosshair, and keeps above the plate. Off screen, the edge arrow (same badge with an arrow) points to the current task. The faint light beam stays in the world.
- Checks: `tests/test_fire_ux.gd` (opening shot path and handover, skip, markers, plate layout at 1280x720 and 1920x1080 in English and Turkish). Shots: `fire_shots.gd` saves `fire_intro_0..7`; `bash tools/fire_intro_gif.sh` makes `export/shots/fire_intro.gif`.

## Open questions

- The exact wording of the score on the card.
- Real event details and what the card says (Black Saturday facts to verify).
