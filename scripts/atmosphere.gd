class_name Atmosphere
extends Resource
## Weather and time of day at a disaster's place (Disaster.atmosphere): the one source its diorama set
## (scenes/diorama/diorama.gd) and its minigame world (Connect: scenes/minigames/connect/connect_world.gd)
## light themselves from, so the cut from the diorama into the game keeps the same world. Colours are
## scene colours (before the filmic tonemap). Clear sky: no clouds.

## Key light (sun / moon): rotation in degrees (Node3D order) in the set's own frame, which is the
## minigame's slab frame (the diorama set root = Connect's $Coast), colour and energy.
@export var sun_rotation := Vector3(-36.0, -40.0, 0.0)
@export var sun_color := Color(1.0, 0.87, 0.7)
@export var sun_energy := 1.0
## Flat ambient light (sky-tinted).
@export var ambient_color := Color(0.62, 0.74, 0.9)
@export var ambient_energy := 0.45
## Background: [top, bottom] gradient on screen.
@export var sky_top := Color(0.07, 0.16, 0.24)
@export var sky_bottom := Color(0.07, 0.16, 0.24)
## Depth fog colour; the world's far edges dissolve into it.
@export var haze := Color(0.07, 0.16, 0.24)
## Depth fog [begin, end] in metres from a camera `fog_ref` m from the subject (the diorama's orbit
## radius); a nearer or farther camera scales both.
@export var fog := Vector2(48.0, 140.0)
@export var fog_ref := 42.0
## Filmic tonemap exposure.
@export var exposure := 1.0


## Sets the key light; `frame` = the basis of the set / slab frame in the light's parent.
func light(sun: DirectionalLight3D, frame := Basis()) -> void:
	sun.basis = frame * Basis.from_euler(sun_rotation * PI / 180.0)
	sun.light_color = sun_color
	sun.light_energy = sun_energy


## Tonemap, ambient light and depth fog; `fog_scale` = camera distance to the subject / fog_ref.
func environment(env: Environment, fog_scale := 1.0) -> void:
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = exposure
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = haze
	env.fog_light_energy = 1.0
	env.fog_density = 1.0
	env.fog_sky_affect = 0.0
	env.fog_depth_curve = 1.3
	env.fog_depth_begin = fog.x * fog_scale
	env.fog_depth_end = fog.y * fog_scale
