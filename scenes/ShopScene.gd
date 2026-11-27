extends Control
## Pazar (Market): No Ads altın kartı, Güçlendiriciler (Çekiç, Yenile, Bomba)
## ve Temalar (Zümrüt Tapınak, Obsidyen Altın, Buzul Rünü).
## Hem tam ekran sahne hem de oyun içi modal katman olarak çalışır.

signal shop_closed

var is_overlay: bool = false
var _bg_rect: ColorRect
var _main_vbox: VBoxContainer


func _ready() -> void:
	_bg_rect = ColorRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg_rect)
	move_child(_bg_rect, 0)

	_main_vbox = $SafeMargin/MainVBox
	_main_vbox.add_theme_constant_override("separation", 16)

	ThemeManager.theme_changed.connect(_on_theme_changed)
	_rebuild_shop()


func _on_theme_changed(_tid: String) -> void:
	_rebuild_shop.call_deferred()


func _rebuild_shop() -> void:
	var td: Dictionary = ThemeManager.get_theme_data()
	_bg_rect.color = Color(0.02, 0.04, 0.03, 0.96) if is_overlay else td["bg_deep"]

	for ch in _main_vbox.get_children():
		ch.queue_free()

	# 1) ÜST BAR (Geri + PAZAR + Altın Bakiyesi)
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 12)

	var back_btn := ThemeManager.make_button("← GERİ", 18, "stone")
	back_btn.custom_minimum_size = Vector2(118, 52)
	back_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click")
		if is_overlay:
			shop_closed.emit()
			queue_free()
		else:
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	top_bar.add_child(back_btn)

	var title_lbl := ThemeManager.make_label("PAZAR", 28, "gold_light", true)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title_lbl)

	var coin_pill := ThemeManager.make_card_panel(true, 14, 8)
	coin_pill.custom_minimum_size = Vector2(140, 52)
	var coin_lbl := ThemeManager.make_label("🪙 %d" % GameState.coins, 22, "gold_light", true)
	coin_pill.add_child(coin_lbl)
	top_bar.add_child(coin_pill)
	_main_vbox.add_child(top_bar)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var content_vb := VBoxContainer.new()
	content_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vb.add_theme_constant_override("separation", 18)
	scroll.add_child(content_vb)
	_main_vbox.add_child(scroll)

	# 2) NO ADS (EN ÜSTTE ALTIN KART)
	var no_ads_card := PanelContainer.new()
	no_ads_card.add_theme_stylebox_override(
		"panel",
		ThemeManager.make_card_style(Color("#2D1F08"), Color("#F59E0B"), 18, 18, 16)
	)
	var na_hb := HBoxContainer.new()
	na_hb.add_theme_constant_override("separation", 14)

	var na_icon := ThemeManager.make_label("🚫", 38, "gold_light", true)
	na_icon.custom_minimum_size = Vector2(56, 0)
	na_hb.add_child(na_icon)

	var na_vb := VBoxContainer.new()
	na_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	na_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	na_vb.add_child(ThemeManager.make_label("NO ADS", 26, "gold_light"))
	na_vb.add_child(ThemeManager.make_label("Banner reklam yok", 15, "text_dim"))
	na_hb.add_child(na_vb)

	if GameState.no_ads:
		var badge := ThemeManager.make_button("✓ AKTİF", 19, "emerald")
		badge.disabled = true
		badge.custom_minimum_size = Vector2(150, 56)
		na_hb.add_child(badge)
	else:
		var buy_na := ThemeManager.make_button("VIP AÇ", 20, "amber_solid")
		buy_na.custom_minimum_size = Vector2(150, 56)
		buy_na.pressed.connect(func() -> void:
			if GameState.purchase_no_ads():
				AudioManager.play_sfx("purchase")
				_rebuild_shop.call_deferred()
		)
		na_hb.add_child(buy_na)

	no_ads_card.add_child(na_hb)
	content_vb.add_child(no_ads_card)

	# 3) GÜÇLENDİRİCİLER (3 TOK KART)
	content_vb.add_child(ThemeManager.make_label("GÜÇLENDİRİCİLER", 18, "text_dim"))

	var boost_row := HBoxContainer.new()
	boost_row.add_theme_constant_override("separation", 10)
	boost_row.add_child(_make_booster_card("hammer", "🔨", "ÇEKİÇ"))
	boost_row.add_child(_make_booster_card("rotate", "⟳", "DÖNDÜR"))
	boost_row.add_child(_make_booster_card("refresh", "🔄", "YENİLE"))
	boost_row.add_child(_make_booster_card("bomb", "💣", "BOMBA"))
	content_vb.add_child(boost_row)

	# 4) TEMALAR
	content_vb.add_child(ThemeManager.make_label("TEMALAR", 18, "text_dim"))

	var themes_vb := VBoxContainer.new()
	themes_vb.add_theme_constant_override("separation", 12)
	for tid_var in ThemeManager.THEME_ORDER:
		var tid: String = str(tid_var)
		themes_vb.add_child(_make_theme_card(tid))
	content_vb.add_child(themes_vb)


func _make_booster_card(booster_id: String, icon_str: String, short_name: String) -> PanelContainer:
	var cost: int = int(GameState.BOOSTER_COSTS[booster_id])
	var owned: int = GameState.get_booster_count(booster_id)
	var can_afford: bool = (GameState.coins >= cost)

	var card := ThemeManager.make_card_panel(false, 12, 14)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)

	vb.add_child(ThemeManager.make_label(icon_str, 36, "gold_light", true))
	vb.add_child(ThemeManager.make_label(short_name, 18, "text_main", true))
	vb.add_child(ThemeManager.make_label("x%d" % owned, 22, "gold_light", true))

	var buy_btn := ThemeManager.make_button("🪙 %d" % cost, 18, "gold" if can_afford else "stone")
	buy_btn.custom_minimum_size = Vector2(0, 50)
	buy_btn.disabled = not can_afford
	buy_btn.pressed.connect(func() -> void:
		if GameState.buy_booster(booster_id):
			AudioManager.play_sfx("purchase")
			_rebuild_shop.call_deferred()
		else:
			AudioManager.play_sfx("cancel")
	)
	vb.add_child(buy_btn)
	card.add_child(vb)
	return card


func _make_theme_card(theme_id: String) -> PanelContainer:
	var t_data: Dictionary = ThemeManager.get_theme_data(theme_id)
	var cost: int = int(t_data["cost"])
	var unlocked: bool = GameState.is_theme_unlocked(theme_id)
	var equipped: bool = (GameState.active_theme == theme_id)

	var card := PanelContainer.new()
	var border_col: Color = t_data["border_gold"] if equipped else t_data["border_stone"]
	card.add_theme_stylebox_override("panel", ThemeManager.make_card_style(t_data["card_bg"], border_col, 16, 16, 12))

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)

	# Canlı renk önizleme kutusu
	var swatch := Control.new()
	swatch.custom_minimum_size = Vector2(54, 54)
	var swatch_bg: Color = t_data["bg_deep"]
	var swatch_accent: Color = t_data["accent_secondary"]
	swatch.draw.connect(func() -> void:
		swatch.draw_rect(Rect2(Vector2.ZERO, swatch.size), swatch_bg, true)
		swatch.draw_rect(Rect2(Vector2(6, 6), Vector2(42, 42)), swatch_accent, true)
		swatch.draw_rect(Rect2(Vector2.ZERO, swatch.size), Color("#F59E0B"), false, 2.0)
	)
	hb.add_child(swatch)

	var name_lbl := ThemeManager.make_label(str(t_data["name"]).to_upper(), 20, "gold_light" if equipped else "text_main")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(name_lbl)

	if equipped:
		var eq_btn := ThemeManager.make_button("✓ AKTİF", 17, "emerald")
		eq_btn.disabled = true
		eq_btn.custom_minimum_size = Vector2(146, 50)
		hb.add_child(eq_btn)
	elif unlocked:
		var use_btn := ThemeManager.make_button("KUŞAN", 18, "gold")
		use_btn.custom_minimum_size = Vector2(146, 50)
		use_btn.pressed.connect(func() -> void:
			AudioManager.play_sfx("ui_click")
			ThemeManager.apply_theme(theme_id)
		)
		hb.add_child(use_btn)
	else:
		var can_buy: bool = (GameState.coins >= cost)
		var unlock_btn := ThemeManager.make_button("🪙 %d" % cost, 18, "amber_solid" if can_buy else "stone")
		unlock_btn.disabled = not can_buy
		unlock_btn.custom_minimum_size = Vector2(146, 50)
		unlock_btn.pressed.connect(func() -> void:
			if GameState.unlock_and_equip_theme(theme_id, cost):
				AudioManager.play_sfx("purchase")
				ThemeManager.apply_theme(theme_id)
		)
		hb.add_child(unlock_btn)

	card.add_child(hb)
	return card
