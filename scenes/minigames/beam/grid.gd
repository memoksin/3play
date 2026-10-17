extends Node2D
## Placeholder grid (prototype look): the satellite network's field, `cols` x `rows` cells of `cell`
## px from this node's position (the grid's top-left corner).

var cols := 1
var rows := 1
var cell := 40.0


func _draw() -> void:
	var bw := cols * cell
	var bh := rows * cell
	var box := Rect2(-3, -3, bw + 6, bh + 6)
	draw_rect(box, Color(0.047, 0.07, 0.15, 0.5))
	draw_rect(box, Color(0.47, 0.67, 1.0, 0.16), false, 1.0)
	var line := Color(0.47, 0.67, 1.0, 0.06)
	for x in range(1, cols):
		draw_line(Vector2(x * cell + 0.5, 0), Vector2(x * cell + 0.5, bh), line, 1.0)
	for y in range(1, rows):
		draw_line(Vector2(0, y * cell + 0.5), Vector2(bw, y * cell + 0.5), line, 1.0)
	var dot := Color(0.59, 0.75, 1.0, 0.22)
	for x in range(1, cols):
		for y in range(1, rows):
			draw_rect(Rect2(x * cell - 1, y * cell - 1, 2, 2), dot)
