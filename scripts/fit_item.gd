class_name FitItem
extends Resource
## One item on the board.

## FitItemType.id
@export var type: StringName
## tr() key. Empty = the type's label.
@export var name_key := ""
## tr() key of the small second line. May be empty.
@export var role_key := ""
