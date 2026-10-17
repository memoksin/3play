@tool
class_name PlateStyle
extends StyleBox
## The globe's place plate as a StyleBox: translucent dark fill, a thin edge,
## and a coloured accent bar on the left (scenes/globe.gd draws the same plate).

@export var bg := Color(0, 0, 0, 0.72)
@export var edge := Color(0.62, 0.85, 1.0, 0.18)
@export var bar := Color(1.0, 0.35, 0.24)
@export var edge_width := 1.0
@export var bar_width := 3.0


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var rs := RenderingServer
	if bg.a > 0:
		rs.canvas_item_add_rect(to_canvas_item, rect, bg)
	if edge.a > 0 and edge_width > 0:
		var w := edge_width
		rs.canvas_item_add_rect(to_canvas_item, Rect2(rect.position, Vector2(rect.size.x, w)), edge)
		rs.canvas_item_add_rect(to_canvas_item, Rect2(rect.position + Vector2(0, rect.size.y - w), Vector2(rect.size.x, w)), edge)
		rs.canvas_item_add_rect(to_canvas_item, Rect2(rect.position + Vector2(rect.size.x - w, 0), Vector2(w, rect.size.y)), edge)
	if bar.a > 0 and bar_width > 0:
		rs.canvas_item_add_rect(to_canvas_item, Rect2(rect.position, Vector2(bar_width, rect.size.y)), bar)
