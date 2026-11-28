extends Control
## Günlük Görevler penceresi (ana menüden açılır). Kendi kendini kapatır.

signal closed

var _list_vb: VBoxContainer
var _timer_lbl: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 40

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.04, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var dialog := ThemeManager.make_card_panel(true, 22, 22)
	dialog.custom_minimum_size = Vector2(640, 0)
	center.add_child(dialog)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	dialog.add_child(vb)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	var title := ThemeManager.make_title("GÜNLÜK GÖREVLER", 32, "gold_light", false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := ThemeManager.make_button("", 20, "stone", 14, "close")
	close_btn.custom_minimum_size = Vector2(56, 52)
	close_btn.pressed.connect(func() -> void:
		AudioManager.play_ui_click()
		closed.emit()
		queue_free()
	)
	header.add_child(close_btn)
	vb.add_child(header)

	var timer_hb := HBoxContainer.new()
	timer_hb.add_theme_constant_override("separation", 6)
	timer_hb.add_child(ThemeManager.make_icon("clock", 20, "text_dim"))
	_timer_lbl = ThemeManager.make_label("", 18, "text_dim")
	timer_hb.add_child(_timer_lbl)
	vb.add_child(timer_hb)

	_list_vb = VBoxContainer.new()
	_list_vb.add_theme_constant_override("separation", 12)
	vb.add_child(_list_vb)

	DailyQuests.quests_updated.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	if not is_instance_valid(_list_vb):
		return
	_timer_lbl.text = "Yenilenmesine " + DailyQuests.get_time_left_label()
	for ch in _list_vb.get_children():
		ch.queue_free()
	var qs: Array = DailyQuests.get_quests()
	for i in range(qs.size()):
		_list_vb.add_child(_make_quest_row(i, qs[i]))
	_list_vb.add_child(_make_bonus_row())


func _make_quest_row(i: int, q: Dictionary) -> PanelContainer:
	var td: Dictionary = ThemeManager.get_theme_data()
	var done: bool = DailyQuests.is_done(i)
	var claimed: bool = bool(q["claimed"])
	var border: Color = td["border_gold"] if (done and not claimed) else td["border_stone"]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", ThemeManager.make_card_style(td["card_bg"], border, 14, 14, 12))
	card.modulate = Color(1, 1, 1, 0.55 if claimed else 1.0)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	card.add_child(hb)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	info.add_child(ThemeManager.make_label(str(q["text"]), 21, "text_main"))

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = int(q["target"])
	bar.value = int(q["progress"])
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = td["card_dark"]
	bg_sb.set_corner_radius_all(6)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = td["border_gold"] if not done else Color("#34D399")
	fill_sb.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg_sb)
	bar.add_theme_stylebox_override("fill", fill_sb)
	info.add_child(bar)

	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 8)
	meta.add_child(ThemeManager.make_label("%d / %d" % [int(q["progress"]), int(q["target"])], 16, "text_dim"))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_child(sp)
	meta.add_child(ThemeManager.make_icon("medal", 16, "gold_light"))
	meta.add_child(ThemeManager.make_label("+%d XP" % int(q["xp"]), 16, "gold_light"))
	meta.add_child(ThemeManager.make_icon("coin", 16, Color.WHITE))
	meta.add_child(ThemeManager.make_label("+%d" % int(q["coins"]), 16, "gold_light"))
	info.add_child(meta)
	hb.add_child(info)

	var btn: Button
	if claimed:
		btn = ThemeManager.make_button("", 18, "stone", 14, "check")
		btn.disabled = true
	elif done:
		btn = ThemeManager.make_button("AL", 22, "amber_solid", 14)
		btn.pressed.connect(func() -> void:
			if DailyQuests.claim(i):
				AudioManager.play_purchase()
		)
	else:
		btn = ThemeManager.make_button("", 18, "stone", 14, "lock")
		btn.disabled = true
	btn.custom_minimum_size = Vector2(96, 64)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(btn)
	return card


func _make_bonus_row() -> PanelContainer:
	var td: Dictionary = ThemeManager.get_theme_data()
	var card := PanelContainer.new()
	var bonus_ready: bool = DailyQuests.can_claim_bonus()
	card.add_theme_stylebox_override("panel", ThemeManager.make_card_style(Color("#2D1F08"), Color("#F59E0B") if bonus_ready else td["border_stone"], 14, 14, 12))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	card.add_child(hb)
	hb.add_child(ThemeManager.make_icon("bomb", 34, "gold_light"))
	var lbl := ThemeManager.make_label("Üçünü de bitir: +1 Bomba", 19, "gold_light")
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(lbl)
	var btn: Button
	if DailyQuests.bonus_claimed:
		btn = ThemeManager.make_button("", 18, "stone", 14, "check")
		btn.disabled = true
	elif bonus_ready:
		btn = ThemeManager.make_button("AL", 22, "amber_solid", 14)
		btn.pressed.connect(func() -> void:
			if DailyQuests.claim_bonus():
				AudioManager.play_purchase()
		)
	else:
		btn = ThemeManager.make_button("", 18, "stone", 14, "lock")
		btn.disabled = true
	btn.custom_minimum_size = Vector2(96, 56)
	hb.add_child(btn)
	return card
