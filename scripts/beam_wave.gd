class_name BeamWave
extends Resource
## One wave of the Beam minigame (solar flare 3026). Rules live in BeamLogic.
## Map glyphs, one string per row: . empty, M mirror, S splitter, T thermal, C collector, H habitat.
## Satellites (M, S, T) are numbered in map order (row by row, left to right).

## tr() key of the title.
@export var title_key := ""
## Flare class shown in the HUD and the briefing, e.g. "X1.8".
@export var flare_class := ""
## Countdown seconds before the flare fires on its own.
@export var time := 45.0
## Column the flare comes down from the Sun.
@export var sun := 0
@export var map := PackedStringArray()
## Earth city codes, one per column (names: BeamSkin.city_key()).
@export var earth := PackedStringArray()
## Habitat names in map order (proper names, not translated).
@export var habitats := PackedStringArray()
## Briefing diagrams: &"mirror", &"splitter", &"thermal" or &"" (none).
@export var mech := &""
## tr() key of the briefing chip ("New: splitter"), "" for none.
@export var chip_key := ""
## Chip colour: &"new" (violet) or &"thermal" (orange).
@export var chip_style := &"new"
@export var intro_key := ""
@export var tip_key := ""
## Start rotation per satellite, one digit 0-7 (45 degree steps).
@export var start := ""
## A perfect rotation per satellite, one digit 0-3, "?" = any (tests, debug solve()).
@export var solution := ""
