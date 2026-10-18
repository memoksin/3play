extends Node3D
## Look scene for the Kahramanmaras street + rescue set (#123 Fener): the 6 Feb 2023 night between the quakes.
## No gameplay. Small life only, picked by light name: Fire* flicker, BeaconRed*/BeaconBlue* alternate,
## Amber* pulse (machine beacons), Spark* crackle (live cables).

var t := 0.0
var lights: Array[Light3D] = []
var base: Array[float] = []


func _ready() -> void:
	for n in find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if l is DirectionalLight3D:
			continue
		lights.append(l)
		base.append(l.light_energy)


func _process(delta: float) -> void:
	t += delta
	for i in lights.size():
		var l := lights[i]
		var nm := String(l.name)
		var e := base[i]
		if nm.begins_with("Fire"):
			var n := sin(t * 13.0 + i * 3.1) * 0.5 + sin(t * 23.7 + i) * 0.3 + sin(t * 5.3 + i * 7.0) * 0.2
			l.light_energy = e * (0.86 + 0.14 * n)
		elif nm.begins_with("BeaconRed") or nm.begins_with("BeaconBlue"):
			var ph := fmod(t * 1.6 + (0.5 if nm.begins_with("BeaconBlue") else 0.0), 1.0)
			l.light_energy = e * (1.0 if ph < 0.5 else 0.08) * (0.6 + 0.4 * absf(sin(ph * TAU * 2.0)))
		elif nm.begins_with("Amber"):
			l.light_energy = e * (0.3 + 0.7 * maxf(0.0, sin(t * 7.0 + i)))
		elif nm.begins_with("Spark"):
			var s := sin(t * 41.0 + i * 5.0) * sin(t * 17.0 + i)
			l.light_energy = e * (1.0 if s > 0.55 else 0.12)
