# Meshy characters on Quaternius UAL (Fener, Fire)

Five citizens for Fener: `player`, `mom`, `child`, `grandpa`, `rescuer`. The Black Saturday `farmer` (Fire
minigame): the ending NPC and the player's own first-person arms (see "Farmer" below).
Pipeline: ChatGPT reference image (`ref/`) -> Meshy image-to-3D + auto-rig (`out/<name>/rigged.glb`, `fetch.sh`) ->
new joints and weights (`rig.py`) -> Quaternius UAL clips + clips built on them (`retarget.py`, `clips.py`) ->
`assets/3d/kahramanmaras/meshy_<name>.glb` (one mesh, 24 bones, ~3.5k tris, 512 px JPEG, Basis Universal import).
Meshy's own walk/run/idle are not used: with its weights the coats moved with the thighs and the body folded.

## Clips (Godot names; all loop)

| Clip | Who | Source | Ground speed (m/s) |
|---|---|---|---|
| `idle` | all | UAL `Idle_Loop` | 0 |
| `walk` | all | UAL `Walk_Loop` | 0.86 adults, 0.57 child |
| `run` | all | UAL `Jog_Fwd_Loop`, stride and arm pump calmed (x0.72 / x0.8) | 3.6-3.9 adults, 2.6 child |
| `walk_follow` | player, mom, child, grandpa | `Walk_Loop`, shorter steps, small arm swing, 1.3x slower | 0.53 adults, 0.35 child |
| `walk_tired` | grandpa | `Walk_Loop`, stooped, soft knees, arms forward, 1.4x slower | 0.36 |
| `shiver` | child | `Idle_Loop` + arms hugging the chest, hands rubbing, shoulders up, trembling | 0 |
| `trapped` | mom, child, grandpa | last pose of UAL `Death01` (on the back), right arm rises and waves, head and chest lift, 4 s loop | 0 |
| `dig` | rescuer | seamless loop cut from UAL `Fixing_Kneeling` (kneeling, hands on the rubble) | 0 |
| `wave` | rescuer | `Idle_Loop` + right arm raised, palm forward, 4 waves per loop | 0 |
| `jog` | farmer | UAL `Jog_Fwd_Loop` calmed (legs x0.55, arms x0.6), 1.2x slower | 2.7 |
| `crouch` | farmer | UAL `Crouch_Idle_Loop`, right forearm over the mouth, two coughs per loop | 0 |

The farmer also has `idle`, `walk` (0.94 m/s) and `run` (4.2 m/s); `scenes/minigames/fire/art/farmer.gd` blends
walk / jog / run by the speed it reads from `set_run(phase)` and seeks them by distance (no sliding).

Clips are in place. Move the character at the ground speed above (planted-foot speed, `work/<name>_report.json`
`foot_speed_mps`) or the feet slide; scale playback with the move speed for in-between speeds.
In Fener the player walks 5.2 m/s and followers can catch up at 6.5: `run` then plays at 1.4x (adults, 3.8) and 2.0-2.5x (child, 2.6),
which is why `fener_rig.gd` lets `run` speed up to 2.6x (feet still keep still).
Clip set per character: `CLIPS_OF` in `clips.py` (any clip can be given to anyone: add it there and rebuild).

## Rebuild

```sh
blender -b --factory-startup --python-exit-code 1 -P tools/models/meshy/merge.py   # rig.py + retarget.py, all five
godot --headless --path . --import
godot --headless --path . -s res://tests/test_meshy_chars.gd
bash tools/models/meshy/gif.sh          # export/shots/meshy_gif/<name>_<clip>.gif + contact.gif (needs a window)
bash tools/models/meshy/gif.sh only=farmer
```

`rig.py` / `retarget.py` also run alone and take `-- name ...`. UAL: Universal Animation Library [Standard]
(Quaternius, CC0, https://quaternius.itch.io/universal-animation-library), expected at
`~/Downloads/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb` or `$UAL`.

## Farmer (Fire #125)

Reference `ref/farmer.png` (GPT Image 2.5 via Meshy text-to-image), mesh `src/farmer_meshy.glb` (Meshy image-to-3D,
meshy-t2.5, ~15k faces, A-pose, separate gloved fingers). No Meshy auto-rig: `fit_skeleton.py` builds the 24-bone
rig itself (height 1.88 m; wrists at the narrowest cut of the glove cuff, elbows one forearm length up the arm,
found from the texture's glove / skin colours), and `rig.py` falls back to it when `out/farmer/rigged.glb` is
missing. `retarget.py` writes `assets/3d/fire/meshy_farmer.glb` (`DEST_OF`, 4.6k tris, 1024 px: `TEX_OF`).

First-person arms (`assets/3d/fire/fp_cutters.glb`, `fp_nozzle.glb`, `fp_empty.glb`; `scenes/minigames/fire/art/hand_*.tscn`):

```sh
blender -b --factory-startup --python-exit-code 1 -P tools/models/fire/fp_tools.py    # tool parts -> work/fp_tools/
blender -b --factory-startup --python-exit-code 1 -P tools/models/meshy/fp_arms.py    # stages mesh, rig, anim
blender -b --factory-startup --python-exit-code 1 -P tools/models/meshy/fp_arms.py -- anim nozzle   # or cutters / empty
godot --headless --path . --import
godot --headless --path . -s res://tests/test_fire_arms.gd
bash tools/models/meshy/fp_gif.sh       # export/shots/fp_gif/<tool>_<clip>.gif + contact.png (needs a window)
godot --path . -s res://tools/fire_shots.gd -- only=cutters,snip,pickup,attach,turn,attached,spray prefix=fp_ size=1280x720
bash tools/fire_gif.sh                  # export/shots/fire_gif/{pickup,attach,valve,spray}.gif: the clips in the game
```

- `fp_arms.py` stage `mesh`: both arms cut from the full-detail mesh at mid upper arm (glove shell + sleeve piece,
  far below the frame in every pose), the cut capped, one subdivision level, the texture baked into its own
  1024 px layout (`work/fp_mesh.blend`, ~19k tris for both arms).
- stage `rig`: per arm Arm, ForeArm, ForeArmTwist, Hand and Hand{Thumb,Index,Middle,Ring,Pinky}{1,2,3}. Fingers are
  found by slicing the hand across its axis every 2 mm and tracking the section loops (shared vertices) from the
  fingertips into the palm; joints at anatomical shares of each finger. Weights: arm chain along the bone line,
  the twist bone taking 85 % of the hand's twist; each finger's cells per phalanx with narrow blends at the knuckles.
- stage `anim` (`fp_tool.py`, `fp_pose.py`): the tool parts on their own bones (Tool, CutR/CutL; Trigger, Muzzle,
  Hose0..10, Inlet), both hands placed by two-bone IK with an anatomical elbow hinge; `best_grip` picks the hand
  roll / palm angle / elbow pole that keep forearm twist and wrist bend natural; fingers close on the handles by a
  contact solver against the glove's own vertices, the thumb by a small search. Clips (camera space, 30 fps):
  cutters `idle` `walk` `snip` `raise` `lower`; nozzle `idle` `walk` `spray` `spray_start` `raise` `lower`
  `pickup` `attach` `valve`; empty (bare hands) `idle` `walk` `raise` `lower`. Reach and twist per clip in
  `work/fp_report.json`.
- Bare hands (`Empty`, `hand_empty.tscn` with plain `fp_arms.gd`, `FireSkin.hand_empty_model`): no tool, both
  hands relaxed and half open (fingers 16-34 deg per joint, more toward the little finger), wrists 0.34 m below
  and 0.3 m ahead of the eye, so only the fingers and the backs of the hands show over the bottom of the view
  (~33 deg below centre at FOV 75). fire.gd shows them while no tool is in hand: they go down (`put_away`) as a
  tool comes up, and come back up (`raise`) once the last tool has gone down.
- Nozzle interaction clips (`Nozzle.pickup_p` / `attach_p` / `valve_p`): fire.gd brings the camera, in `LOCK_IN`
  0.4 s, to where the clip wants it on the prop (the prop's frame in camera space is baked on three root bones,
  `Ref<Act>O/X/Y`; `hand_nozzle.gd act_ref`; camera = prop x ref^-1, crouched, movement and look frozen) and plays
  the clip by game time (`set_act`). `pickup` 1.8 s: bent down (eye 0.7 m over the nozzle, the arms' roots forward),
  the right hand takes the nozzle lying by the coil with its hold grip (0.9 s: the coil's own nozzle, the same part,
  hides and the hand's one shows: the Tool bone's scale), lifts it, the left hand comes up under the hose.
  `attach` 2.1 s: the nozzle aside, the left hand brings the hose's coupling (`fp_coupling`, Coupling bone) under the
  tap's connector, pushes it on, turns it 60 deg and lets go (1.47 s: valve.tscn's Coupling shows, the hose line
  too). `valve` 2.6 s, seeked by the hold (`valve_seconds`): the nozzle dropped, both hands on the rim (palm on its
  front, fingers closed round it on four short capsules along the arc, forearm twist within -75..+25 deg over a
  heave), four 90 deg heaves with a regrip between (one turn, counterclockwise: opening), let go, reach down; the
  wheel's turn is baked on the Turn bone (`act_turn`), so the prop wheel follows the hands. Then `raise`.
- Spray: the loop is held still against the jet (only a sway once per loop). The old 4-9 Hz "pressure shiver",
  keyed at 30 fps, moved the muzzle ~1 mm between frames at 60 fps (the jet, the FP hose and the world hose line
  with it); now 0.007 mm.
- Cutters grip (`Cutters` in `fp_tool.py`): each hand holds its handle from the outside, as with real long-handled
  bolt cutters: the palm on the handle's outer, upper side, the fingers closing round under it to the inner side,
  the thumb over the top, so squeezing brings the handles together. `anat_grip` searches hand roll, palm diagonal
  (40-55 deg, the handle from the heel of the hand to the index knuckle) and elbow pole by the wrist's own ranges
  (forearm twist about neutral, extension / flexion, ulnar / radial deviation, `wrist`), the palm within 35 deg of
  inward-and-down and the hand within reach (`grip_choice` in the report: twist ~41, extension ~3, ulnar ~27 deg,
  reach 0.94). The view model's cutters are 1.2x the chopping-block ones (0.92 m, a 36 in bolt cutter, against
  the farmer's ~23 cm gloved hands; `CUT_SCALE` here and in `fp_tools.py`), held with the head pitched up 11 deg
  just under the crosshair and the arms' roots 3 cm forward / 12 cm up (`SHOULDER`: the farmer's arms are short
  for a first-person view; the upper-arm cut and the elbows stay out of frame at the running FOV). `raise` /
  `lower` move the whole View bone so the hands never leave the grips. `split_fingers` cuts the glove where the
  thumb tip and the index / middle tips are fused in the Meshy mesh (they pulled out into needles once the
  fingers part); cutters only, the nozzle export is unchanged.
- In game: `fp_arms.gd` (AnimationTree: idle / walk by `set_move`, the tool action, raise / lower one-shots),
  `hand_cutters.gd` (`set_snip` 0..1 seeks `snip`), `hand_nozzle.gd` (`set_spray`; `set_act` / `act_ref` /
  `act_event` / `act_turn`, the interaction clips over everything), `viewmodel.gdshader` (drawn in front of the world
  by squeezing the depth, so walls never cut the arms; glove grain / sleeve weave detail).

## What the scripts do

- `rig.py`: joints centred on cross-sections of the mesh (elbows, wrists, knees, ankles, shoulders on the upper arm's
  centre line, spine in the torso depth). Weights depend on position only, so Meshy's nested shells (coat, skirt,
  lining) move together: arm chain in a capsule blended into the torso at the shoulder; spine bands; clavicles on
  the shoulder tops; head only inside the skull (hoods, collars, scarves stay on neck/chest); leg chain in a capsule;
  coat and skirt below the crotch on Hips, sliding to the thighs (and shins under the knee) towards the hem with a
  wide left/right blend (`CFG` per character); crotch mostly Hips; 2 smoothing passes, max 4 influences.
- `retarget.py`: pf_3d Bloom retarget maths (rest delta per bone, arm/leg chains rest-aligned, hip-height translation
  scale). Arm clearance against the skinned body (star-shaped slices in chest and hip space): an arm that would go
  into a coat swings outward about the chest's forward axis, eased at <= 3 deg/frame. Grounding by the lowest
  skinned vertex. 30 fps.
- `motion_quality.py`: per clip edge stretch of the skinned mesh (p99.9 <= 2.8 in every clip), planted-foot speed,
  loop seam, frame-to-frame pops, hand drift from the clearance. Numbers in `work/<name>_report.json`.
- `gif.gd` / `gif.sh`: style camera (pitch -40, yaw -22, FOV 26), ground grid scrolling at the clip's foot speed
  (sliding feet show against it); trapped turned so the body lies across the screen.

Known limits: the long coats (mom, grandpa) follow the thighs, so in `run` the hem opens at the front/back slit
(edge stretch up to ~5x on a few hem edges); the child's arms stand ~35 deg out in `walk` (puffy jacket); fingers
have no bones in the 24-bone game rigs (mittens/gloves read fine, bare hands stay a flat paddle); only the farmer's
first-person arms have finger joints.
