extends Control
## Sezon (Battle Pass) ekranı: kademe ilerlemesi, Ücretsiz + Premium ödül yolları.

const BOOSTER_ICONS: Dictionary = {"hammer": "🔨", "rotate": "⟳", "refresh": "🔄", "bomb": "💣"}

var _bg_rect: ColorRect
var _tier_lbl: Label
var _xp_lbl: Label
var _xp_bar: ProgressBar
var _premium_btn: Button
var _rows_vbox: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	_bg_rect = ColorRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_rect)
	move_child(_bg_rect, 0)

	_build_ui()
	BattlePass.pass_updated.connect(_refresh)
	_refresh()
	_scroll_to_current_tier.call_deferred()


func _build_ui() -> void:
	var td: Dictionary = ThemeManager.get_theme_data()
	_bg_rect.color = td["bg_deep"]

	var main_vbox: VBoxContainer = $SafeMargin/MainVBox
	main_vbox.add_theme_constant_override("separation", 14)

	# Üst Bar
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)

	var back_btn := ThemeManager.make_button("←", 22, "stone")
	back_btn.custom_minimum_size = Vector2(72, 52)
	back_btn.pressed.connect(func() -> void:
		AudioManager.play_ui_click()
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	top_bar.add_child(back_btn)

	var title_lbl := ThemeManager.make_label("SEZON %d" % (BattlePass.season_id % 1000 + 1), 28, "gold_light", true)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title_lbl)

	var timer_pill := ThemeManager.make_card_panel(false, 12, 8)
	timer_pill.add_child(ThemeManager.make_label("⏳ %dG" % BattlePass.get_days_left(), 18, "gold_light", true))
	top_bar.add_child(timer_pill)
	main_vbox.add_child(top_bar)

	# İlerleme Kartı
	var prog_card := ThemeManager.make_card_panel(true, 18, 14)
	var prog_vb := VBoxContainer.new()
	prog_vb.add_theme_constant_override("separation", 8)

	var prog_hb := HBoxContainer.new()
	_tier_lbl = ThemeManager.make_label("", 28, "gold_light")
	_tier_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prog_hb.add_child(_tier_lbl)
	_xp_lbl = ThemeManager.make_label("", 20, "text_main")
	prog_hb.add_child(_xp_lbl)
	prog_vb.add_child(prog_hb)

	_xp_bar = ProgressBar.new()
	_xp_bar.min_value = 0
	_xp_bar.max_value = BattlePass.XP_PER_TIER
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(0, 14)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = td["card_dark"]
	bg_sb.set_corner_radius_all(7)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = td["border_gold"]
	fill_sb.set_corner_radius_all(7)
	_xp_bar.add_theme_stylebox_override("background", bg_sb)
	_xp_bar.add_theme_stylebox_override("fill", fill_sb)
	prog_vb.add_child(_xp_bar)

	_premium_btn = ThemeManager.make_button("", 20, "amber_solid")
	_premium_btn.custom_minimum_size = Vector2(0, 56)
	_premium_btn.pressed.connect(func() -> void:
		if BattlePass.purchase_premium():
			AudioManager.play_purchase()
	)
	prog_vb.add_child(_premium_btn)
	prog_card.add_child(prog_vb)
	main_vbox.add_child(prog_card)

	# Sütun başlıkları
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var h0 := ThemeManager.make_label("", 13, "text_dim", true)
	h0.custom_minimum_size = Vector2(60, 0)
	head.add_child(h0)
	var h1 := ThemeManager.make_label("ÜCRETSİZ", 14, "text_dim", true)
	h1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(h1)
	var h2 := ThemeManager.make_label("PREMIUM", 14, "gold_light", true)
	h2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(h2)
	main_vbox.add_child(head)

	# Kademe Listesi
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows_vbox = VBoxContainer.new()
	_rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_vbox.add_theme_constant_override("separation", 8)
	_scroll.add_child(_rows_vbox)
	main_vbox.add_child(_scroll)


func _refresh() -> void:
	var tier: int = BattlePass.get_tier()
	_tier_lbl.text = "KADEME %d / %d" % [tier, BattlePass.TIER_COUNT]
	if tier >= BattlePass.TIER_COUNT:
		_xp_lbl.text = "MAKS"
	else:
		_xp_lbl.text = "%d / %d XP" % [BattlePass.get_xp_into_tier(), BattlePass.XP_PER_TIER]
	_xp_bar.value = BattlePass.get_xp_into_tier()

	if BattlePass.premium:
		_premium_btn.text = "✓ PREMIUM AKTİF"
		_premium_btn.disabled = true
	else:
		_premium_btn.text = "★ PREMIUM AÇ"
		_premium_btn.disabled = false

	for ch in _rows_vbox.get_children():
		ch.queue_free()
	for t in range(1, BattlePass.TIER_COUNT + 1):
		_rows_vbox.add_child(_create_tier_row(t, tier))


func _create_tier_row(t: int, cur_tier: int) -> PanelContainer:
	var td: Dictionary = ThemeManager.get_theme_data()
	var reached: bool = t <= cur_tier
	var is_next: bool = t == cur_tier + 1

	var border: Color = td["border_gold"] if is_next else td["border_stone"]
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeManager.make_card_style(td["card_bg"], border, 12, 12, 8))
	panel.modulate = Color(1, 1, 1, 1.0 if (reached or is_next) else 0.6)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)

	var num := ThemeManager.make_label(str(t), 24, "gold_light" if reached else "text_dim", true)
	num.custom_minimum_size = Vector2(60, 0)
	hb.add_child(num)

	hb.add_child(_create_reward_cell(t, false))
	hb.add_child(_create_reward_cell(t, true))
	panel.add_child(hb)
	return panel


func _create_reward_cell(t: int, is_premium_track: bool) -> Button:
	var reward: Dictionary = BattlePass.get_reward(t, is_premium_track)
	var label: String = _describe_reward(reward)
	var variant: String = "stone"
	var disabled: bool = true

	if BattlePass.is_claimed(t, is_premium_track):
		label = "✓  " + label
	elif BattlePass.can_claim(t, is_premium_track):
		variant = "gold" if not is_premium_track else "amber_solid"
		disabled = false
	elif is_premium_track and not BattlePass.premium:
		label = "🔒  " + label

	var btn := ThemeManager.make_button(label, 17, variant, 10)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 52)
	btn.disabled = disabled
	btn.pressed.connect(func() -> void:
		if BattlePass.claim(t, is_premium_track):
			AudioManager.play_purchase()
	)
	return btn


func _describe_reward(reward: Dictionary) -> String:
	match str(reward.get("type", "")):
		"coins":
			return "🪙 %d" % int(reward.get("amount", 0))
		"booster":
			var bid: String = str(reward.get("id", ""))
			return "%s x%d" % [str(BOOSTER_ICONS.get(bid, "?")), int(reward.get("amount", 1))]
		"theme":
			var t_data: Dictionary = ThemeManager.get_theme_data(str(reward.get("id", "")))
			return "🎨 " + str(t_data.get("name", "TEMA")).to_upper()
	return "?"


func _scroll_to_current_tier() -> void:
	var idx: int = clampi(BattlePass.get_tier() - 1, 0, _rows_vbox.get_child_count() - 1)
	if idx <= 0 or _rows_vbox.get_child_count() == 0:
		return
	await get_tree().process_frame
	var row: Control = _rows_vbox.get_child(idx)
	_scroll.scroll_vertical = int(row.position.y)
