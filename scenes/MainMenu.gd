extends Control
## Ana Menü: Tok ve sade arayüz, Pazar & Altın barı, 7 günlük rün şeridi
## ve 2'li Sonsuz Mod (Normal / Özel) seçim penceresi.

const DAY_LETTERS: Array = ["P", "S", "Ç", "P", "C", "C", "P"]

var _time_acc: float = 0.0
var _backdrop_canvas: Control
var _mosaic_strip: Control
var _endless_modal: ColorRect
var _sound_btn: Button


func _ready() -> void:
	_backdrop_canvas = $BackdropCanvas
	_backdrop_canvas.draw.connect(_draw_mystic_backdrop)

	var dust := CPUParticles2D.new()
	dust.position = Vector2(360, 640)
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(360, 640)
	dust.amount = 24
	dust.lifetime = 4.5
	dust.gravity = Vector2(0, -14)
	dust.initial_velocity_min = 4.0
	dust.initial_velocity_max = 15.0
	dust.scale_amount_min = 2.0
	dust.scale_amount_max = 4.5
	dust.color = Color(0.99, 0.90, 0.54, 0.22)
	add_child(dust)
	move_child(dust, 1)

	ThemeManager.theme_changed.connect(_on_theme_changed)
	_rebuild_menu()


func _on_theme_changed(_tid: String) -> void:
	_rebuild_menu.call_deferred()


func _process(delta: float) -> void:
	_time_acc += delta
	if _backdrop_canvas != null:
		_backdrop_canvas.queue_redraw()
	if _mosaic_strip != null and is_instance_valid(_mosaic_strip):
		_mosaic_strip.queue_redraw()


func _rebuild_menu() -> void:
	var main_vbox: VBoxContainer = $SafeMargin/MainVBox
	main_vbox.add_theme_constant_override("separation", 16)
	for ch in main_vbox.get_children():
		ch.queue_free()
	if _endless_modal != null and is_instance_valid(_endless_modal):
		_endless_modal.queue_free()
		_endless_modal = null

	# 1) ÜST BAR (Altın + Pazar + Ses)
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)

	var coin_card := ThemeManager.make_card_panel(true, 14, 8)
	coin_card.add_child(ThemeManager.make_label("🪙 %d" % GameState.coins, 22, "gold_light", true))
	top_bar.add_child(coin_card)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	var shop_btn := ThemeManager.make_button("🛒 PAZAR", 18, "amber_solid")
	shop_btn.custom_minimum_size = Vector2(146, 50)
	shop_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click")
		get_tree().change_scene_to_file("res://scenes/ShopScene.tscn")
	)
	top_bar.add_child(shop_btn)

	_sound_btn = ThemeManager.make_button("✕" if AudioManager.sound_muted else "♪", 22, "stone")
	_sound_btn.custom_minimum_size = Vector2(56, 50)
	_sound_btn.pressed.connect(func() -> void:
		var on: bool = AudioManager.toggle_sound()
		_sound_btn.text = "♪" if on else "✕"
	)
	top_bar.add_child(_sound_btn)
	main_vbox.add_child(top_bar)

	# 2) AMBLEM VE BAŞLIK
	var hero_vb := VBoxContainer.new()
	hero_vb.add_theme_constant_override("separation", 4)

	var crest := Control.new()
	crest.custom_minimum_size = Vector2(0, 92)
	crest.draw.connect(func() -> void:
		var c: Vector2 = crest.size * 0.5
		var pulse: float = 0.5 + 0.5 * sin(_time_acc * 2.6)
		crest.draw_arc(c, 42.0 + pulse * 3.0, 0.0, TAU, 36, Color(0.96, 0.62, 0.04, 0.38), 2.5, true)
		PieceLibrary.draw_relic_tile(crest, Rect2(c - Vector2(28, 28), Vector2(56, 56)), "jade", 0, 1.0, 0.6, true)
	)
	hero_vb.add_child(crest)
	hero_vb.add_child(ThemeManager.make_label("RELICGRID", 52, "gold_light", true))
	main_vbox.add_child(hero_vb)

	# 3) 3 TOK İSTATİSTİK KARTI (Kısa başlık + büyük sayı)
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 12)
	var league_info: Dictionary = GameState.get_current_league_info()
	stats_row.add_child(_make_stat_pill("BÖLÜM", "%d" % GameState.unlocked_stage, "★ %d" % GameState.get_total_stars(), ThemeManager.get_color("gold_light")))
	stats_row.add_child(_make_stat_pill("SERİ", "%d🔥" % GameState.daily_streak, "MAX %d" % GameState.best_daily_streak, Color("#34D399")))
	stats_row.add_child(_make_stat_pill(str(league_info["name"]).to_upper(), "%d" % GameState.weekly_points, "LP", league_info["accent"]))
	main_vbox.add_child(stats_row)

	# 4) 7 GÜNLÜK MOZAİK RÜN ŞERİDİ
	var mosaic_card := ThemeManager.make_card_panel(false, 14, 10)
	_mosaic_strip = Control.new()
	_mosaic_strip.custom_minimum_size = Vector2(0, 62)
	_mosaic_strip.draw.connect(_draw_weekly_mosaic_strip)
	mosaic_card.add_child(_mosaic_strip)
	main_vbox.add_child(mosaic_card)

	# 5) ANA MOD BUTONLARI
	var btn_box := VBoxContainer.new()
	btn_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 12)

	if BoardSaveManager.has_saved_run():
		var saved: Dictionary = BoardSaveManager.load_run()
		if not saved.is_empty():
			var btn_resume := ThemeManager.make_button("▶  DEVAM ET  (%d)" % int(saved.get("score", 0)), 22, "emerald")
			btn_resume.custom_minimum_size = Vector2(0, 64)
			btn_resume.pressed.connect(func() -> void:
				AudioManager.play_pickup()
				GameState.active_mode = int(saved.get("mode", 0)) as GameState.PlayMode
				GameState.selected_stage = maxi(1, int(saved.get("stage", 1)))
				get_tree().change_scene_to_file("res://scenes/GameScene.tscn")
			)
			btn_box.add_child(btn_resume)

	var btn_camp := ThemeManager.make_button("⚔  KAMPANYA  #%d" % GameState.unlocked_stage, 24, "gold")
	btn_camp.custom_minimum_size = Vector2(0, 76)
	btn_camp.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click")
		GameState.campaign_page = int((GameState.unlocked_stage - 1) / 20)
		get_tree().change_scene_to_file("res://scenes/CampaignMap.tscn")
	)
	btn_box.add_child(btn_camp)

	var daily_done: bool = GameState.is_daily_completed_today()
	var btn_daily := ThemeManager.make_button("☀  GÜNLÜK" + ("  ✓" if daily_done else ""), 22, "amber_solid")
	btn_daily.custom_minimum_size = Vector2(0, 68)
	btn_daily.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click")
		GameState.active_mode = GameState.PlayMode.DAILY_MOSAIC
		get_tree().change_scene_to_file("res://scenes/GameScene.tscn")
	)
	btn_box.add_child(btn_daily)

	var btn_endless := ThemeManager.make_button("∞  SONSUZ", 22, "emerald")
	btn_endless.custom_minimum_size = Vector2(0, 68)
	btn_endless.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click")
		_endless_modal.visible = true
	)
	btn_box.add_child(btn_endless)

	var btn_league := ThemeManager.make_button("🏆  LİG", 22, "purple")
	btn_league.custom_minimum_size = Vector2(0, 68)
	btn_league.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click")
		get_tree().change_scene_to_file("res://scenes/WeeklyCohort.tscn")
	)
	btn_box.add_child(btn_league)
	main_vbox.add_child(btn_box)

	# 6) REKLAM YER TUTUCU (NO ADS alındığında kalıcı olarak gizlenir)
	if not GameState.no_ads:
		var ad_bar := ThemeManager.make_button("AD  ·  🚫 NO ADS", 14, "stone", 10)
		ad_bar.custom_minimum_size = Vector2(0, 40)
		ad_bar.pressed.connect(func() -> void:
			AudioManager.play_sfx("ui_click")
			get_tree().change_scene_to_file("res://scenes/ShopScene.tscn")
		)
		main_vbox.add_child(ad_bar)

	_build_endless_selector_modal()


func _build_endless_selector_modal() -> void:
	_endless_modal = ColorRect.new()
	_endless_modal.color = Color(0.02, 0.05, 0.04, 0.88)
	_endless_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_endless_modal.z_index = 35
	_endless_modal.visible = false

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_endless_modal.add_child(center)

	var dialog := ThemeManager.make_card_panel(true, 22, 20)
	dialog.custom_minimum_size = Vector2(620, 0)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)

	var header := HBoxContainer.new()
	var h_lbl := ThemeManager.make_label("SONSUZ MOD", 28, "gold_light")
	h_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(h_lbl)

	var close_btn := ThemeManager.make_button("✕", 20, "stone")
	close_btn.custom_minimum_size = Vector2(50, 48)
	close_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click")
		_endless_modal.visible = false
	)
	header.add_child(close_btn)
	vb.add_child(header)

	# 2'li Seçim Kartları (Normal Sonsuz vs Özel Sonsuz)
	var cards_hb := HBoxContainer.new()
	cards_hb.add_theme_constant_override("separation", 16)

	cards_hb.add_child(_make_endless_mode_card(
		"▣",
		"NORMAL",
		"8x8",
		GameState.best_normal_endless,
		"emerald",
		func() -> void:
			AudioManager.play_sfx("ui_click")
			GameState.active_mode = GameState.PlayMode.MODE_NORMAL_ENDLESS
			get_tree().change_scene_to_file("res://scenes/GameScene.tscn")
	))

	cards_hb.add_child(_make_endless_mode_card(
		"✦",
		"ÖZEL",
		"RÜN ×1.25",
		GameState.best_special_endless,
		"amber_solid",
		func() -> void:
			AudioManager.play_sfx("ui_click")
			GameState.active_mode = GameState.PlayMode.MODE_SPECIAL_ENDLESS
			get_tree().change_scene_to_file("res://scenes/GameScene.tscn")
	))

	vb.add_child(cards_hb)
	dialog.add_child(vb)
	center.add_child(dialog)
	add_child(_endless_modal)


func _make_endless_mode_card(
	icon_txt: String,
	mode_title: String,
	badge_txt: String,
	best_val: int,
	btn_variant: String,
	on_play: Callable
) -> PanelContainer:
	var card := ThemeManager.make_card_panel(true, 16, 18)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)

	vb.add_child(ThemeManager.make_label(icon_txt, 42, "gold_light", true))
	vb.add_child(ThemeManager.make_label(mode_title, 26, "text_main", true))
	vb.add_child(ThemeManager.make_label(badge_txt, 14, "text_dim", true))

	var best_box := ThemeManager.make_card_panel(false, 10, 8)
	var b_vb := VBoxContainer.new()
	b_vb.add_theme_constant_override("separation", 2)
	b_vb.add_child(ThemeManager.make_label("BEST", 13, "text_dim", true))
	b_vb.add_child(ThemeManager.make_label("%d" % best_val, 28, "gold_light", true))
	best_box.add_child(b_vb)
	vb.add_child(best_box)

	var play_btn := ThemeManager.make_button("▶ OYNA", 20, btn_variant)
	play_btn.custom_minimum_size = Vector2(0, 56)
	play_btn.pressed.connect(on_play)
	vb.add_child(play_btn)

	card.add_child(vb)
	return card


func _make_stat_pill(caption: String, big_num: String, sub_num: String, accent: Color) -> PanelContainer:
	var p := ThemeManager.make_card_panel(false, 12, 10)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.add_child(ThemeManager.make_label(caption, 13, "text_dim", true))
	vb.add_child(ThemeManager.make_label(big_num, 26, accent, true))
	vb.add_child(ThemeManager.make_label(sub_num, 14, "text_main", true))
	p.add_child(vb)
	return p


func _draw_mystic_backdrop() -> void:
	var td: Dictionary = ThemeManager.get_theme_data()
	var sz: Vector2 = _backdrop_canvas.size
	_backdrop_canvas.draw_rect(Rect2(Vector2.ZERO, sz), td["bg_deep"], true)

	var center := Vector2(sz.x * 0.5, sz.y * 0.21)
	var wave: float = sin(_time_acc * 1.2) * 6.0
	_backdrop_canvas.draw_arc(center, 175.0 + wave, 0.0, TAU, 48, Color(0.96, 0.62, 0.04, 0.06), 2.0, true)
	var sec_col: Color = td["accent_secondary"]
	_backdrop_canvas.draw_arc(center, 250.0 - wave, 0.0, TAU, 64, Color(sec_col.r, sec_col.g, sec_col.b, 0.05), 1.5, true)


func _draw_weekly_mosaic_strip() -> void:
	var w: float = _mosaic_strip.size.x
	var gap: float = 10.0
	var tile_w: float = minf(68.0, (w - gap * 6.0) / 7.0)
	var start_x: float = (w - (tile_w * 7.0 + gap * 6.0)) * 0.5
	var today_idx: int = GameState.get_today_weekday_index()
	var pulse: float = 0.5 + 0.5 * sin(_time_acc * 4.5)
	var font: Font = ThemeDB.fallback_font
	var td: Dictionary = ThemeManager.get_theme_data()

	for i in range(7):
		var x: float = start_x + float(i) * (tile_w + gap)
		var r := Rect2(Vector2(x, 2.0), Vector2(tile_w, 40.0))
		var lit: bool = GameState.mosaic_week_days[i]
		if lit:
			var pals: Array = ["jade", "amber", "amethyst", "ruby", "sapphire", "jade", "amber"]
			PieceLibrary.draw_relic_tile(_mosaic_strip, r, str(pals[i]), i, 1.0, 0.45 + 0.45 * pulse)
		else:
			_mosaic_strip.draw_rect(r, td["card_dark"], true)
			var rim: Color = td["border_gold"] if i == today_idx else td["border_stone"]
			_mosaic_strip.draw_rect(r, rim, false, 2.0 if i == today_idx else 1.2)
			PieceLibrary.draw_rune_glyph(_mosaic_strip, r.get_center(), 9.0, i, Color(0.95, 0.93, 0.88, 0.20))

		if font != null:
			var day_col: Color = td["gold_light"] if (lit or i == today_idx) else td["text_dim"]
			_mosaic_strip.draw_string(
				font,
				Vector2(x, 58.0),
				str(DAY_LETTERS[i]),
				HORIZONTAL_ALIGNMENT_CENTER,
				tile_w,
				13,
				day_col
			)
