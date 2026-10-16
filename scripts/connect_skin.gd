class_name ConnectSkin
extends Resource
## Mechanic data for the Connect minigame. Indian Ocean: pipelines from ocean inlets to basins
## under each community. Rules live in ConnectLogic, art layout in scenes/minigames/connect.gd.

enum Tile { ROCK, STRAIGHT, CORNER, INLET, BASIN }

@export var cols := 7
@export var rows := 6
## Tile type per cell, row-major (cols * rows entries).
@export var tiles := PackedInt32Array()
## Solved rotation per cell in clockwise quarter turns. Fixed tiles use 0.
@export var solution := PackedInt32Array()
## Seed of the shipped start rotations (ConnectLogic.start_rotations re-rolls from it if needed).
@export var start_seed := 2004
@export var min_start_clicks := 10
@export var timer_seconds := 60.0
## The timer bar turns red for the last red_seconds.
@export var red_seconds := 15.0
## tr() key of the one-line prompt.
@export var prompt_key := "IO_TASK"
## tr() keys of the community names, in basin order (top to bottom).
@export var community_keys: PackedStringArray = []
## Result line key, "%d/4 communities saved".
@export var score_key := "IO_CARD_SCORE"
## Banner key shown when the wave hits.
@export var wave_key := "IO_CONNECT_WAVE"


func index(c: int, r: int) -> int:
	return r * cols + c


func tile(c: int, r: int) -> int:
	return tiles[r * cols + c]
