class_name FenerPerson
extends Resource
## One person to reach in Fener (#123). The kind decides what they need; the figure is a rigged Meshy character
## (tools/models/meshy/README.md): set `figure` (and `figure_speeds` if its gaits differ) to swap it.

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
## Rigged figure, origin at the feet, front +Z. Clips (a missing one falls back to a close one): idle, walk, run,
## walk_follow, walk_tired (slow followers), trapped (under rubble / hurt), shiver (cold).
@export var figure: PackedScene
## Figure scale (the figures come in real size: a child is 1.3 m).
@export var figure_scale := 1.0
## Ground speed in m/s of each moving clip of `figure`: the playback follows the person's real speed so the feet
## keep still on the ground.
@export var figure_speeds := {&"walk": 0.86, &"walk_follow": 0.53, &"run": 3.8, &"walk_tired": 0.36}
