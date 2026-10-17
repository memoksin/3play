class_name FireSkin
extends Resource
## Mechanic data for the Fire minigame (Black Saturday, kangaroo farm, #125; docs/minigames/fire-farm.md).
## Rules live in FireLogic, the scene in scenes/minigames/fire.gd (built by tools/fire_gen.gd).
## Art: every *_model field, when set, replaces that prop's placeholder `Model` node at start-up. The
## prop's root keeps its place, colliders and anchors, so a model only has to look right. A model may
## react to the game (optional): `set_state(state: StringName)` (or an AnimationPlayer with an animation
## of that name) for "cut", "open", "attached", "out", "free"...; the valve's `set_turn(0..1)`; the
## flame's `set_strength(0..1)`; the kangaroo's `set_hop(0..1)` (0 = on the ground). Without them the
## scene animates the placeholder way.

## Total time (s): the player must be out of the gate before it runs out.
@export var timer_seconds := 90.0
## Seconds after the start before the "Overview" camera hands over to first person.
@export var overview_seconds := 3.8

@export_group("Smoke")
## Smoke follows the clock: clear for clear_seconds, thickens to ramp_level until dense_seconds before
## the end, then to 1 (very dense) at the end.
@export var clear_seconds := 10.0
@export var dense_seconds := 10.0
@export var ramp_level := 0.68
## Exponential fog density (1/m) at smoke 0 and 1; in between it grows geometrically, so every second
## takes away about the same share of the view.
@export var fog_clear := 0.006
@export var fog_dense := 0.42
@export var smoke_color := Color(0.46, 0.38, 0.33)
## How much the smoke colour covers the sky at the start (it is fully covered at smoke 1).
@export var sky_fog_clear := 0.55
## Sun colour and energy, clear and in full smoke.
@export var sun_color := Color(1.0, 0.72, 0.45)
@export var sun_energy := 1.15
@export var sun_energy_smoke := 0.3

@export_group("Player")
@export var walk_speed := 4.4
@export var run_speed := 6.8
## Metres per second squared on the ground (speeding up / slowing down) and in the air.
@export var accel := 38.0
@export var air_accel := 12.0
## Jump: 6.6 m/s against 20 m/s2 lifts the feet about 1.09 m: over the 0.75 m debris, never over a fence.
@export var jump_velocity := 6.6
@export var gravity := 20.0
## Radians per screen pixel; keyboard turning in radians per second.
@export var mouse_sensitivity := 0.0024
@export var key_turn_speed := 2.6
@export var fov := 75.0
@export var run_fov := 81.0

@export_group("Tasks")
## Hand reach (m) for picking up, cutting, attaching and turning.
@export var reach := 2.6
@export var cut_seconds := 1.0
@export var valve_seconds := 1.0
## The hose sprays this far (m); the flame is out after douse_seconds of water, and grows back at
## regrow_rate per second while it is not hit.
@export var spray_range := 8.5
@export var douse_seconds := 1.6
@export var regrow_rate := 0.15
## Hose length (m) from the valve: the player cannot walk further while holding the attached hose.
@export var hose_length := 13.0
## Kangaroos that run out of the cut fence (2 or 3), and seconds between them.
@export var kangaroos := 3
@export var kangaroo_gap := 0.45

@export_group("Texts")
## tr() keys.
@export var task_key := "FIRE_TASK"
@export var controls_key := "FIRE_CONTROLS"
@export var paused_key := "FIRE_PAUSED"
@export var fence_done_key := "FIRE_DONE_FENCE"
@export var flame_done_key := "FIRE_DONE_FLAME"
@export var lose_key := "FIRE_LOSE"

@export_group("Models")
## Yard, house, shed, hay, fences and scrub (replaces Farm/Model; the colliders stay).
@export var farm_model: PackedScene
@export var knife_model: PackedScene
## The cuttable fence section (state "cut" when it falls).
@export var fence_model: PackedScene
## The broken exit gate (state "open" when the exit marker shows).
@export var gate_model: PackedScene
@export var debris_model: PackedScene
@export var valve_model: PackedScene
## The hose coil on the ground (state "held" when picked up, "attached" on the valve).
@export var hose_model: PackedScene
@export var flame_model: PackedScene
@export var kangaroo_model: PackedScene
## The exclamation marker over a task.
@export var marker_model: PackedScene
## In-hand models (first person), shown at the bottom right.
@export var hand_knife_model: PackedScene
@export var hand_nozzle_model: PackedScene
