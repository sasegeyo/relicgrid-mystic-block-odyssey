extends Control
## Haftalık Lig / Kohort Ekranı: Kısa başlıklar, net ikonlar ve büyük sayılar.

var _viewing_tier: int = 0
var _bg_rect: ColorRect
var _tier_buttons: Array[Button] = []
var _rank_lbl: Label
var _pts_lbl: Label
var _rows_vbox: VBoxContainer


func _ready() -> void:
	_viewing_tier = GameState.cohort_tier_index
	_bg_rect = ColorRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_rect)
	move_child(_bg_rect, 0)

	_build_ui()
	_refresh_standings()


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
		SoundManager.play_sfx("ui_click")
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	top_bar.add_child(back_btn)

	var title_lbl := ThemeManager.make_label("LİG", 28, "gold_light", true)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title_lbl)

	var timer_pill := ThemeManager.make_card_panel(false, 12, 8)
	timer_pill.add_child(ThemeManager.make_label("⏳ " + GameState.get_week_remaining_label(), 18, "gold_light", true))
	top_bar.add_child(timer_pill)
	main_vbox.add_child(top_bar)

	# 5 Lig Sekmesi
	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 8)
	_tier_buttons.clear()
	for i in range(GameState.LEAGUE_TIERS.size()):
		var t_cfg: Dictionary = GameState.LEAGUE_TIERS[i]
		var tab_txt: String = str(t_cfg["name"]).to_upper()
		var tb := ThemeManager.make_button(tab_txt, 14, "gold" if i == GameState.cohort_tier_index else "stone", 10)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size = Vector2(0, 48)
		var cap_i: int = i
		tb.pressed.connect(func() -> void:
			SoundManager.play_sfx("ui_click")
			_viewing_tier = cap_i
			_refresh_standings()
		)
		_tier_buttons.append(tb)
		tabs_row.add_child(tb)
	main_vbox.add_child(tabs_row)

	# Özet Kartı (Sıra ve LP)
	var sum_card := ThemeManager.make_card_panel(true, 18, 12)
	var sum_hb := HBoxContainer.new()
	_rank_lbl = ThemeManager.make_label("#1", 28, "gold_light")
	_rank_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sum_hb.add_child(_rank_lbl)
	_pts_lbl = ThemeManager.make_label("0 LP", 28, "text_main")
	sum_hb.add_child(_pts_lbl)
	sum_card.add_child(sum_hb)
	main_vbox.add_child(sum_card)

	# Sıralama Listesi
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_rows_vbox = VBoxContainer.new()
	_rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(_rows_vbox)
	main_vbox.add_child(scroll)

	# Oyna Butonu
	var play_btn := ThemeManager.make_button("▶ OYNA", 22, "gold")
	play_btn.custom_minimum_size = Vector2(0, 62)
	play_btn.pressed.connect(func() -> void:
		SoundManager.play_sfx("ui_click")
		GameState.active_mode = GameState.PlayMode.CAMPAIGN
		GameState.selected_stage = GameState.unlocked_stage
		get_tree().change_scene_to_file("res://scenes/GameScene.tscn")
	)
	main_vbox.add_child(play_btn)


func _refresh_standings() -> void:
	var tier_cfg: Dictionary = GameState.LEAGUE_TIERS[_viewing_tier]
	var accent: Color = tier_cfg["accent"]
	var standings: Array[Dictionary] = GameState.get_cohort_standings(_viewing_tier)

	for i in range(_tier_buttons.size()):
		_tier_buttons[i].modulate = Color(1, 1, 1, 1.0 if i == _viewing_tier else 0.65)

	if _viewing_tier == GameState.cohort_tier_index:
		var my_rank: int = 1
		for e in standings:
			if bool(e["is_player"]):
				my_rank = int(e["rank"])
				break
		_rank_lbl.text = "%s  ·  #%d" % [str(tier_cfg["name"]).to_upper(), my_rank]
		_pts_lbl.text = "%d LP" % GameState.weekly_points
	else:
		_rank_lbl.text = str(tier_cfg["name"]).to_upper()
		_pts_lbl.text = "%d+ LP" % int(tier_cfg["min_pts"])

	for ch in _rows_vbox.get_children():
		ch.queue_free()

	for entry in standings:
		var rnk: int = int(entry["rank"])
		_rows_vbox.add_child(_create_row(entry, accent))
		if rnk == 5:
			_rows_vbox.add_child(ThemeManager.make_label("▲ İLK 5 ▲", 13, Color("#34D399"), true))


func _create_row(entry: Dictionary, tier_accent: Color) -> PanelContainer:
	var is_me: bool = bool(entry["is_player"])
	var rnk: int = int(entry["rank"])
	var td: Dictionary = ThemeManager.get_theme_data()

	var bg_col: Color = Color("#2D210B") if is_me else td["card_bg"]
	var border_col: Color = td["border_gold"] if is_me else (Color("#236349") if rnk <= 5 else td["border_stone"])

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeManager.make_card_style(bg_col, border_col, 12, 14, 10))

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)

	var rank_col: Color = td["gold_light"] if rnk <= 3 else (Color("#34D399") if rnk <= 5 else td["text_dim"])
	var r_lbl := ThemeManager.make_label("#%d" % rnk, 20, rank_col)
	r_lbl.custom_minimum_size = Vector2(52, 0)
	hb.add_child(r_lbl)

	var badge := Control.new()
	badge.custom_minimum_size = Vector2(34, 34)
	var bseed: int = int(entry.get("badge_seed", 1))
	badge.draw.connect(func() -> void:
		var pal_id: String = str(PieceLibrary.PALETTE_ORDER[posmod(bseed, PieceLibrary.PALETTE_ORDER.size())])
		PieceLibrary.draw_relic_tile(badge, Rect2(Vector2(1, 1), Vector2(32, 32)), pal_id, bseed % 6, 1.0, 0.5 if is_me else 0.0)
	)
	hb.add_child(badge)

	var n_lbl := ThemeManager.make_label(str(entry["name"]), 18, "gold_light" if is_me else "text_main")
	n_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(n_lbl)

	hb.add_child(ThemeManager.make_label("%d" % int(entry["points"]), 22, td["gold_light"] if is_me else tier_accent))
	panel.add_child(hb)
	return panel
