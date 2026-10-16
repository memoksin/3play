class_name Disaster
extends Resource

@export var id: StringName
@export var role: StringName
## tr() key prefix: "KAHR" -> KAHR_PLACE, KAHR_INTRO_1, KAHR_CARD_FACT...
@export var key_prefix: String
@export var lat := 0.0
@export var lon := 0.0
## Event year: the globe counter rewinds to it.
@export var year := 0
## Key in Game.SCENES: fit, connect.
@export var minigame: StringName
## Mechanic data (FitSkin, ConnectSkin). Owned by the minigame.
@export var skin: Resource
## Solar flare: globe glitches to year 3000+.
@export var glitch := false


func text(suffix: String) -> String:
	return TranslationServer.translate(key_prefix + "_" + suffix)
