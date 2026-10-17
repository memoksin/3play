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
## Event time, ISO UTC ("2023-02-06T01:17:00"): the globe lights the Earth from the real sun. Empty = the prototype sun at the lock pose.
@export var utc := ""
## Key in Game.SCENES: fit, connect, beam, fener.
@export var minigame: StringName
## Mechanic data (FitSkin, ConnectSkin, BeamSkin, FenerSkin). Owned by the minigame.
@export var skin: Resource
## Mission badge model (Story progress, tools/models/badges/): drawn by BadgeView on the badges screen and in the badge moment after the result card.
@export var badge: PackedScene
## Solar flare: globe glitches to year 3000+.
@export var glitch := false


func text(suffix: String) -> String:
	return TranslationServer.translate(key_prefix + "_" + suffix)
