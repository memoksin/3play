class_name TextFx
## Entry effects for text screens: fade in, type on. Layout-safe: they only
## touch modulate and visible_ratio, never size or position, so containers
## keep their measured size from the first frame.

const FADE := 0.35       # seconds
const TYPE_CPS := 60.0   # characters per second


## Fades `node` from transparent to its current colour after `delay` seconds.
static func fade_in(node: CanvasItem, delay := 0.0, duration := FADE) -> Tween:
	var target := node.modulate
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(node, "modulate:a", target.a, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tw


## Reveals `label` letter by letter after `delay` seconds. Returns the tween;
## kill it or call custom_step(9999.0) on it to show the full text at once.
## `on_start` runs when the first letter appears (after `delay`), `on_finish`
## when the last one does; custom_step() skipping still runs both, once each.
## (kill() runs neither.) Audio hook for typing loops, see docs/audio.md.
static func type_on(label: Control, delay := 0.0, cps := TYPE_CPS, on_start := Callable(), on_finish := Callable()) -> Tween:
	label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING  # keep wrap stable
	label.visible_ratio = 0.0
	var chars := maxi(label.get_total_character_count(), 1)
	var tw := label.create_tween()
	tw.tween_interval(delay)
	if on_start.is_valid():
		tw.tween_callback(on_start)
	tw.tween_property(label, "visible_ratio", 1.0, chars / cps)
	if on_finish.is_valid():
		tw.tween_callback(on_finish)
	return tw


## Seconds type_on() needs for `label` at `cps`.
static func type_time(label: Control, cps := TYPE_CPS) -> float:
	return label.get_total_character_count() / cps
