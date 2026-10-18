class_name FitZone
extends Resource
## One place items can be dropped on (Building, Car, Tent; later: solar flare seats).

enum Warm { ALWAYS, NEVER, NEEDS_HEAT }

@export var id: StringName
## tr() key of the zone name.
@export var label_key := ""
## Slot capacity. -1 = unlimited.
@export var slots := -1
@export var warm: Warm = Warm.ALWAYS
## Persons here at the end are saved. False for the damaged building.
@export var safe := true
## Placeholder fill. Used until a texture exists.
@export var color := Color("3e3546")
## Optional sprite, drawn behind the items instead of the placeholder.
@export var texture: Texture2D
## Optional horizontal sheet of frame_count equal frames, drawn behind the chips filling the zone.
## Frame = crack stage (0 at start, +1 per aftershock), the last frame once the collapse starts.
## Set = the code-drawn building/cracks are skipped. Single frame (1) for car/tent.
@export var frames: Texture2D
@export var frame_count := 1
