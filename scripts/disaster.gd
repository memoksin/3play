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
## Weather and time of day at the place (sun, ambient, sky, fog): the diorama set and the minigame world
## both light themselves from it. Null = each keeps its own scene's light.
@export var atmosphere: Atmosphere
## Key in Game.SCENES: fit, connect, beam.
@export var minigame: StringName
## Mechanic data (FitSkin, ConnectSkin, BeamSkin). Owned by the minigame.
@export var skin: Resource
## Mission badge model (Story progress, tools/models/badges/): drawn by BadgeView on the badges screen and in the badge moment after the result card.
@export var badge: PackedScene
## Solar flare: globe glitches to year 3000+.
@export var glitch := false


func text(suffix: String) -> String:
	return TranslationServer.translate(key_prefix + "_" + suffix)
