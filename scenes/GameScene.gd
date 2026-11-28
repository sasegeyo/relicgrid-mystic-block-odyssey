extends Control
## Oyun Sahnesi: Camera2D sarsıntı desteği, ayrı Kombo/Durum bildirim alanları,
## canlı Combo Grace HUD, All-Clear & Yeni Rekor, 4'lü Güçlendirici barı (Çekiç/Döndür/Yenile/Bomba),
## 1500 puan / 3+ hat ödül döngüsü, otomatik kayıt/devam, Revive ve Duraklatma/Titreşim kontrolleri.

const ShopScenePacked := preload("res://scenes/ShopScene.tscn")
const DAY_LETTERS: Array = ["P", "S", "Ç", "P", "C", "C", "P"]
const HYPE_WORDS: Array = ["HARİKA!", "MÜKEMMEL!", "EFSANE!", "DURDURULAMAZ!"]

var level_config: Dictionary = {}
var current_score: int = 0
var displayed_score: float = 0.0
var broken_obstacles: int = 0
var target_score: int = 0
var target_obstacles: int = 0
var session_ended: bool = false
var is_paused: bool = false

var _revive_used: bool = false
## Oyun sonu ekranında ödüllü teklif (devam et / 2x altın) gösterildi mi, alındı mı?
var _offer_shown: bool = false
## Bu oyun günlük görevde 'oyun bitir' olarak sayıldı mı (revive sonrası tekrar sayılmasın)
var _quest_game_counted: bool = false
var _offer_taken: bool = false
# Revive öncesi Game Over'da ödülü verilmiş skor (aynı puanlar iki kez ödüllendirilmesin)
var _rewarded_score: int = 0
var _next_booster_score: int = 1500
var _run_initial_best: int = 0
var _new_best_announced: bool = false
var _record_zone_active: bool = false
var _record_banner: PanelContainer
var _record_banner_lbl: Label
var _stuck_offer_active: bool = false

var grid_board: GridBoard
var piece_tray: PieceTray

# Üst Bar ve HUD
var _bg_rect: ColorRect
var _title_lbl: Label
var _coin_lbl: Label
var _sound_btn: Button
var _score_val_lbl: Label
var _mid_cap_lbl: Label
var _mid_val_lbl: Label
var _right_cap_lbl: Label
var _right_val_lbl: Label
var _progress_bar_canvas: Control

# Canlı Combo Grace HUD + Ayrı Popup Alanları (Ezilme Bug Fix)
var _combo_grace_row: HBoxContainer
var _combo_hud_label: Label
var _combo_grace_bar: ProgressBar
var _combo_label: Label
var _status_label: Label
var _combo_tween: Tween = null
var _status_tween: Tween = null

# Güçlendirici Butonları
var _btn_hammer: Button
var _btn_rotate: Button
var _btn_refresh: Button
var _btn_bomb: Button
var _btn_give_up: Button
var _ad_banner_btn: Button

# Modal Katmanı
var _modal_backdrop: ColorRect
var _modal_box: VBoxContainer
var _modal_pulse: float = 0.0
var _modal_mosaic_strip: Control = null


func _ready() -> void:
	_ensure_camera2d()
	_build_layout()
	GameState.state_updated.connect(_sync_economy_ui)
	DailyQuests.quest_completed.connect(_on_quest_completed)
	ThemeManager.theme_changed.connect(_on_theme_changed)

	if not _try_resume_saved_run():
		_start_configured_level(true)


func _ensure_camera2d() -> void:
	var cam := Camera2D.new()
	cam.name = "GameCamera2D"
	# Sol üst köşeye sabitle: farklı ekran oranlarında (uzun telefonlar, tablet)
	# arayüz kaymasın ve dokunma koordinatları çizimle aynı kalsın.
	# Sarsıntı efekti sadece cam.offset ile çalışır.
	cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	cam.position = Vector2.ZERO
	cam.enabled = true
	add_child(cam)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not session_ended and grid_board != null and piece_tray != null:
			save_current_progress()
		AdManager.note_session_interrupted()


func _process(delta: float) -> void:
	_modal_pulse += delta
	if _is_actively_playing():
		AdManager.add_play_time(delta)
	if absf(displayed_score - float(current_score)) > 0.4:
		displayed_score = lerpf(displayed_score, float(current_score), clampf(delta * 12.0, 0.0, 1.0))
		if absf(displayed_score - float(current_score)) < 1.0:
			displayed_score = float(current_score)
		_score_val_lbl.text = str(int(round(displayed_score)))
	if _modal_mosaic_strip != null and is_instance_valid(_modal_mosaic_strip):
		_modal_mosaic_strip.queue_redraw()


func _on_theme_changed(_tid: String) -> void:
	if _bg_rect != null:
		_bg_rect.color = ThemeManager.get_color("bg_deep")
	if _progress_bar_canvas != null:
		_progress_bar_canvas.queue_redraw()


func _build_layout() -> void:
	_bg_rect = ColorRect.new()
	_bg_rect.color = ThemeManager.get_color("bg_deep")
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_rect)
	move_child(_bg_rect, 0)

	var root_vbox: VBoxContainer = $SafeMargin/RootVBox
	root_vbox.add_theme_constant_override("separation", 8)

	# 1) ÜST BAR
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)

	var pause_btn := ThemeManager.make_button("", 20, "stone", 14, "pause")
	pause_btn.custom_minimum_size = Vector2(64, 60)
	pause_btn.pressed.connect(toggle_pause)
	top_bar.add_child(pause_btn)

	_title_lbl = ThemeManager.make_title("BÖLÜM 1", 32, "gold_light", false)
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(_title_lbl)

	var coin_info: Dictionary = ThemeManager.make_coin_pill(GameState.coins, 24)
	_coin_lbl = coin_info["label"]
	top_bar.add_child(coin_info["panel"])

	var shop_btn := ThemeManager.make_button("", 20, "amber_solid", 14, "shop")
	shop_btn.custom_minimum_size = Vector2(64, 60)
	shop_btn.pressed.connect(_open_shop_overlay)
	top_bar.add_child(shop_btn)

	_sound_btn = ThemeManager.make_button("", 20, "stone", 14, "mute" if AudioManager.sound_muted else "sound")
	_sound_btn.custom_minimum_size = Vector2(64, 60)
	_sound_btn.pressed.connect(toggle_sound)
	top_bar.add_child(_sound_btn)
	root_vbox.add_child(top_bar)

	# 2) TOK HUD PANELİ + CANLI COMBO GRACE HUD
	var hud_panel := ThemeManager.make_card_panel(false, 14, 9)
	var hud_vb := VBoxContainer.new()
	hud_vb.add_theme_constant_override("separation", 6)

	var metrics_row := HBoxContainer.new()
	metrics_row.add_theme_constant_override("separation", 10)

	var col1 := VBoxContainer.new()
	col1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col1.add_child(ThemeManager.make_label("SKOR", 16, "text_dim", true))
	_score_val_lbl = ThemeManager.make_label("0", 46, "gold_light", true)
	col1.add_child(_score_val_lbl)
	metrics_row.add_child(col1)

	var col2 := VBoxContainer.new()
	col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mid_cap_lbl = ThemeManager.make_label("HEDEF", 16, "text_dim", true)
	col2.add_child(_mid_cap_lbl)
	_mid_val_lbl = ThemeManager.make_label("0", 32, "text_main", true)
	col2.add_child(_mid_val_lbl)
	metrics_row.add_child(col2)

	var col3 := VBoxContainer.new()
	col3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_cap_lbl = ThemeManager.make_label("ENGEL", 16, "text_dim", true)
	col3.add_child(_right_cap_lbl)
	_right_val_lbl = ThemeManager.make_label("0", 32, Color("#34D399"), true)
	col3.add_child(_right_val_lbl)
	metrics_row.add_child(col3)
	hud_vb.add_child(metrics_row)

	_progress_bar_canvas = Control.new()
	_progress_bar_canvas.custom_minimum_size = Vector2(0, 10)
	_progress_bar_canvas.draw.connect(_draw_goal_progress_bar)
	hud_vb.add_child(_progress_bar_canvas)

	# Canlı Combo Grace Satırı ("COMBO x3 (2 hamle)" + ProgressBar)
	_combo_grace_row = HBoxContainer.new()
	_combo_grace_row.add_theme_constant_override("separation", 10)
	_combo_grace_row.visible = false

	_combo_hud_label = ThemeManager.make_label("COMBO x1 (2 hamle)", 14, "gold_light")
	_combo_grace_row.add_child(_combo_hud_label)

	_combo_grace_bar = ProgressBar.new()
	_combo_grace_bar.min_value = 0.0
	_combo_grace_bar.max_value = 2.0
	_combo_grace_bar.value = 2.0
	_combo_grace_bar.show_percentage = false
	_combo_grace_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_combo_grace_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_combo_grace_bar.custom_minimum_size = Vector2(0, 10)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color("#08130F")
	bg_sb.set_corner_radius_all(5)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = Color("#F59E0B")
	fill_sb.set_corner_radius_all(5)
	_combo_grace_bar.add_theme_stylebox_override("background", bg_sb)
	_combo_grace_bar.add_theme_stylebox_override("fill", fill_sb)
	_combo_grace_row.add_child(_combo_grace_bar)
	hud_vb.add_child(_combo_grace_row)

	hud_panel.add_child(hud_vb)
	root_vbox.add_child(hud_panel)

	# 3) AYRI SİSTEM DURUM BİLDİRİM ALANI (status_label — combo_label'ı asla ezmez)
	_record_banner = PanelContainer.new()
	var rb_sb := StyleBoxFlat.new()
	rb_sb.bg_color = Color("#362508")
	rb_sb.border_color = Color("#F59E0B")
	rb_sb.set_border_width_all(3)
	rb_sb.set_corner_radius_all(16)
	rb_sb.content_margin_left = 16
	rb_sb.content_margin_right = 16
	rb_sb.content_margin_top = 8
	rb_sb.content_margin_bottom = 8
	_record_banner.add_theme_stylebox_override("panel", rb_sb)
	var rb_hb := HBoxContainer.new()
	rb_hb.add_theme_constant_override("separation", 10)
	rb_hb.add_child(ThemeManager.make_icon("flame", 26, Color("#FCD34D")))
	var rb_title := ThemeManager.make_label("REKOR BÖLGESİ", 22, Color("#FEF08A"))
	rb_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rb_hb.add_child(rb_title)
	_record_banner_lbl = ThemeManager.make_label("", 20, Color("#FCD34D"))
	rb_hb.add_child(_record_banner_lbl)
	_record_banner.add_child(rb_hb)
	_record_banner.visible = false
	root_vbox.add_child(_record_banner)

	_status_label = ThemeManager.make_label("", 16, Color("#34D399"), true)
	_status_label.custom_minimum_size = Vector2(0, 24)
	_status_label.modulate.a = 0.0
	root_vbox.add_child(_status_label)

	# 4) ANA IZGARA TAHTASI (GridBoard)
	grid_board = GridBoard.new()
	grid_board.name = "GridBoard"
	grid_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_board.custom_minimum_size = Vector2(0, 480)
	grid_board.booster_executed.connect(_on_board_booster_executed)
	grid_board.combo_changed.connect(_on_combo_changed)
	root_vbox.add_child(grid_board)

	# 5) 4'LÜ GÜÇLENDİRİCİ BAR (Çekiç, Döndür, Yenile, Bomba + Opsiyonel Bitir)
	var booster_row := HBoxContainer.new()
	booster_row.add_theme_constant_override("separation", 8)

	_btn_hammer = ThemeManager.make_button("x0", 24, "stone", 16, "hammer")
	_btn_hammer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_hammer.custom_minimum_size = Vector2(0, 50)
	_btn_hammer.pressed.connect(func() -> void: _on_booster_pressed("hammer"))
	booster_row.add_child(_btn_hammer)

	_btn_rotate = ThemeManager.make_button("x0", 24, "stone", 16, "rotate")
	_btn_rotate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_rotate.custom_minimum_size = Vector2(0, 50)
	_btn_rotate.pressed.connect(func() -> void: _on_booster_pressed("rotate"))
	booster_row.add_child(_btn_rotate)

	_btn_refresh = ThemeManager.make_button("x0", 24, "stone", 16, "refresh")
	_btn_refresh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_refresh.custom_minimum_size = Vector2(0, 50)
	_btn_refresh.pressed.connect(func() -> void: _on_booster_pressed("refresh"))
	booster_row.add_child(_btn_refresh)

	_btn_bomb = ThemeManager.make_button("x0", 24, "stone", 16, "bomb")
	_btn_bomb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_bomb.custom_minimum_size = Vector2(0, 50)
	_btn_bomb.pressed.connect(func() -> void: _on_booster_pressed("bomb"))
	booster_row.add_child(_btn_bomb)

	_btn_give_up = ThemeManager.make_button("BİTİR", 15, "danger")
	_btn_give_up.custom_minimum_size = Vector2(78, 50)
	_btn_give_up.visible = false
	_btn_give_up.pressed.connect(_trigger_game_over)
	booster_row.add_child(_btn_give_up)

	root_vbox.add_child(booster_row)

	# 6) 3 PARÇALI ALT TEPSİ
	piece_tray = PieceTray.new()
	piece_tray.name = "PieceTray"
	piece_tray.custom_minimum_size = Vector2(0, 172)
	piece_tray.z_index = 15
	piece_tray.piece_placed_from_tray.connect(_on_piece_placed)
	piece_tray.no_moves_remaining.connect(_on_no_moves_remaining)
	piece_tray.rescue_triggered.connect(_on_rescue_triggered)
	piece_tray.piece_rotated.connect(_on_piece_rotated)
	piece_tray.symmetric_rotate_rejected.connect(_on_symmetric_rotate_rejected)
	root_vbox.add_child(piece_tray)

	# 7) REKLAM YER TUTUCU (NO ADS alındığında kalıcı olarak gizlenir)
	_ad_banner_btn = ThemeManager.make_button("REKLAM  ·  NO ADS", 18, "stone", 10, "noads")
	_ad_banner_btn.custom_minimum_size = Vector2(0, 32)
	_ad_banner_btn.visible = not GameState.no_ads
	_ad_banner_btn.pressed.connect(_open_shop_overlay)
	root_vbox.add_child(_ad_banner_btn)

	# 8) ÜST KOMBO / HYPE POPUP ETİKETİ (combo_label — status_label'dan bağımsız!)
	_combo_label = ThemeManager.make_title("", 56, "gold_light", true)
	_combo_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_combo_label.offset_left = -280
	_combo_label.offset_right = 280
	_combo_label.offset_top = 470
	_combo_label.offset_bottom = 560
	_combo_label.add_theme_color_override("font_outline_color", Color("#06100C"))
	_combo_label.add_theme_constant_override("outline_size", 8)
	_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_label.z_index = 32
	_combo_label.modulate.a = 0.0
	add_child(_combo_label)

	# 9) MODAL KATMANI
	_modal_backdrop = ColorRect.new()
	_modal_backdrop.color = Color(0.02, 0.05, 0.04, 0.86)
	_modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_backdrop.z_index = 40
	_modal_backdrop.visible = false

	var center_wrap := CenterContainer.new()
	center_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_backdrop.add_child(center_wrap)

	var modal_panel := ThemeManager.make_card_panel(true, 22, 20)
	modal_panel.custom_minimum_size = Vector2(560, 0)
	_modal_box = VBoxContainer.new()
	_modal_box.add_theme_constant_override("separation", 14)
	modal_panel.add_child(_modal_box)
	center_wrap.add_child(modal_panel)
	add_child(_modal_backdrop)


func _start_configured_level(clear_save: bool = true) -> void:
	if clear_save:
		BoardSaveManager.clear_saved_run(int(GameState.active_mode))

	session_ended = false
	is_paused = false
	_revive_used = false
	_quest_game_counted = false
	_rewarded_score = 0
	_stuck_offer_active = false
	_btn_give_up.visible = false
	_next_booster_score = 1500
	_new_best_announced = false
	_record_zone_active = false
	_update_record_banner()
	_hide_modal()

	match GameState.active_mode:
		GameState.PlayMode.CAMPAIGN:
			level_config = LevelGenerator.generate_campaign_level(GameState.selected_stage)
			_run_initial_best = GameState.get_stage_best_score(GameState.selected_stage)
		GameState.PlayMode.DAILY_MOSAIC:
			level_config = LevelGenerator.generate_daily_level(GameState.get_today_dict())
			_run_initial_best = 0
		GameState.PlayMode.MODE_NORMAL_ENDLESS:
			level_config = LevelGenerator.generate_normal_endless_level()
			_run_initial_best = GameState.best_normal_endless
		GameState.PlayMode.MODE_SPECIAL_ENDLESS:
			level_config = LevelGenerator.generate_special_endless_level()
			_run_initial_best = GameState.best_special_endless

	current_score = 0
	displayed_score = 0.0
	broken_obstacles = 0
	target_score = int(level_config.get("target_score", 0))
	target_obstacles = int(level_config.get("target_obstacles", 0))

	_title_lbl.text = str(level_config.get("title", "RELICGRID"))
	_score_val_lbl.text = "0"

	grid_board.setup_from_level(level_config)
	var is_special_mode: bool = (GameState.active_mode == GameState.PlayMode.MODE_SPECIAL_ENDLESS)
	piece_tray.setup_tray(
		grid_board,
		int(level_config.get("piece_seed", 12345)),
		int(level_config.get("max_shape_tier", 2)),
		is_special_mode
	)

	_sync_economy_ui()
	_refresh_hud()


# --- OTOMATİK KAYIT VE KALDIĞIN YERDEN DEVAM ---

func save_current_progress() -> void:
	if session_ended or grid_board == null or piece_tray == null:
		return
	var payload: Dictionary = {
		"mode": int(GameState.active_mode),
		"stage": GameState.selected_stage,
		"day_key": GameState.get_today_key(),
		"score": current_score,
		"rewarded_score": _rewarded_score,
		"best_score": maxi(_run_initial_best, current_score),
		"broken_obstacles": broken_obstacles,
		"combo_streak": grid_board.streak_count,
		"moves_since_clear": grid_board.moves_since_clear,
		"jokers_used": piece_tray.jokers_used,
		"rescues_used": piece_tray.rescues_used,
		"hammer": GameState.get_booster_count("hammer"),
		"rotate": GameState.get_booster_count("rotate"),
		"refresh": GameState.get_booster_count("refresh"),
		"next_booster_score": _next_booster_score,
		"revive_used": _revive_used,
		"occupied_cells": grid_board.export_occupied_cells(),
		"tray_slots": piece_tray.export_tray_slots()
	}
	BoardSaveManager.save_run(payload)


func _try_resume_saved_run() -> bool:
	if not BoardSaveManager.has_saved_run(int(GameState.active_mode)):
		return false
	var data: Dictionary = BoardSaveManager.load_run(int(GameState.active_mode))
	if data.is_empty():
		return false
	var saved_mode: int = int(data.get("mode", -1))
	var saved_stage: int = int(data.get("stage", 1))
	if saved_mode != int(GameState.active_mode):
		return false
	if GameState.active_mode == GameState.PlayMode.CAMPAIGN and saved_stage != GameState.selected_stage:
		return false
	# Dünün Günlük Mozaik tahtası bugünün bulmacasının üstüne yüklenmesin.
	if GameState.active_mode == GameState.PlayMode.DAILY_MOSAIC and str(data.get("day_key", "")) != GameState.get_today_key():
		return false

	_start_configured_level(false)
	current_score = maxi(0, int(data.get("score", 0)))
	displayed_score = float(current_score)
	_score_val_lbl.text = str(current_score)
	broken_obstacles = maxi(0, int(data.get("broken_obstacles", 0)))
	_next_booster_score = maxi(1500, int(data.get("next_booster_score", 1500)))
	_revive_used = bool(data.get("revive_used", false))
	_rewarded_score = clampi(int(data.get("rewarded_score", 0)), 0, current_score)
	_new_best_announced = (_run_initial_best > 0 and current_score > _run_initial_best)
	_record_zone_active = _run_initial_best >= 300 and current_score >= int(_run_initial_best * 0.85)
	piece_tray.record_zone = _record_zone_active
	_update_record_banner()

	var occ: Variant = data.get("occupied_cells", [])
	if typeof(occ) == TYPE_ARRAY:
		grid_board.import_occupied_cells(occ)
	grid_board.restore_combo_state(int(data.get("combo_streak", 0)), int(data.get("moves_since_clear", 0)))

	piece_tray.current_score_hint = current_score
	piece_tray.restore_counters(int(data.get("jokers_used", 0)), int(data.get("rescues_used", 0)))
	var saved_tray: Variant = data.get("tray_slots", [])
	if typeof(saved_tray) == TYPE_ARRAY and not (saved_tray as Array).is_empty():
		piece_tray.import_tray_slots(saved_tray)

	# Not: Güçlendirici sayıları zaten GameState kaydında tutuluyor. Burada eski
	# değerleri geri yüklemek, oyun dışında satın alınan/kazanılanları siliyordu.
	_sync_economy_ui()
	_refresh_hud()
	show_status("Kaldığın yerden devam!", Color("#34D399"))
	return true


# --- AYRI POPUP & BİLDİRİM YÖNETİMİ ---

func show_combo_popup(msg: String, col: Color = Color("#FDE68A")) -> void:
	if _combo_label == null:
		return
	_combo_label.text = msg
	_combo_label.add_theme_color_override("font_color", col)
	_combo_label.pivot_offset = _combo_label.size * 0.5
	_combo_label.scale = Vector2(0.6, 0.6)
	_combo_label.modulate.a = 1.0
	if _combo_tween != null and _combo_tween.is_valid():
		_combo_tween.kill()
	_combo_tween = create_tween()
	_combo_tween.tween_property(_combo_label, "scale", Vector2(1.12, 1.12), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_combo_tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.10)
	_combo_tween.tween_interval(0.55)
	_combo_tween.tween_property(_combo_label, "modulate:a", 0.0, 0.30)


func show_status(msg: String, col: Color = Color("#34D399")) -> void:
	if _status_label == null:
		return
	_status_label.text = msg
	_status_label.add_theme_color_override("font_color", col)
	_status_label.modulate.a = 1.0
	if _status_tween != null and _status_tween.is_valid():
		_status_tween.kill()
	_status_tween = create_tween()
	_status_tween.tween_interval(1.6)
	_status_tween.tween_property(_status_label, "modulate:a", 0.0, 0.35)


func _on_combo_changed(combo_streak: int, remaining_grace: int, max_grace: int) -> void:
	if _combo_grace_row == null:
		return
	if combo_streak <= 0:
		_combo_grace_row.visible = false
		return
	_combo_grace_row.visible = true
	_combo_hud_label.text = "COMBO x%d (%d hamle)" % [combo_streak, remaining_grace]
	_combo_grace_bar.max_value = float(maxi(1, max_grace))
	_combo_grace_bar.value = float(remaining_grace)


# --- PAUSE, SES, TİTREŞİM ---

func toggle_pause() -> void:
	if session_ended:
		return
	is_paused = not is_paused
	if is_paused:
		_open_pause_modal()
	else:
		_hide_modal()
		piece_tray.set_interaction_locked(false)


func toggle_sound() -> void:
	var sound_on: bool = AudioManager.toggle_sound()
	if _sound_btn != null:
		_sound_btn.icon = ThemeManager.get_icon("sound" if sound_on else "mute")


func toggle_haptics() -> void:
	AudioManager.toggle_haptics()


# --- EKONOMİ & GÜÇLENDİRİCİLER ---

func _sync_economy_ui() -> void:
	if _coin_lbl != null:
		_coin_lbl.text = str(GameState.coins)
	if _ad_banner_btn != null:
		_ad_banner_btn.visible = not GameState.no_ads
	_update_booster_buttons()


func _update_booster_buttons() -> void:
	var active_b: String = grid_board.active_booster if grid_board != null else ""
	var rot_active: bool = piece_tray.rotate_mode_active if piece_tray != null else false

	if _btn_hammer != null:
		var hc: int = GameState.get_booster_count("hammer")
		_set_booster_btn(_btn_hammer, "hammer", hc, active_b == "hammer")
		_btn_hammer.modulate = Color(1.0, 0.92, 0.65) if active_b == "hammer" else Color.WHITE
	if _btn_rotate != null:
		var rotc: int = GameState.get_booster_count("rotate")
		_set_booster_btn(_btn_rotate, "rotate", rotc, rot_active)
		_btn_rotate.modulate = Color(1.0, 0.92, 0.65) if rot_active else Color.WHITE
	if _btn_refresh != null:
		var rc: int = GameState.get_booster_count("refresh")
		_set_booster_btn(_btn_refresh, "refresh", rc, false)
	if _btn_bomb != null:
		var bc: int = GameState.get_booster_count("bomb")
		_set_booster_btn(_btn_bomb, "bomb", bc, active_b == "bomb")
		_btn_bomb.modulate = Color(1.0, 0.92, 0.65) if active_b == "bomb" else Color.WHITE


## Aktifken "kapat" ikonu, yoksa "+" (mağaza), varsa "xN" gösterir.
func _set_booster_btn(btn: Button, icon_name: String, count: int, active: bool) -> void:
	btn.icon = ThemeManager.get_icon("close" if active else icon_name)
	btn.text = "" if active else (("x%d" % count) if count > 0 else "+")


func _on_booster_pressed(booster_id: String) -> void:
	if session_ended or is_paused:
		return

	if booster_id == "rotate":
		if piece_tray.rotate_mode_active:
			piece_tray.set_rotate_targeting(false)
			_update_booster_buttons()
			return
		if GameState.get_booster_count("rotate") <= 0:
			_open_shop_overlay()
			return
		grid_board.set_booster_targeting("")
		piece_tray.set_rotate_targeting(true)
		AudioManager.play_pickup()
		_update_booster_buttons()
		return

	if grid_board.active_booster == booster_id:
		grid_board.set_booster_targeting("")
		_update_booster_buttons()
		return

	if GameState.get_booster_count(booster_id) <= 0:
		_open_shop_overlay()
		return

	piece_tray.set_rotate_targeting(false)

	if booster_id == "refresh":
		if GameState.consume_booster("refresh"):
			grid_board.set_booster_targeting("")
			_stuck_offer_active = false
			_btn_give_up.visible = false
			piece_tray.use_refresh_booster()
			_sync_economy_ui()
			save_current_progress()
	else:
		AudioManager.play_pickup()
		grid_board.set_booster_targeting(booster_id)
		_update_booster_buttons()


func _on_piece_rotated() -> void:
	GameState.consume_booster("rotate")
	_stuck_offer_active = false
	_btn_give_up.visible = false
	_sync_economy_ui()
	save_current_progress()
	piece_tray.check_moves_still_possible()


func _on_symmetric_rotate_rejected() -> void:
	show_status("Bu şekil zaten simetrik!", Color("#FDE68A"))


func _on_rescue_triggered() -> void:
	show_status("KURTARMA!", Color("#34D399"))
	save_current_progress()


func _on_board_booster_executed(booster_id: String, summary: Dictionary) -> void:
	GameState.consume_booster(booster_id)
	_stuck_offer_active = false
	_btn_give_up.visible = false
	_add_score(int(summary.get("score_gained", 0)))
	broken_obstacles += int(summary.get("obstacles_broken", 0))
	_sync_economy_ui()
	_refresh_hud()
	_check_victory_or_moves()
	if not session_ended:
		save_current_progress()


func _can_any_booster_help() -> bool:
	if GameState.get_booster_count("hammer") > 0 and grid_board.get_occupied_count() > 0:
		return true
	if GameState.get_booster_count("bomb") > 0 and grid_board.get_occupied_count() > 0:
		return true
	if GameState.get_booster_count("refresh") > 0:
		return true
	if GameState.get_booster_count("rotate") > 0 and piece_tray.can_any_rotation_fit():
		return true
	return false


func _open_shop_overlay() -> void:
	AudioManager.play_pickup()
	grid_board.set_booster_targeting("")
	piece_tray.set_rotate_targeting(false)
	_update_booster_buttons()
	piece_tray.set_interaction_locked(true)

	var shop_inst: Control = ShopScenePacked.instantiate()
	shop_inst.set("is_overlay", true)
	shop_inst.z_index = 50
	shop_inst.connect("shop_closed", func() -> void:
		_sync_economy_ui()
		if not session_ended and not is_paused and not _modal_backdrop.visible:
			piece_tray.set_interaction_locked(false)
	)
	add_child(shop_inst)


# --- SKOR, ALL-CLEAR, HYPE VE ÖDÜL DÖNGÜSÜ ---

func _add_score(delta_pts: int) -> void:
	if delta_pts <= 0:
		return
	current_score += delta_pts
	piece_tray.current_score_hint = current_score

	# Rekor Bölgesi: rekorun %85'ine gelince açıkça duyurulur ve parçalar zorlaşır
	if not _record_zone_active and _run_initial_best >= 300 and current_score >= int(_run_initial_best * 0.85):
		_record_zone_active = true
		piece_tray.record_zone = true
		AudioManager.play_booster()
		show_combo_popup("REKOR BÖLGESİ!", Color("#F59E0B"))
		show_status("Parçalar zorlaştı!", Color("#FDE68A"))
	_update_record_banner()

	# İlk kez Best Score geçildiğinde oyun başına 1 kez bildirim + ses
	if not _new_best_announced and _run_initial_best > 0 and current_score > _run_initial_best:
		_new_best_announced = true
		AudioManager.play_new_best()
		show_status("YENİ REKOR!", Color("#FDE68A"))

	# Her 1500 puanda en az sahip olunan güçlendiriciye +1 ödül (tavan 9)
	while current_score >= _next_booster_score:
		_next_booster_score += 1500
		_grant_booster_reward()


## Oyun sonu ekranına "Reklam izle, altını 2'ye katla" butonu ekler (oyun başına 1 kez).
func _add_double_coins_button(coin_amount: int) -> void:
	if coin_amount <= 0:
		return
	_offer_shown = true
	var dbl_btn := ThemeManager.make_button("2X ALTIN  ·  +%d" % coin_amount, 24, "emerald", 16, "video")
	dbl_btn.custom_minimum_size = Vector2(0, 76)
	dbl_btn.pressed.connect(func() -> void:
		dbl_btn.disabled = true
		AdManager.show_rewarded("double_coins", func(completed: bool) -> void:
			if not completed:
				if is_instance_valid(dbl_btn):
					dbl_btn.disabled = false
				return
			_offer_taken = true
			GameState.add_coins(coin_amount, true)
			AudioManager.play_purchase()
			if is_instance_valid(dbl_btn):
				dbl_btn.text = "+%d ALTIN ALINDI" % coin_amount
				dbl_btn.icon = ThemeManager.get_icon("check")
		)
	)
	_modal_box.add_child(dbl_btn)


## Günlük sonucu Wordle gibi paylaşılabilir metin olarak panoya kopyalar.
func _make_share_button(stars: int) -> Button:
	var share_btn := ThemeManager.make_button("SONUCU PAYLAŞ", 22, "purple", 16, "share")
	share_btn.custom_minimum_size = Vector2(0, 66)
	share_btn.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(build_daily_share_text(stars))
		AudioManager.play_ui_click()
		share_btn.text = "KOPYALANDI · YAPIŞTIR & GÖNDER"
		share_btn.icon = ThemeManager.get_icon("check")
	)
	return share_btn


func build_daily_share_text(stars: int) -> String:
	var start: int = int(Time.get_unix_time_from_datetime_string("2026-01-01T00:00:00"))
	var today: int = int(Time.get_unix_time_from_datetime_string(GameState.get_today_key() + "T00:00:00"))
	var day_no: int = maxi(1, int((today - start) / 86400) + 1)
	var star_txt: String = ""
	for i in range(3):
		star_txt += "⭐" if i < stars else "☆"
	var week: String = ""
	var colors: Array = ["🟩", "🟨", "🟪", "🟥", "🟦", "🟩", "🟨"]
	for i in range(7):
		week += str(colors[i]) if GameState.mosaic_week_days[i] else "⬛"
	var lines: Array = [
		"RelicGrid Günlük #%d" % day_no,
		"%s  %d puan" % [star_txt, current_score],
		"🔥 %d günlük seri" % GameState.daily_streak,
		week,
	]
	return "\n".join(lines)


func _on_quest_completed(_text: String) -> void:
	show_status("GÖREV TAMAM!", Color("#34D399"))


func _update_record_banner() -> void:
	if _record_banner == null:
		return
	_record_banner.visible = _record_zone_active
	if not _record_zone_active:
		return
	var left: int = _run_initial_best - current_score
	_record_banner_lbl.text = ("%d puan kaldı" % left) if left > 0 else "REKOR KIRILDI!"


func _grant_booster_reward() -> void:
	var awarded: String = GameState.grant_lowest_booster(9)
	if awarded == "":
		return
	AudioManager.play_booster()
	var label_map: Dictionary = {
		"hammer": "+1 ÇEKİÇ!",
		"rotate": "+1 DÖNDÜR!",
		"refresh": "+1 YENİLE!"
	}
	show_status(str(label_map.get(awarded, "+1 GÜÇLENDİRİCİ!")), Color("#FDE68A"))


func _on_piece_placed(summary: Dictionary) -> void:
	if session_ended:
		return

	_stuck_offer_active = false
	_btn_give_up.visible = false
	_add_score(int(summary.get("score_gained", 0)))
	broken_obstacles += int(summary.get("obstacles_broken", 0))

	var gained_coins: int = int(summary.get("coins_gained", 0))
	if gained_coins > 0:
		GameState.add_coins(gained_coins, true)

	var lines_c: int = int(summary.get("lines_cleared", 0))
	var streak_c: int = int(summary.get("streak_count", 0))

	# Tek hamlede 3+ satır temizlemede ekstra güçlendirici ödülü
	if lines_c >= 3:
		_grant_booster_reward()

	# Türkçe coşku sözleri ve kombo bildirimi
	if lines_c > 0:
		var hype_level: int = maxi(lines_c, streak_c)
		if hype_level >= 3:
			var hype_idx: int = clampi(hype_level - 3, 0, HYPE_WORDS.size() - 1)
			show_combo_popup(str(HYPE_WORDS[hype_idx]), Color("#FDE68A"))
		elif lines_c >= 2:
			show_combo_popup("COMBO x%d!" % lines_c, Color("#F59E0B"))

		# All-Clear Bonusu: Tahta tamamen boşaldıysa +500 * combo!
		if int(summary.get("occupied_count", 1)) == 0:
			var bonus: int = 500 * maxi(1, streak_c)
			_add_score(bonus)
			AudioManager.play_all_clear()
			var b_center: Vector2 = summary.get("board_center_global", grid_board.get_board_center_global())
			JuicyEffectsManager.play_all_clear_celebration(b_center)
			show_combo_popup("TAHTA TEMİZ! +%d" % bonus, Color("#4AE3A7"))

	_refresh_hud(
		float(summary.get("combo_factor", 1.0)),
		float(summary.get("streak_mult", 1.0))
	)
	_check_victory_or_moves()
	if not session_ended:
		save_current_progress()
		# Tepsi bittiyse bu bir doğal ara: baskı eşiği geçildiyse geçiş reklamı +
		# Hediye Çarkı. Rekor Bölgesi'nde ya da büyük kombodan hemen sonra çıkmaz.
		AdManager.note_lines_cleared(lines_c)
		DailyQuests.report("lines", lines_c)
		if lines_c >= 2:
			DailyQuests.report("combo", 1)
		if piece_tray.is_tray_empty():
			AdManager.note_tray_finished()
			_maybe_mid_game_ad.call_deferred(_record_zone_active or lines_c >= 2 or streak_c >= 3)


## Oyuncu bu oyun sonu ekranında ödüllü teklifi gördü ama almadıysa true.
## O an zorunlu reklam gösterilmez (reddettikten hemen sonra reklam = kötü deneyim).
func _declined_offer() -> bool:
	return _offer_shown and not _offer_taken


func _is_actively_playing() -> bool:
	if session_ended or is_paused or grid_board == null or piece_tray == null:
		return false
	if _modal_backdrop != null and _modal_backdrop.visible:
		return false
	return not AdManager.is_showing()


func _maybe_mid_game_ad(protected_moment: bool = false) -> void:
	if not _is_actively_playing():
		return
	piece_tray.set_interaction_locked(true)
	var shown: bool = AdManager.try_mid_game_break(func() -> void:
		if is_instance_valid(piece_tray) and not session_ended and not is_paused:
			piece_tray.set_interaction_locked(false)
		_update_booster_buttons()
	, protected_moment)
	if not shown:
		piece_tray.set_interaction_locked(false)


func _check_victory_or_moves() -> void:
	if session_ended:
		return
	var is_endless: bool = GameState.active_mode in [
		GameState.PlayMode.MODE_NORMAL_ENDLESS,
		GameState.PlayMode.MODE_SPECIAL_ENDLESS
	]
	if not is_endless:
		if current_score >= target_score and broken_obstacles >= target_obstacles:
			_trigger_stage_clear()
			return
	piece_tray.check_moves_still_possible()


func _on_no_moves_remaining() -> void:
	if session_ended:
		return
	var is_endless: bool = GameState.active_mode in [
		GameState.PlayMode.MODE_NORMAL_ENDLESS,
		GameState.PlayMode.MODE_SPECIAL_ENDLESS
	]
	if not is_endless and current_score >= target_score and broken_obstacles >= target_obstacles:
		_trigger_stage_clear()
		return

	_trigger_game_over()


func _refresh_hud(last_combo: float = 1.0, last_streak_mult: float = 1.0) -> void:
	match GameState.active_mode:
		GameState.PlayMode.MODE_NORMAL_ENDLESS:
			_mid_cap_lbl.text = "BEST"
			_mid_val_lbl.text = str(maxi(GameState.best_normal_endless, current_score))
			_right_cap_lbl.text = "KOMBO"
			_right_val_lbl.text = "×%.1f" % last_combo if last_combo > 1.0 else "×1"
		GameState.PlayMode.MODE_SPECIAL_ENDLESS:
			_mid_cap_lbl.text = "BEST"
			_mid_val_lbl.text = str(maxi(GameState.best_special_endless, current_score))
			_right_cap_lbl.text = "SERİ"
			_right_val_lbl.text = "×%.2f" % last_streak_mult if last_streak_mult > 1.0 else ("x%d" % grid_board.streak_count)
		_:
			_mid_cap_lbl.text = "HEDEF"
			_mid_val_lbl.text = str(target_score)
			_right_cap_lbl.text = "ENGEL"
			if target_obstacles > 0:
				_right_val_lbl.text = "%d/%d" % [mini(broken_obstacles, target_obstacles), target_obstacles]
			else:
				_right_val_lbl.text = "—"

	_progress_bar_canvas.queue_redraw()


func _draw_goal_progress_bar() -> void:
	var td: Dictionary = ThemeManager.get_theme_data()
	var sz: Vector2 = _progress_bar_canvas.size
	var full_r := Rect2(Vector2.ZERO, sz)
	_progress_bar_canvas.draw_rect(full_r, td["card_dark"], true)

	var ratio: float = 0.0
	if GameState.active_mode == GameState.PlayMode.MODE_NORMAL_ENDLESS:
		var denom: float = maxf(500.0, float(maxi(GameState.best_normal_endless, 1000)))
		ratio = clampf(float(current_score) / denom, 0.0, 1.0)
	elif GameState.active_mode == GameState.PlayMode.MODE_SPECIAL_ENDLESS:
		var denom_s: float = maxf(800.0, float(maxi(GameState.best_special_endless, 1500)))
		ratio = clampf(float(current_score) / denom_s, 0.0, 1.0)
	else:
		var score_part: float = clampf(float(current_score) / float(maxi(1, target_score)), 0.0, 1.0)
		var obs_part: float = 1.0 if target_obstacles <= 0 else clampf(float(broken_obstacles) / float(target_obstacles), 0.0, 1.0)
		ratio = score_part * 0.65 + obs_part * 0.35

	if ratio > 0.0:
		var fill_r := Rect2(Vector2(2, 2), Vector2(maxf(4.0, (sz.x - 4.0) * ratio), sz.y - 4.0))
		var gold_c: Color = td["border_gold"]
		_progress_bar_canvas.draw_rect(fill_r, gold_c.lerp(Color("#34D399"), ratio), true)
	_progress_bar_canvas.draw_rect(full_r, td["border_stone"], false, 1.5)


func _compute_earned_stars() -> int:
	var thresholds: Array = level_config.get("star_thresholds", [target_score, int(target_score * 1.35), int(target_score * 1.75)])
	var stars: int = 1
	if thresholds.size() >= 2 and current_score >= int(thresholds[1]):
		stars = 2
	if thresholds.size() >= 3 and current_score >= int(thresholds[2]):
		stars = 3
	return stars


func _trigger_stage_clear() -> void:
	session_ended = true
	_offer_shown = false
	_offer_taken = false
	BoardSaveManager.clear_saved_run(int(GameState.active_mode))
	grid_board.set_booster_targeting("")
	piece_tray.set_rotate_targeting(false)
	piece_tray.set_interaction_locked(true)
	AudioManager.play_all_clear()

	var stars: int = _compute_earned_stars()
	var reward_info: Dictionary = {}
	if GameState.active_mode == GameState.PlayMode.CAMPAIGN:
		reward_info = GameState.record_campaign_victory(int(level_config["stage"]), current_score, stars)
	elif GameState.active_mode == GameState.PlayMode.DAILY_MOSAIC:
		reward_info = GameState.record_daily_victory(current_score)

	# Battle Pass XP (bugün zaten bitirilmiş günlük tekrar oynanınca zafer bonusu yok)
	var first_daily: bool = bool(reward_info.get("first_clear_today", false))
	var counts_as_win: bool = GameState.active_mode == GameState.PlayMode.CAMPAIGN or first_daily
	var xp_gain: int = BattlePass.award_game_xp(current_score - _rewarded_score, counts_as_win, stars, first_daily)
	_rewarded_score = current_score

	_clear_modal_children()
	_modal_backdrop.visible = true

	_modal_box.add_child(ThemeManager.make_title("ZAFER!", 48, "gold_light"))
	var star_row := HBoxContainer.new()
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	star_row.add_theme_constant_override("separation", 14)
	for si in range(3):
		star_row.add_child(ThemeManager.make_icon("star", 64, "gold_light" if si < stars else Color(0.25, 0.32, 0.29)))
	_modal_box.add_child(star_row)
	_modal_box.add_child(ThemeManager.make_label("%d" % current_score, 36, "text_main", true))
	_modal_box.add_child(_make_reward_row(int(reward_info.get("coin_gain", 0)), int(reward_info.get("league_gain", 0)), xp_gain))
	_add_double_coins_button(int(reward_info.get("coin_gain", 0)))

	if not _quest_game_counted:
		DailyQuests.report("games", 1)
		_quest_game_counted = true
	DailyQuests.report("score_game", current_score)
	if GameState.active_mode == GameState.PlayMode.CAMPAIGN:
		DailyQuests.report("stage_win", 1)

	if GameState.active_mode == GameState.PlayMode.DAILY_MOSAIC:
		DailyQuests.report("daily", 1)
		_modal_box.add_child(ThemeManager.make_label("%d GÜNLÜK SERİ" % GameState.daily_streak, 24, "gold_light", true))
		_modal_mosaic_strip = Control.new()
		_modal_mosaic_strip.custom_minimum_size = Vector2(0, 66)
		_modal_mosaic_strip.draw.connect(_draw_modal_mosaic_board)
		_modal_box.add_child(_modal_mosaic_strip)
		_modal_box.add_child(_make_share_button(stars))

	if GameState.active_mode == GameState.PlayMode.CAMPAIGN and int(level_config["stage"]) < 500:
		var next_stage: int = int(level_config["stage"]) + 1
		var next_btn := ThemeManager.make_button("BÖLÜM %d" % next_stage, 28, "gold", 16, "play")
		next_btn.custom_minimum_size = Vector2(0, 84)
		next_btn.pressed.connect(func() -> void:
			AudioManager.play_pickup()
			AdManager.on_game_end_continue(func() -> void:
				GameState.selected_stage = next_stage
				GameState.campaign_page = int((next_stage - 1) / 20)
				_start_configured_level(true)
			, _declined_offer())
		)
		_modal_box.add_child(next_btn)

	var replay_btn := ThemeManager.make_button("TEKRAR", 24, "stone", 16, "refresh")
	replay_btn.custom_minimum_size = Vector2(0, 72)
	replay_btn.pressed.connect(func() -> void:
		AudioManager.play_pickup()
		AdManager.on_game_end_continue(func() -> void: _start_configured_level(true), _declined_offer())
	)
	_modal_box.add_child(replay_btn)

	var menu_btn := ThemeManager.make_button("ANA MENÜ", 18, "stone")
	menu_btn.custom_minimum_size = Vector2(0, 50)
	menu_btn.pressed.connect(func() -> void:
		AudioManager.play_pickup()
		AdManager.on_game_end_continue(func() -> void: get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"), _declined_offer())
	)
	_modal_box.add_child(menu_btn)


func _trigger_game_over() -> void:
	session_ended = true
	_offer_shown = false
	_offer_taken = false
	_stuck_offer_active = false
	_btn_give_up.visible = false
	BoardSaveManager.clear_saved_run(int(GameState.active_mode))
	grid_board.set_booster_targeting("")
	piece_tray.set_rotate_targeting(false)
	piece_tray.set_interaction_locked(true)
	AudioManager.play_game_over()

	var res: Dictionary = {}
	if GameState.active_mode == GameState.PlayMode.MODE_NORMAL_ENDLESS:
		res = GameState.record_endless_run(current_score, false, _rewarded_score)
	elif GameState.active_mode == GameState.PlayMode.MODE_SPECIAL_ENDLESS:
		res = GameState.record_endless_run(current_score, true, _rewarded_score)
	else:
		res = GameState.record_failed_attempt_points(current_score, _rewarded_score)
	var xp_gain: int = BattlePass.award_game_xp(current_score - _rewarded_score, false)
	_rewarded_score = current_score
	if not _quest_game_counted:
		DailyQuests.report("games", 1)
		_quest_game_counted = true
	DailyQuests.report("score_game", current_score)

	var lp_gain: int = int(res.get("league_gain", 0))
	var coin_gain: int = int(res.get("coin_gain", 0))
	var new_record: bool = bool(res.get("new_best", false))

	_clear_modal_children()
	_modal_backdrop.visible = true

	_modal_box.add_child(ThemeManager.make_title("YENİ REKOR!" if new_record else "HAMLE YOK", 40, "gold_light" if new_record else Color("#FCA5A5")))
	_modal_box.add_child(ThemeManager.make_label("%d" % current_score, 84, "text_main", true))

	# Rekora ne kadar kaldığını göster (revive için en güçlü motivasyon)
	var best_now: int = _run_initial_best
	if not new_record and best_now > 0 and current_score < best_now:
		_modal_box.add_child(_make_record_gap_box(current_score, best_now))

	# Tek Seferlik İkinci Şans (Revive): SADECE ödüllü reklamla. Altınla veya
	# NO ADS/VIP ile ücretsiz alınamaz.
	if not _revive_used:
		_offer_shown = true
		var revive_btn := ThemeManager.make_button("REKLAM İZLE & DEVAM ET", 28, "amber_solid", 18, "video")
		revive_btn.custom_minimum_size = Vector2(0, 100)
		revive_btn.pressed.connect(func() -> void:
			revive_btn.disabled = true
			AdManager.show_rewarded("revive", func(completed: bool) -> void:
				if completed:
					_offer_taken = true
					revive_game()
				elif is_instance_valid(revive_btn):
					revive_btn.disabled = false
			)
		)
		_modal_box.add_child(revive_btn)

	_add_double_coins_button(coin_gain)
	_modal_box.add_child(_make_reward_row(coin_gain, lp_gain, xp_gain))

	var retry_btn := ThemeManager.make_button("TEKRAR", 26, "gold", 16, "refresh")
	retry_btn.custom_minimum_size = Vector2(0, 80)
	retry_btn.pressed.connect(func() -> void:
		AudioManager.play_pickup()
		AdManager.on_game_end_continue(func() -> void: _start_configured_level(true), _declined_offer())
	)
	_modal_box.add_child(retry_btn)

	var menu_btn := ThemeManager.make_button("ANA MENÜ", 18, "stone")
	menu_btn.custom_minimum_size = Vector2(0, 50)
	menu_btn.pressed.connect(func() -> void:
		AudioManager.play_pickup()
		AdManager.on_game_end_continue(func() -> void: get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"), _declined_offer())
	)
	_modal_box.add_child(menu_btn)


func revive_game() -> void:
	if _revive_used:
		return
	_revive_used = true
	session_ended = false
	_stuck_offer_active = false
	_btn_give_up.visible = false
	_hide_modal()
	grid_board.clear_center_area(1)
	piece_tray.set_interaction_locked(false)
	piece_tray.refill_tray(true)
	save_current_progress()


func _open_pause_modal() -> void:
	AudioManager.play_pickup()
	grid_board.set_booster_targeting("")
	piece_tray.set_rotate_targeting(false)
	_update_booster_buttons()
	piece_tray.set_interaction_locked(true)

	_clear_modal_children()
	_modal_backdrop.visible = true

	_modal_box.add_child(ThemeManager.make_label("DURAKLAT", 30, "gold_light", true))

	var resume_btn := ThemeManager.make_button("DEVAM", 26, "gold", 16, "play")
	resume_btn.custom_minimum_size = Vector2(0, 58)
	resume_btn.pressed.connect(toggle_pause)
	_modal_box.add_child(resume_btn)

	var toggles_hb := HBoxContainer.new()
	toggles_hb.add_theme_constant_override("separation", 12)

	var snd_btn := ThemeManager.make_button("SES: " + ("KAPALI" if AudioManager.sound_muted else "AÇIK"), 16, "stone")
	snd_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	snd_btn.custom_minimum_size = Vector2(0, 50)
	snd_btn.pressed.connect(func() -> void:
		toggle_sound()
		snd_btn.text = "SES: " + ("KAPALI" if AudioManager.sound_muted else "AÇIK")
	)
	toggles_hb.add_child(snd_btn)

	var hap_btn := ThemeManager.make_button("TİTREŞİM: " + ("KAPALI" if AudioManager.haptics_muted else "AÇIK"), 16, "stone")
	hap_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hap_btn.custom_minimum_size = Vector2(0, 50)
	hap_btn.pressed.connect(func() -> void:
		toggle_haptics()
		hap_btn.text = "TİTREŞİM: " + ("KAPALI" if AudioManager.haptics_muted else "AÇIK")
	)
	toggles_hb.add_child(hap_btn)
	_modal_box.add_child(toggles_hb)

	var restart_btn := ThemeManager.make_button("YENİDEN", 22, "stone", 16, "refresh")
	restart_btn.custom_minimum_size = Vector2(0, 52)
	restart_btn.pressed.connect(func() -> void:
		AudioManager.play_pickup()
		_start_configured_level(true)
	)
	_modal_box.add_child(restart_btn)

	if GameState.active_mode == GameState.PlayMode.CAMPAIGN:
		var map_btn := ThemeManager.make_button("HARİTA", 19, "stone")
		map_btn.custom_minimum_size = Vector2(0, 52)
		map_btn.pressed.connect(func() -> void:
			save_current_progress()
			AudioManager.play_pickup()
			get_tree().change_scene_to_file("res://scenes/CampaignMap.tscn")
		)
		_modal_box.add_child(map_btn)

	var menu_btn := ThemeManager.make_button("ANA MENÜ", 18, "stone")
	menu_btn.custom_minimum_size = Vector2(0, 50)
	menu_btn.pressed.connect(func() -> void:
		save_current_progress()
		AudioManager.play_pickup()
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	_modal_box.add_child(menu_btn)


func _draw_modal_mosaic_board() -> void:
	if _modal_mosaic_strip == null:
		return
	var td: Dictionary = ThemeManager.get_theme_data()
	var w: float = _modal_mosaic_strip.size.x
	var gap: float = 8.0
	var tile_w: float = minf(62.0, (w - gap * 6.0) / 7.0)
	var start_x: float = (w - (tile_w * 7.0 + gap * 6.0)) * 0.5
	var today_idx: int = GameState.get_today_weekday_index()
	var pulse: float = 0.5 + 0.5 * sin(_modal_pulse * 6.5)
	var font: Font = ThemeDB.fallback_font

	for i in range(7):
		var x: float = start_x + float(i) * (tile_w + gap)
		var r := Rect2(Vector2(x, 4.0), Vector2(tile_w, 42.0))
		var lit: bool = GameState.mosaic_week_days[i]
		if lit:
			var pals: Array = ["jade", "amber", "amethyst", "ruby", "sapphire", "jade", "amber"]
			PieceLibrary.draw_relic_tile(_modal_mosaic_strip, r, str(pals[i]), i, 1.0, (0.7 + 0.3 * pulse) if i == today_idx else 0.35)
		else:
			_modal_mosaic_strip.draw_rect(r, td["card_dark"], true)
			_modal_mosaic_strip.draw_rect(r, td["border_stone"], false, 1.4)

		if font != null:
			_modal_mosaic_strip.draw_string(
				font,
				Vector2(x, 62.0),
				str(DAY_LETTERS[i]),
				HORIZONTAL_ALIGNMENT_CENTER,
				tile_w,
				13,
				td["gold_light"] if i == today_idx else td["text_dim"]
			)


## Oyun sonu ödül kutuları: ALTIN · LP · XP
func _make_reward_row(coin_gain: int, lp_gain: int, xp_gain: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for item in [[coin_gain, "ALTIN", ThemeManager.get_color("gold_light")], [lp_gain, "LP", Color("#C084FC")], [xp_gain, "XP", Color("#34D399")]]:
		var box := _make_inset_box()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 0)
		vb.add_child(ThemeManager.make_label("+%d" % int(item[0]), 30, item[2], true))
		vb.add_child(ThemeManager.make_label(str(item[1]), 16, "text_dim", true))
		box.add_child(vb)
		row.add_child(box)
	return row


## "Rekora X puan kaldı" + ilerleme çubuğu
func _make_record_gap_box(score: int, best: int) -> PanelContainer:
	var box := _make_inset_box()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	var hb := HBoxContainer.new()
	var l1 := ThemeManager.make_label("Rekora %d puan kaldı" % (best - score), 26, "gold_light")
	l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l1)
	hb.add_child(ThemeManager.make_label("Rekor %d" % best, 18, "text_dim"))
	vb.add_child(hb)
	var bar := ProgressBar.new()
	bar.max_value = best
	bar.value = score
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = ThemeManager.get_color("bg_deep")
	bg_sb.border_color = ThemeManager.get_color("border_stone")
	bg_sb.set_border_width_all(1)
	bg_sb.set_corner_radius_all(4)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = Color("#F59E0B")
	fill_sb.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg_sb)
	bar.add_theme_stylebox_override("fill", fill_sb)
	vb.add_child(bar)
	box.add_child(vb)
	return box


func _make_inset_box() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeManager.get_color("card_dark")
	sb.border_color = ThemeManager.get_color("border_stone")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	return p


func _clear_modal_children() -> void:
	_modal_mosaic_strip = null
	for ch in _modal_box.get_children():
		ch.queue_free()


func _hide_modal() -> void:
	_modal_mosaic_strip = null
	_modal_backdrop.visible = false
