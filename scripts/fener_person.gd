class_name FenerPerson
extends Resource
## One person to reach in Fener (#123). The kind decides what they need; the figure is a placeholder
## (scenes/art_pilot citizens) until the final people arrive: set `figure` to swap it.

enum Kind {
	LOST,     ## found by the light, then follows you (whistles)
	SLOW,     ## follows, but you all walk slower (cane; whistles)
	TRAPPED,  ## under rubble: found by the light, then report it to a rescue crew (taps)
	INJURED,  ## needs a first aid kit, then follows slowly (calls for help)
	COLD,     ## needs a blanket, then follows (cries)
}

@export var id: StringName
## Text suffix of the name (skin.text_prefix + name_key), e.g. "MOM" -> KAHR_FENER_MOM.
@export var name_key := ""
@export var kind := Kind.LOST
## FenerMap.SPOTS group: where this person can be.
@export var spot_group: StringName
## Family members count for the family slots in the HUD.
@export var family := false
@export var color := Color.WHITE
@export var figure: PackedScene
## Figure scale (a child is smaller than the placeholder's 1.75 m).
@export var figure_scale := 1.0
