class_name FitLogic
extends RefCounted
## Fit rules, no nodes. `placement` holds the zone id of every skin item, by index.


static func start_placement(skin: FitSkin) -> Array[StringName]:
	var p: Array[StringName] = []
	p.resize(skin.items.size())
	p.fill(skin.start_zone)
	return p


static func slots_used(skin: FitSkin, placement: Array[StringName], zone_id: StringName) -> int:
	var n := 0
	for i in placement.size():
		if placement[i] == zone_id:
			n += skin.type_of(i).slots
	return n


## Free slots, or -1 for an unlimited zone.
static func slots_free(skin: FitSkin, placement: Array[StringName], zone_id: StringName) -> int:
	var cap := skin.zone(zone_id).slots
	if cap < 0:
		return -1
	return maxi(cap - slots_used(skin, placement, zone_id), 0)


static func can_place(skin: FitSkin, placement: Array[StringName], item_index: int, zone_id: StringName) -> bool:
	var z := skin.zone(zone_id)
	if z == null:
		return false
	if z.slots < 0 or placement[item_index] == zone_id:
		return true
	return slots_used(skin, placement, zone_id) + skin.type_of(item_index).slots <= z.slots


static func is_warm(skin: FitSkin, placement: Array[StringName], zone_id: StringName) -> bool:
	match skin.zone(zone_id).warm:
		FitZone.Warm.ALWAYS:
			return true
		FitZone.Warm.NEVER:
			return false
	var blankets := 0
	for i in placement.size():
		if placement[i] != zone_id:
			continue
		match skin.type_of(i).heat:
			FitItemType.Heat.STOVE:
				return true
			FitItemType.Heat.BLANKET:
				blankets += 1
	return blankets >= skin.blankets_to_warm


## {saved, total, cold}: scored items outside unsafe zones are saved; saved in a cold zone also count as cold.
static func score(skin: FitSkin, placement: Array[StringName]) -> Dictionary:
	var saved := 0
	var total := 0
	var cold := 0
	for i in placement.size():
		if not skin.type_of(i).scored:
			continue
		total += 1
		if skin.zone(placement[i]).safe:
			saved += 1
			if not is_warm(skin, placement, placement[i]):
				cold += 1
	return {"saved": saved, "total": total, "cold": cold}
