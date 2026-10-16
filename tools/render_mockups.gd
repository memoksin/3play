extends SceneTree
## Renders UI mockups (role select, HUD timer, result card) to docs/ui/*.png
## using the real theme and font. Needs a window (not --headless):
## godot --path . -s tools/render_mockups.gd

const OUT := "res://docs/ui/"
const LOGO := preload("res://ui/logo.tscn")


func _init() -> void:
	RenderingServer.set_default_clear_color(Palette.BG)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _run() -> void:
	for shot: Array in [["role_select", _role_select()], ["hud_timer", _hud()], ["result_card", _result()]]:
		var ui: Control = shot[1]
		root.add_child(ui)
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.save_png(OUT + shot[0] + ".png")
		print("saved ", OUT, shot[0], ".png ", img.get_size())
		ui.queue_free()
		await process_frame
	quit()


func _full() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


func _label(key: String, variation := "", align := HORIZONTAL_ALIGNMENT_CENTER, wrap_w := 0) -> Label:
	var l := Label.new()
	l.text = key
	l.theme_type_variation = variation
	l.horizontal_alignment = align
	if wrap_w > 0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = wrap_w
	return l


func _role_select() -> Control:
	var c := _full()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 32)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(box)
	var logo: Control = LOGO.instantiate()
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(logo)
	box.add_child(_label("MENU_PROMPT"))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 48)
	box.add_child(row)
	for r in [["ROLE_STATE", "StateButton", "ROLE_STATE_DESC"], ["ROLE_CITIZEN", "CitizenButton", "ROLE_CITIZEN_DESC"]]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 12)
		var b := Button.new()
		b.text = r[0]
		b.theme_type_variation = r[1]
		b.custom_minimum_size = Vector2(320, 112)
		col.add_child(b)
		var d := _label(r[2], "", HORIZONTAL_ALIGNMENT_CENTER, 320)
		col.add_child(d)
		row.add_child(col)
	return c


func _hud() -> Control:
	var c := _full()
	# Fake minigame area so the HUD reads as an overlay.
	var game := ColorRect.new()
	game.color = Color("374e4a")
	game.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(game)
	for pair in [[Vector2(48, 48), "normal 42 s"], [Vector2(48, 180), "warn 24 s"], [Vector2(48, 312), "danger 7 s"]]:
		var p := _timer_widget(pair[1])
		p.position = pair[0]
		c.add_child(p)
	var note := _label("top-left anchored, 16 px margin in-game. Shown 3 states.", "MutedLabel", HORIZONTAL_ALIGNMENT_LEFT)
	note.position = Vector2(48, 640)
	note.size = Vector2(1184, 40)
	c.add_child(note)
	return c


func _timer_widget(state: String) -> PanelContainer:
	var secs := int(state.split(" ")[1])
	var color := Palette.SAFE
	var fill := Palette.SAFE
	if secs < 10:
		color = Palette.DANGER
		fill = Palette.DANGER
	elif secs < 30:
		color = Palette.WARN
		fill = Palette.WARN
	var p := PanelContainer.new()
	p.theme_type_variation = "HudPanel"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	h.add_child(_label("HUD_TIME", "MutedLabel", HORIZONTAL_ALIGNMENT_LEFT))
	var t := _label("0:%02d" % secs, "TimerLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	t.add_theme_color_override("font_color", color)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var bar := ProgressBar.new()
	bar.theme_type_variation = "TimerBar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(240, 16)
	bar.max_value = 90
	bar.value = secs
	var fs := (p.get_theme_stylebox("fill", "TimerBar") as StyleBoxFlat).duplicate()
	fs.bg_color = fill
	bar.add_theme_stylebox_override("fill", fs)
	v.add_child(bar)
	return p


func _result() -> Control:
	var c := _full()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(880, 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	card.add_child(v)
	# Real Tier 1 strings (Indian Ocean) from locale/strings.csv.
	v.add_child(_label(tr("IO_PLACE") + ", " + tr("IO_YEAR"), "MutedLabel"))
	v.add_child(_label(tr("IO_CARD_SCORE") % 3, "SafeLabel"))
	var real := _label("IO_CARD_NUMBERS", "", HORIZONTAL_ALIGNMENT_CENTER, 800)
	real.add_theme_color_override("font_color", Palette.GOLD)
	v.add_child(real)
	v.add_child(HSeparator.new())
	v.add_child(_label("IO_CARD_FACT", "", HORIZONTAL_ALIGNMENT_LEFT, 800))
	v.add_child(_label("IO_CARD_HELP", "", HORIZONTAL_ALIGNMENT_LEFT, 800))
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 24)
	for k in ["RESULT_REPLAY", "RESULT_MENU"]:
		var b := Button.new()
		b.text = k
		btns.add_child(b)
	v.add_child(btns)
	v.add_child(_label("CLOSING_LINE", "ClosingLabel"))
	return c
