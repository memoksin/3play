class_name FitSkin
extends Resource
## Mechanic data for the Fit minigame. Kahramanmaras: items into Building/Car/Tent.
## Solar flare reuses it with seats as zones.

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
