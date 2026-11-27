extends Control
## 500 Bölümlük Kampanya Haritası: Sade, tok kartlar ve büyük sayılar.

const STAGES_PER_PAGE: int = 20
const TOTAL_PAGES: int = 25

var _page_index: int = 0
var _bg_rect: ColorRect
var _biome_lbl: Label
var _page_lbl: Label
var _grid: GridContainer
var _prev_btn: Button
var _next_btn: Button


func _ready() -> void:
	_page_index = clampi(GameState.campaign_page, 0, TOTAL_PAGES - 1)
	_bg_rect = ColorRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_rect)
	move_child(_bg_rect, 0)

	_build_ui()
	_refresh_page()


func _build_ui() -> void:
	var td: Dictionary = ThemeManager.get_theme_data()
	_bg_rect.color = td["bg_deep"]

	var main_vbox: VBoxContainer = $SafeMargin/MainVBox
	main_vbox.add_theme_constant_override("separation", 14)

	# Üst Çubuk
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)

	var back_btn := ThemeManager.make_button("←", 22, "stone")
	back_btn.custom_minimum_size = Vector2(72, 52)
	back_btn.pressed.connect(func() -> void:
		SoundManager.play_sfx("ui_click")
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	top_bar.add_child(back_btn)

	var title_lbl := ThemeManager.make_label("KAMPANYA", 26, "gold_light", true)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title_lbl)

	var jump_btn := ThemeManager.make_button("▶ #%d" % GameState.unlocked_stage, 19, "amber_solid")
	jump_btn.custom_minimum_size = Vector2(124, 52)
	jump_btn.pressed.connect(func() -> void:
		SoundManager.play_sfx("ui_click")
		_launch_stage(GameState.unlocked_stage)
	)
	top_bar.add_child(jump_btn)
	main_vbox.add_child(top_bar)

	# Özet Kartı (Biyom + Yıldız Sayısı)
	var header_card := ThemeManager.make_card_panel(true, 16, 12)
	var h_hb := HBoxContainer.new()
	_biome_lbl = ThemeManager.make_label("", 22, "gold_light")
	_biome_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_hb.add_child(_biome_lbl)
	h_hb.add_child(ThemeManager.make_label("★ %d / 1500" % GameState.get_total_stars(), 22, "text_main"))
	header_card.add_child(h_hb)
	main_vbox.add_child(header_card)

	# Sayfalama
	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 8)

	var first_btn := ThemeManager.make_button("|<", 17, "stone")
	first_btn.custom_minimum_size = Vector2(64, 48)
	first_btn.pressed.connect(func() -> void: _set_page(0))
	nav_row.add_child(first_btn)

	_prev_btn = ThemeManager.make_button("◀", 18, "stone")
	_prev_btn.custom_minimum_size = Vector2(78, 48)
	_prev_btn.pressed.connect(func() -> void: _set_page(_page_index - 1))
	nav_row.add_child(_prev_btn)

	_page_lbl = ThemeManager.make_label("", 20, "text_main", true)
	_page_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_row.add_child(_page_lbl)

	_next_btn = ThemeManager.make_button("▶", 18, "stone")
	_next_btn.custom_minimum_size = Vector2(78, 48)
	_next_btn.pressed.connect(func() -> void: _set_page(_page_index + 1))
	nav_row.add_child(_next_btn)

	var last_btn := ThemeManager.make_button(">|", 17, "stone")
	last_btn.custom_minimum_size = Vector2(64, 48)
	last_btn.pressed.connect(func() -> void: _set_page(TOTAL_PAGES - 1))
	nav_row.add_child(last_btn)
	main_vbox.add_child(nav_row)

	# 4x5 Bölüm Izgarası
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)
	main_vbox.add_child(scroll)


func _set_page(new_idx: int) -> void:
	var clamped: int = clampi(new_idx, 0, TOTAL_PAGES - 1)
	if clamped == _page_index:
		return
	SoundManager.play_sfx("ui_click")
	_page_index = clamped
	GameState.campaign_page = _page_index
	_refresh_page()


func _refresh_page() -> void:
	var start_stage: int = _page_index * STAGES_PER_PAGE + 1
	var end_stage: int = mini(500, start_stage + STAGES_PER_PAGE - 1)
	var biome: String = LevelGenerator.get_biome_name_for_stage(start_stage).to_upper()

	_biome_lbl.text = "%s  (%d-%d)" % [biome, start_stage, end_stage]
	_page_lbl.text = "%d / %d" % [_page_index + 1, TOTAL_PAGES]
	_prev_btn.disabled = (_page_index <= 0)
	_next_btn.disabled = (_page_index >= TOTAL_PAGES - 1)

	for ch in _grid.get_children():
		ch.queue_free()

	for st in range(start_stage, end_stage + 1):
		_grid.add_child(_create_stage_card(st))


func _create_stage_card(stage_num: int) -> Control:
	var is_unlocked: bool = (stage_num <= GameState.unlocked_stage)
	var is_current: bool = (stage_num == GameState.unlocked_stage)
	var stars: int = GameState.get_stage_stars(stage_num)

	var variant: String = "amber_solid" if is_current else ("gold" if is_unlocked else "stone")
	var btn := ThemeManager.make_button("", 22, variant, 14)
	btn.custom_minimum_size = Vector2(0, 114)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.disabled = not is_unlocked

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 6)

	var num_txt: String = str(stage_num) if is_unlocked else ("🔒 %d" % stage_num)
	var num_col: Color = ThemeManager.get_color("gold_light") if is_current else (ThemeManager.get_color("text_main") if is_unlocked else Color(0.45, 0.52, 0.49))
	vb.add_child(ThemeManager.make_label(num_txt, 26 if is_unlocked else 18, num_col, true))

	if is_unlocked:
		var s_txt: String = ("★" if stars >= 1 else "☆") + ("★" if stars >= 2 else "☆") + ("★" if stars >= 3 else "☆")
		var s_col: Color = ThemeManager.get_color("gold_light") if stars > 0 else Color(0.42, 0.52, 0.48)
		vb.add_child(ThemeManager.make_label(s_txt, 17, s_col, true))

	btn.add_child(vb)
	btn.pressed.connect(func() -> void:
		SoundManager.play_sfx("ui_click")
		_launch_stage(stage_num)
	)
	return btn


func _launch_stage(stage_num: int) -> void:
	GameState.active_mode = GameState.PlayMode.CAMPAIGN
	GameState.selected_stage = clampi(stage_num, 1, 500)
	GameState.campaign_page = int((GameState.selected_stage - 1) / STAGES_PER_PAGE)
	get_tree().change_scene_to_file("res://scenes/GameScene.tscn")
