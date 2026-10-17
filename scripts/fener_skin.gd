class_name FenerSkin
extends Resource
## Rules and art of the Fener minigame (Kahramanmaras, #123). Rules run in scenes/minigames/fener.gd,
## the map in scripts/fener_map.gd, the look in scenes/minigames/fener/. New figures: set a *_scene
## field or a person's `figure`; null = the art pilot placeholder.

@export var people: Array[FenerPerson] = []
## Prefix of every tr() key of the minigame: <prefix>START, <prefix>MOM ...
@export var text_prefix := "KAHR_FENER_"

@export_group("Time")
@export var time_seconds := 210.0
## Story clock shown in the HUD (between the 04:17 and 13:24 quakes, still dark): starts here and
## runs story_minutes over the whole game.
@export var story_from := "04:38"
@export var story_minutes := 50.0

@export_group("Player")
## Metres per second.
@export var walk_speed := 4.0
## Each injury slows you by this fraction (floor: min_speed_k).
@export var injury_slow := 0.07
@export var min_speed_k := 0.55
## Walking with a slow or treated person behind you caps your speed at this.
@export var slow_speed := 3.0
@export var rough_k := 0.6

@export_group("Flashlight")
@export var lamp_range := 13.0
## Half angle of the light cone, radians.
@export var lamp_half := 0.4
## Radius you always see around you.
@export var ambient := 2.4
## Battery % per second while the light is on.
@export var drain := 1.25
## Battery % a spare battery gives.
@export var spare := 45.0
@export var low_battery := 25.0

@export_group("Aftershocks")
## First shock: random seconds in this range; then every `shock_every` seconds (random in range).
@export var shock_first := Vector2(20.0, 25.0)
@export var shock_every := Vector2(26.0, 34.0)
@export var shock_warn := 1.5
@export var shock_shake := 1.8
## No new shock this close to the end.
@export var shock_tail := 12.0

@export_group("Art")
@export var player_scene: PackedScene
@export var rescuer_scene: PackedScene


func text(suffix: String) -> String:
	return TranslationServer.translate(text_prefix + suffix)
