extends Control
## Ana Menü: Tok ve sade arayüz, Pazar & Altın barı, 7 günlük rün şeridi
## ve 2'li Sonsuz Mod (Normal / Özel) seçim penceresi.

const DAY_LETTERS: Array = ["P", "S", "Ç", "P", "C", "C", "P"]

const QuestsPanelScript := preload("res://scripts/QuestsPanel.gd")

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
	main_vbox.add_theme_constant_override("separation", 22)
	for ch in main_vbox.get_children():
		ch.queue_free()
	if _endless_modal != null and is_instance_valid(_endless_modal):
		_endless_modal.queue_free()
		_endless_modal = null

	# 1) ÜST BAR (Altın + Pazar + Ses)
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 12)
	top_bar.add_child(ThemeManager.make_coin_pill(GameState.coins, 28)["panel"])

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	var quest_btn := ThemeManager.make_button("", 24, "emerald", 18, "quest")
	quest_btn.custom_minimum_size = Vector2(76, 72)
	quest_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click")
		var panel: Control = QuestsPanelScript.new()
		panel.closed.connect(func() -> void: _rebuild_menu.call_deferred())
		add_child(panel)
	)
	var quest_left: int = DailyQuests.get_claimable_count()
	if quest_left > 0:
		quest_btn.add_child(_make_badge(quest_left))
	top_bar.add_child(quest_btn)

	var shop_btn := ThemeManager.make_button("Pazar", 24, "amber_solid", 18, "shop")
	shop_btn.custom_minimum_size = Vector2(0, 72)
	shop_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click")
		get_tree().change_scene_to_file("res://scenes/ShopScene.tscn")
	)
	top_bar.add_child(shop_btn)

	_sound_btn = ThemeManager.make_button("", 24, "stone", 18, "mute" if AudioManager.sound_muted else "sound")
	_sound_btn.custom_minimum_size = Vector2(76, 72)
	_sound_btn.pressed.connect(func() -> void:
		var on: bool = AudioManager.toggle_sound()
		_sound_btn.icon = ThemeManager.get_icon("sound" if on else "mute")
	)
	top_bar.add_child(_sound_btn)
	main_vbox.add_child(top_bar)

	# 2) AMBLEM VE BAŞLIK
	var hero_vb := VBoxContainer.new()
	hero_vb.add_theme_constant_override("separation", 6)
	var crest := Control.new()
	crest.custom_minimum_size = Vector2(0, 128)
	crest.draw.connect(func() -> void:
		var c: Vector2 = crest.size * 0.5
		var pulse: float = 0.5 + 0.5 * sin(_time_acc * 2.6)
		crest.draw_arc(c, 60.0 + pulse * 3.0, 0.0, TAU, 48, Color(0.96, 0.62, 0.04, 0.45), 3.0, true)
		PieceLibrary.draw_relic_tile(crest, Rect2(c - Vector2(40, 40), Vector2(80, 80)), "jade", 0, 1.0, 0.6, true)
	)
	hero_vb.add_child(crest)
	hero_vb.add_child(ThemeManager.make_title("RELICGRID", 72, "gold_light"))
	main_vbox.add_child(hero_vb)

	# 3) 3 İSTATİSTİK KUTUSU
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 16)
	var league_info: Dictionary = GameState.get_current_league_info()
	stats_row.add_child(_make_stat_pill("BÖLÜM", "%d" % GameState.unlocked_stage, "%d yıldız" % GameState.get_total_stars(), ThemeManager.get_color("gold_light")))
	stats_row.add_child(_make_stat_pill("SERİ", "%d gün" % GameState.daily_streak, "en iyi %d" % GameState.best_daily_streak, Color("#34D399")))
	stats_row.add_child(_make_stat_pill("%s LİG" % str(league_info["name"]).to_upper(), _league_rank_text(), "%d LP" % GameState.weekly_points, league_info["accent"]))
	main_vbox.add_child(stats_row)

	# 4) 7 GÜNLÜK MOZAİK RÜN ŞERİDİ
	var mosaic_card := _make_flat_card()
	_mosaic_strip = Control.new()
	_mosaic_strip.custom_minimum_size = Vector2(0, 90)
	_mosaic_strip.draw.connect(_draw_weekly_mosaic_strip)
	mosaic_card.add_child(_mosaic_strip)
	main_vbox.add_child(mosaic_card)

	# 5) ANA MOD BUTONLARI: tek ana buton (Devam) + Kampanya + 2x2 ızgara
	var btn_box := VBoxContainer.new()
	btn_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 16)

	var saved: Dictionary = BoardSaveManager.get_latest_run()
	var has_resume: bool = false
	if not saved.is_empty():
		var is_stale_daily: bool = int(saved.get("mode", -1)) == GameState.PlayMode.DAILY_MOSAIC and str(saved.get("day_key", "")) != GameState.get_today_key()
		has_resume = not is_stale_daily
	if has_resume:
		var btn_resume := ThemeManager.make_button("DEVAM ET  ·  %d puan" % int(saved.get("score", 0)), 34, "emerald", 20, "play")
		btn_resume.custom_minimum_size = Vector2(0, 112)
		btn_resume.pressed.connect(func() -> void:
			AudioManager.play_pickup()
			GameState.active_mode = int(saved.get("mode", 0)) as GameState.PlayMode
			GameState.selected_stage = maxi(1, int(saved.get("stage", 1)))
			get_tree().change_scene_to_file("res://scenes/GameScene.tscn")
		)
		btn_box.add_child(btn_resume)

	var btn_camp := ThemeManager.make_button("KAMPANYA  ·  %d" % GameState.unlocked_stage, 32, "gold", 20, "sword")
	btn_camp.custom_minimum_size = Vector2(0, 100 if has_resume else 112)
	btn_camp.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click")
		GameState.campaign_page = int((GameState.unlocked_stage - 1) / 20)
		get_tree().change_scene_to_file("res://scenes/CampaignMap.tscn")
	)
	btn_box.add_child(btn_camp)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)

	var daily_done: bool = GameState.is_daily_completed_today()
	grid.add_child(_make_mode_button("Günlük", "check" if daily_done else "sun", "amber_solid", func() -> void:
		GameState.active_mode = GameState.PlayMode.DAILY_MOSAIC
		get_tree().change_scene_to_file("res://scenes/GameScene.tscn")
	))
	grid.add_child(_make_mode_button("Sonsuz", "infinity", "emerald", func() -> void:
		_endless_modal.visible = true
	))
	grid.add_child(_make_mode_button("Lig", "trophy", "purple", func() -> void:
		get_tree().change_scene_to_file("res://scenes/WeeklyCohort.tscn")
	))
	var claimable: int = BattlePass.get_claimable_count()
	var pass_btn := _make_mode_button("Sezon · %d" % BattlePass.get_tier(), "medal", "gold", func() -> void:
		get_tree().change_scene_to_file("res://scenes/BattlePassScene.tscn")
	)
	if claimable > 0:
		pass_btn.add_child(_make_badge(claimable))
	grid.add_child(pass_btn)
	btn_box.add_child(grid)
	main_vbox.add_child(btn_box)

	# 6) REKLAM YER TUTUCU (NO ADS alındığında kalıcı olarak gizlenir)
	if not GameState.no_ads:
		var ad_bar := ThemeManager.make_button("REKLAM  ·  NO ADS", 20, "stone", 12, "noads")
		ad_bar.custom_minimum_size = Vector2(0, 64)
		ad_bar.pressed.connect(func() -> void:
			AudioManager.play_sfx("ui_click")
			get_tree().change_scene_to_file("res://scenes/ShopScene.tscn")
		)
		main_vbox.add_child(ad_bar)

	_build_endless_selector_modal()


func _make_mode_button(txt: String, icon_name: String, variant: String, on_press: Callable) -> Button:
	var b := ThemeManager.make_button(txt, 28, variant, 20, icon_name)
	b.custom_minimum_size = Vector2(0, 92)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click")
		on_press.call()
	)
	return b


## Butonun sağ üst köşesindeki kırmızı sayı rozeti.
func _make_badge(n: int) -> Control:
	var badge := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#DC2626")
	sb.set_corner_radius_all(18)
	sb.border_color = ThemeManager.get_color("bg_deep")
	sb.set_border_width_all(3)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	badge.add_theme_stylebox_override("panel", sb)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(ThemeManager.make_label(str(n), 20, Color.WHITE, true))
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -30
	badge.offset_top = -14
	return badge


func _league_rank_text() -> String:
	for e in GameState.get_cohort_standings():
		if bool(e["is_player"]):
			return "#%d" % int(e["rank"])
	return "-"


## İnce taş kenarlı düz kart (istatistik ve mozaik için).
func _make_flat_card() -> PanelContainer:
	var td: Dictionary = ThemeManager.get_theme_data()
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = td["card_bg"]
	sb.border_color = td["border_stone"]
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	return p


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
	var h_lbl := ThemeManager.make_title("SONSUZ MOD", 34, "gold_light", false)
	h_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(h_lbl)

	var close_btn := ThemeManager.make_button("", 20, "stone", 14, "close")
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
		"infinity",
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
		"star",
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

	var ic := ThemeManager.make_icon(icon_txt, 48, "gold_light")
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ic)
	vb.add_child(ThemeManager.make_label(mode_title, 26, "text_main", true))
	vb.add_child(ThemeManager.make_label(badge_txt, 14, "text_dim", true))

	var best_box := ThemeManager.make_card_panel(false, 10, 8)
	var b_vb := VBoxContainer.new()
	b_vb.add_theme_constant_override("separation", 2)
	b_vb.add_child(ThemeManager.make_label("EN İYİ", 15, "text_dim", true))
	b_vb.add_child(ThemeManager.make_label("%d" % best_val, 28, "gold_light", true))
	best_box.add_child(b_vb)
	vb.add_child(best_box)

	var play_btn := ThemeManager.make_button("OYNA", 22, btn_variant, 14, "play")
	play_btn.custom_minimum_size = Vector2(0, 56)
	play_btn.pressed.connect(on_play)
	vb.add_child(play_btn)

	card.add_child(vb)
	return card


func _make_stat_pill(caption: String, big_num: String, sub_num: String, accent: Color) -> PanelContainer:
	var p := _make_flat_card()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.add_child(ThemeManager.make_label(caption, 18, "text_dim", true))
	vb.add_child(ThemeManager.make_label(big_num, 38, accent, true))
	vb.add_child(ThemeManager.make_label(sub_num, 20, "text_main", true))
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
	var tile_w: float = minf(58.0, (w - gap * 6.0) / 7.0)
	var start_x: float = (w - (tile_w * 7.0 + gap * 6.0)) * 0.5
	var today_idx: int = GameState.get_today_weekday_index()
	var pulse: float = 0.5 + 0.5 * sin(_time_acc * 4.5)
	var font: Font = ThemeManager.font_body if ThemeManager.font_body != null else ThemeDB.fallback_font
	var td: Dictionary = ThemeManager.get_theme_data()

	for i in range(7):
		var x: float = start_x + float(i) * (tile_w + gap)
		var r := Rect2(Vector2(x, 2.0), Vector2(tile_w, tile_w))
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
				Vector2(x, tile_w + 26.0),
				str(DAY_LETTERS[i]),
				HORIZONTAL_ALIGNMENT_CENTER,
				tile_w,
				18,
				day_col
			)
