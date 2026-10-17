extends Node3D
## 2.5D art pilot (#121): Kahramanmaras street, 6 Feb 2023, between the 04:17 and 13:24 quakes.
## Fixed camera, no gameplay. Only small life: fire flicker, the emergency beacon, torch sway, snow.

@export var beacon_rate := 1.6

var t := 0.0
@onready var fires: Array[OmniLight3D] = [$Props/FireA/Light, $Props/FireB/Light]
@onready var beacon: OmniLight3D = $Lights/Beacon
@onready var torch: SpotLight3D = $People/Player/Torch
@onready var fire_energy: Array[float] = []
var torch_rot := Vector3.ZERO
var debris: Array[Node3D] = []
var debris_y: Array[float] = []


func _ready() -> void:
	for f in fires:
		fire_energy.append(f.light_energy)
	torch_rot = torch.rotation_degrees
	for c in $World/Debris.get_children():
		debris.append(c)
		debris_y.append(c.position.y)


func _process(delta: float) -> void:
	t += delta
	for i in fires.size():
		var n := sin(t * 13.0 + i * 3.1) * 0.5 + sin(t * 23.7 + i) * 0.3 + sin(t * 5.3 + i * 7.0) * 0.2
		fires[i].light_energy = fire_energy[i] * (0.86 + 0.14 * n)
	var ph := fmod(t * beacon_rate, 1.0)
	beacon.light_color = Color(1.0, 0.16, 0.12) if ph < 0.5 else Color(0.16, 0.34, 1.0)
	beacon.light_energy = 3.2 * (0.55 + 0.45 * absf(sin(ph * TAU * 2.0)))
	for i in debris.size():
		debris[i].position.y = debris_y[i] + sin(t * 0.6 + i * 1.7) * 0.25
		debris[i].rotate_y(delta * 0.03 * (1.0 if i % 2 else -1.0))
	torch.rotation_degrees = torch_rot + Vector3(sin(t * 1.3) * 1.5, sin(t * 0.9) * 3.0, 0.0)
