class_name FitItemType
extends Resource
## A kind of item: person, stove, blanket...

enum Heat { NONE, STOVE, BLANKET }

@export var id: StringName
## tr() key used when an item has no name of its own.
@export var label_key := ""
@export var slots := 1
## Counts for the score (people).
@export var scored := false
## How the item warms a zone that needs heat.
@export var heat: Heat = Heat.NONE
## Placeholder icon colour and letter source.
@export var color := Color("9babb2")
## Optional sprite, shown instead of the placeholder icon.
@export var texture: Texture2D
