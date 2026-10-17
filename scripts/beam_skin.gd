class_name BeamSkin
extends Resource
## Mechanic data for the Beam minigame (solar flare 3026, #124). Rules live in BeamLogic, flow and
## input in scenes/minigames/beam.gd, the look in scenes/minigames/beam/ (board + pieces).
## New art: set a *_scene field to a scene that keeps the piece's properties (see
## docs/minigames/beam-solar-flare.md); null = the placeholder in scenes/minigames/beam/.

@export var waves: Array[BeamWave] = []
## Beam travel speed in cells per second.
@export var beam_speed := 9.5
## Charge-up before the beam leaves the Sun, in cells of beam time (5.5 / 9.5 = 0.58 s).
@export var charge := 5.5
## Seconds the finished shot stays on screen before the wave result.
@export var hold := 1.5
## Last seconds of the countdown: the timer pulses and ticks.
@export var warn_seconds := 10.0
## Route preview on at start (the player can turn it off on the title card).
@export var preview := true
## Prefix of every tr() key of the minigame: <prefix>FIRE, <prefix>W1_TITLE, <prefix>CITY_IST...
@export var text_prefix := "SF_BEAM_"

@export_group("Art")
## Whole board (layout, layers, pieces). Must keep scenes/minigames/beam/board.gd's API.
@export var board_scene: PackedScene
@export var backdrop_scene: PackedScene
@export var grid_scene: PackedScene
@export var satellite_scene: PackedScene
@export var collector_scene: PackedScene
@export var habitat_scene: PackedScene
## Earth city under a column.
@export var city_scene: PackedScene
## West / east ring and Parker base (city keys W, R, N).
@export var station_scene: PackedScene
@export var beams_scene: PackedScene
@export var fx_scene: PackedScene


func text(suffix: String) -> String:
	return TranslationServer.translate(text_prefix + suffix)


## tr() key of an Earth city code ("IST" -> SF_BEAM_CITY_IST).
func city_key(code: String) -> String:
	return text_prefix + "CITY_" + code


## Every city of every wave: the result card's total.
func total_cities() -> int:
	var n := 0
	for w in waves:
		n += BeamLogic.count_cities(BeamLogic.parse(w))
	return n
