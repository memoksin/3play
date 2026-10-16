class_name FitSkin
extends Resource
## Mechanic data for the Fit minigame. Kahramanmaras: items into Building/Car/Tent.
## Solar flare reuses it with seats as zones.

enum StartArt { BUILDING, NONE }
enum Ending { COLLAPSE, FLARE }

@export var zones: Array[FitZone] = []
@export var item_types: Array[FitItemType] = []
## Every item on the board, in display order.
@export var items: Array[FitItem] = []
## FitZone.id where all items start.
@export var start_zone: StringName
@export var timer_seconds := 75.0
## Clock shown in the HUD, in minutes after midnight (300 = 05:00, 804 = 13:24).
@export var clock_start_min := 300
@export var clock_end_min := 804
## Real seconds of the warning shocks. The final hit is at timer_seconds.
@export var aftershock_times: Array[float] = [25.0, 50.0]
## Blankets needed in a NEEDS_HEAT zone when there is no stove.
@export var blankets_to_warm := 2
## tr() keys.
@export var creak_key := ""
@export var quake_key := ""
## Optional: warning i shows warning_keys[i] instead of creak_key.
@export var warning_keys: Array[String] = []
## Art drawn in the start zone: the cracked building, or nothing.
@export var start_art := StartArt.BUILDING
## Final hit: COLLAPSE = shake + building collapse (warnings shake too); FLARE = white flash, no shake.
@export var ending := Ending.COLLAPSE
## Falling snow and the sky/snow colours.
@export var snow := true
@export var sky_color := Color("323353")
## Optional full-screen backdrop drawn behind the zones. Null = flat sky_color fill.
@export var background: Texture2D
## Optional animated backdrop (a Control with set_time(seconds)); replaces `background` when set.
@export var background_scene: PackedScene
@export var snow_color := Color("c7dcd0")
## Warm/cold badge on every zone. warm_key/cold_key override its text (empty = FIT_WARM/FIT_COLD).
@export var show_warmth := true
@export var warm_key := ""
@export var cold_key := ""
## Optional 32x32 icons drawn in the Warm/Cold badge next to the text. Null = text only.
@export var warm_icon: Texture2D
@export var cold_icon: Texture2D


func zone(id: StringName) -> FitZone:
	for z in zones:
		if z.id == id:
			return z
	return null


func type_of(item_index: int) -> FitItemType:
	var tid := items[item_index].type
	for t in item_types:
		if t.id == tid:
			return t
	return null
