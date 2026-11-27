class_name GridBoard
extends Control
## 8x8 / 9x9 Izgara Tahtası: Object Pooling patlama düğümleri, 2 hamlelik Combo Grace,
## Bomba ilk tur koruması (skip_next_tick), Buz canı (*2/1) & buz-beyaz önizleme,
## Joker (+) çapraz temizleme, dalga patlamaları (distance * 0.035), Revive ve Kayıt/Yükleme.

signal board_resolved(summary: Dictionary)
signal booster_executed(booster_id: String, summary: Dictionary)
signal combo_changed(combo_streak: int, remaining_grace: int, max_grace: int)

const COMBO_GRACE_MAX: int = 2
const COLOR_GOLD_HIGHLIGHT := Color("#F59E0B")
const COLOR_GOLD_GLOW := Color("#FDE68A")
const COLOR_PARCHMENT := Color("#F3EFE6")
const COLOR_ICE_PREVIEW := Color(0.86, 0.96, 1.0, 0.90)

var rows: int = 8
var cols: int = 8
var cells: Array = []

var scoring_mode: String = "standard"
var spawn_dynamic_endless: bool = false
var _turn_counter: int = 0

# Çizim geometrisi
var cell_size: float = 64.0
var cell_gap: float = 5.0
var board_origin: Vector2 = Vector2.ZERO
var board_pixel_size: Vector2 = Vector2.ZERO

# Hayalet önizleme
var ghost_active: bool = false
var ghost_valid: bool = false
var ghost_anchor: Vector2i = Vector2i(-1, -1)
var ghost_piece: Dictionary = {}
var ghost_clear_rows: Array[int] = []
var ghost_clear_cols: Array[int] = []

# Güçlendirici hedefleme modu ("", "hammer", "bomb")
var active_booster: String = ""
var _booster_hover_cell: Vector2i = Vector2i(-1, -1)

# Combo Grace durumu (2 hamlelik tolerans)
var streak_count: int = 0
var moves_since_clear: int = 0

# Object Pool (Sürekli instantiate / queue_free olmadan patlama animasyonları)
var _fx_node_pool: Array[Node] = []
var _pool_tile_tex: ImageTexture = null

# Görsel animasyon durumları
var _pulse_time: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_pool_tile_tex = _build_tile_fx_texture(24)
	resized.connect(_recalculate_metrics)
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_recalculate_metrics()


func _on_theme_changed(_tid: String) -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_pulse_time += delta
	var needs_redraw: bool = ghost_active or (active_booster != "")

	for r in range(rows):
		if r >= cells.size():
			break
		var row_arr: Array = cells[r]
		for c in range(cols):
			var cell: Dictionary = row_arr[c]
			var anim_t: float = float(cell.get("pop_t", 1.0))
			if anim_t < 1.0:
				cell["pop_t"] = minf(1.0, anim_t + delta * 5.5)
				needs_redraw = true
			var flash_t: float = float(cell.get("flash_t", 0.0))
			if flash_t > 0.0:
				cell["flash_t"] = maxf(0.0, flash_t - delta * 3.2)
				needs_redraw = true
			if bool(cell.get("occupied", false)):
				var obs: int = int(cell.get("obstacle", 0))
				if obs == LevelGenerator.ObstacleType.CURSED_SEAL or bool(cell.get("special_rune", false)):
					needs_redraw = true

	if needs_redraw:
		queue_redraw()


func setup_from_level(config: Dictionary) -> void:
	rows = int(config.get("rows", 8))
	cols = int(config.get("cols", 8))
	scoring_mode = str(config.get("scoring_mode", "standard"))
	spawn_dynamic_endless = bool(config.get("spawn_dynamic", false))
	_turn_counter = 0
	streak_count = 0
	moves_since_clear = 0
	active_booster = ""
	_booster_hover_cell = Vector2i(-1, -1)
	clear_ghost_preview()

	var mask: Array = config.get("active_mask", [])
	cells.clear()
	for r in range(rows):
		var row_arr: Array = []
		for c in range(cols):
			var is_active: bool = true
			if r < mask.size() and c < mask[r].size():
				is_active = bool(mask[r][c])
			row_arr.append(_make_empty_cell(is_active))
		cells.append(row_arr)

	var init_list: Array = config.get("initial_cells", [])
	for item in init_list:
		var r: int = int(item["row"])
		var c: int = int(item["col"])
		if _in_bounds(r, c) and bool(cells[r][c]["active"]):
			var obs_t: int = int(item["obstacle"])
			var ice_val: int = int(item.get("ice_layers", 0))
			if obs_t == LevelGenerator.ObstacleType.FROZEN_RELIC and ice_val <= 0:
				ice_val = 2
			cells[r][c] = {
				"active": true,
				"occupied": true,
				"obstacle": obs_t,
				"hp": int(item.get("hp", 1)),
				"max_hp": int(item.get("hp", 1)),
				"ice_layers": ice_val,
				"curse_timer": int(item.get("curse_timer", 0)),
				"curse_max": maxi(1, int(item.get("curse_max", 7))),
				"skip_next_tick": false,
				"palette_id": str(item.get("palette_id", "relic_stone")),
				"rune_id": int(item.get("rune_id", 0)),
				"special_rune": bool(item.get("special_rune", false)),
				"pop_t": 0.0,
				"flash_t": 0.0
			}

	_recalculate_metrics()
	_emit_combo_state()
	queue_redraw()


func _make_empty_cell(is_active: bool) -> Dictionary:
	return {
		"active": is_active,
		"occupied": false,
		"obstacle": LevelGenerator.ObstacleType.NONE,
		"hp": 0,
		"max_hp": 0,
		"ice_layers": 0,
		"curse_timer": 0,
		"curse_max": 7,
		"skip_next_tick": false,
		"palette_id": "jade",
		"rune_id": 0,
		"special_rune": false,
		"pop_t": 1.0,
		"flash_t": 0.0
	}


func _recalculate_metrics() -> void:
	if size.x <= 10.0 or size.y <= 10.0:
		return
	var pad: float = 22.0
	var avail_w: float = maxf(64.0, size.x - pad * 2.0)
	var avail_h: float = maxf(64.0, size.y - pad * 2.0)
	cell_gap = 5.0 if maxi(rows, cols) <= 8 else 4.5
	var max_cw: float = (avail_w - cell_gap * float(cols - 1)) / float(cols)
	var max_ch: float = (avail_h - cell_gap * float(rows - 1)) / float(rows)
	cell_size = floorf(clampf(minf(max_cw, max_ch), 28.0, 74.0))
	board_pixel_size = Vector2(
		cell_size * float(cols) + cell_gap * float(cols - 1),
		cell_size * float(rows) + cell_gap * float(rows - 1)
	)
	board_origin = (size - board_pixel_size) * 0.5
	queue_redraw()


func _in_bounds(r: int, c: int) -> bool:
	return r >= 0 and r < rows and c >= 0 and c < cols


func get_cell_rect(r: int, c: int) -> Rect2:
	var step: float = cell_size + cell_gap
	var pos := board_origin + Vector2(float(c) * step, float(r) * step)
	return Rect2(pos, Vector2(cell_size, cell_size))


func get_cell_global_center(r: int, c: int) -> Vector2:
	return get_global_transform() * get_cell_rect(r, c).get_center()


func get_board_center_global() -> Vector2:
	return get_global_transform() * (board_origin + board_pixel_size * 0.5)


func get_occupied_count() -> int:
	var count: int = 0
	for r in range(rows):
		for c in range(cols):
			if bool(cells[r][c]["active"]) and bool(cells[r][c]["occupied"]):
				count += 1
	return count


func get_bomb_count() -> int:
	var count: int = 0
	for r in range(rows):
		for c in range(cols):
			var cell: Dictionary = cells[r][c]
			if bool(cell["occupied"]) and int(cell["obstacle"]) == LevelGenerator.ObstacleType.CURSED_SEAL:
				count += 1
	return count


func get_remaining_grace_moves() -> int:
	if streak_count <= 0:
		return 0
	return maxi(0, COMBO_GRACE_MAX - moves_since_clear)


func _emit_combo_state() -> void:
	combo_changed.emit(streak_count, get_remaining_grace_moves(), COMBO_GRACE_MAX)


func restore_combo_state(saved_streak: int, saved_moves_since_clear: int) -> void:
	streak_count = maxi(0, saved_streak)
	moves_since_clear = clampi(saved_moves_since_clear, 0, COMBO_GRACE_MAX)
	_emit_combo_state()


# --- OBJECT POOLING (Blok Patlama Düğümleri) ---

func _get_pooled_fx_node() -> Sprite2D:
	while not _fx_node_pool.is_empty():
		var n: Node = _fx_node_pool.pop_back()
		if is_instance_valid(n) and n is Sprite2D:
			var sp: Sprite2D = n
			sp.show()
			return sp
	var fresh := Sprite2D.new()
	fresh.texture = _pool_tile_tex
	fresh.z_index = 18
	add_child(fresh)
	return fresh


func _return_fx_node(sp: Sprite2D) -> void:
	if not is_instance_valid(sp):
		return
	sp.hide()
	_fx_node_pool.append(sp)


func _spawn_pooled_wave_pop(r: int, c: int, col: Color, delay: float) -> void:
	var sp: Sprite2D = _get_pooled_fx_node()
	var rect: Rect2 = get_cell_rect(r, c)
	var tex_sz: float = maxf(1.0, float(_pool_tile_tex.get_width()))
	var base_scale: float = rect.size.x / tex_sz
	sp.position = rect.get_center()
	sp.scale = Vector2(base_scale, base_scale)
	sp.modulate = Color(col.r, col.g, col.b, 0.95)

	if not is_inside_tree():
		_return_fx_node(sp)
		return

	var world_pos: Vector2 = get_cell_global_center(r, c)
	var tw := create_tween()
	if delay > 0.001:
		tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		JuicyEffectsManager.burst_at(world_pos, col, 8)
	)
	tw.tween_property(sp, "scale", Vector2(base_scale * 1.32, base_scale * 1.32), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sp, "scale", Vector2(0.05, 0.05), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(sp, "modulate:a", 0.0, 0.14)
	tw.tween_callback(func() -> void: _return_fx_node(sp))


func _build_tile_fx_texture(px_size: int) -> ImageTexture:
	var img := Image.create(px_size, px_size, false, Image.FORMAT_RGBA8)
	for y in range(px_size):
		for x in range(px_size):
			var edge: bool = (x == 0 or y == 0 or x == px_size - 1 or y == px_size - 1)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.65 if edge else 1.0))
	return ImageTexture.create_from_image(img)


# --- GÜÇLENDİRİCİ (ÇEKİÇ & BOMBA) ---

func set_booster_targeting(booster_id: String) -> void:
	active_booster = booster_id
	_booster_hover_cell = Vector2i(-1, -1)
	if active_booster != "":
		clear_ghost_preview()
	queue_redraw()


func _local_pos_to_cell(local_pos: Vector2) -> Vector2i:
	var step: float = cell_size + cell_gap
	var c: int = int(floor((local_pos.x - board_origin.x + cell_gap * 0.5) / step))
	var r: int = int(floor((local_pos.y - board_origin.y + cell_gap * 0.5) / step))
	if _in_bounds(r, c) and bool(cells[r][c]["active"]):
		return Vector2i(c, r)
	return Vector2i(-1, -1)


func _gui_input(event: InputEvent) -> void:
	if active_booster == "":
		return

	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		_booster_hover_cell = _local_pos_to_cell(mm.position)
		queue_redraw()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var target: Vector2i = _local_pos_to_cell(mb.position)
			if target.x >= 0:
				_try_execute_booster_at(target.y, target.x)
				accept_event()
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			var target: Vector2i = _local_pos_to_cell(st.position)
			if target.x >= 0:
				_try_execute_booster_at(target.y, target.x)
				accept_event()


func _try_execute_booster_at(r: int, c: int) -> void:
	if active_booster == "hammer":
		use_hammer_at(r, c)
	elif active_booster == "bomb":
		use_bomb_at(r, c)


func use_hammer_at(r: int, c: int) -> bool:
	if not _in_bounds(r, c) or not bool(cells[r][c]["active"]) or not bool(cells[r][c]["occupied"]):
		AudioFeedbackManager.play_invalid()
		return false

	var cell: Dictionary = cells[r][c]
	var was_obs: bool = (int(cell["obstacle"]) != LevelGenerator.ObstacleType.NONE)
	var was_special: bool = bool(cell.get("special_rune", false))
	cells[r][c] = _make_empty_cell(true)

	active_booster = ""
	_booster_hover_cell = Vector2i(-1, -1)
	AudioFeedbackManager.play_booster()
	JuicyEffectsManager.shake(6.0, 0.18)
	_spawn_pooled_wave_pop(r, c, COLOR_GOLD_GLOW, 0.0)

	var pts: int = 150 if was_obs else (250 if was_special else 60)
	_spawn_floating_text("+%d" % pts, get_cell_rect(r, c).get_center(), COLOR_GOLD_GLOW, 26)
	queue_redraw()

	var summary: Dictionary = {
		"score_gained": pts,
		"obstacles_broken": 1 if was_obs else 0,
		"coins_gained": 0,
		"occupied_count": get_occupied_count()
	}
	booster_executed.emit("hammer", summary)
	return true


func use_bomb_at(center_r: int, center_c: int) -> bool:
	if not _in_bounds(center_r, center_c) or not bool(cells[center_r][center_c]["active"]):
		AudioFeedbackManager.play_invalid()
		return false

	var hit_any: bool = false
	var obs_broken: int = 0
	var tiles_cleared: int = 0
	var specials_cleared: int = 0

	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			var rr: int = center_r + dr
			var cc: int = center_c + dc
			if not _in_bounds(rr, cc) or not bool(cells[rr][cc]["active"]):
				continue
			if bool(cells[rr][cc]["occupied"]):
				hit_any = true
				if int(cells[rr][cc]["obstacle"]) != LevelGenerator.ObstacleType.NONE:
					obs_broken += 1
				if bool(cells[rr][cc].get("special_rune", false)):
					specials_cleared += 1
				tiles_cleared += 1
				cells[rr][cc] = _make_empty_cell(true)
				var dist: float = Vector2(float(dc), float(dr)).length()
				_spawn_pooled_wave_pop(rr, cc, COLOR_GOLD_HIGHLIGHT, dist * 0.035)

	if not hit_any:
		AudioFeedbackManager.play_invalid()
		return false

	active_booster = ""
	_booster_hover_cell = Vector2i(-1, -1)
	AudioFeedbackManager.play_bomb_explode()
	JuicyEffectsManager.shake(9.5, 0.28)

	var pts: int = tiles_cleared * 40 + obs_broken * 150 + specials_cleared * 250
	_spawn_floating_text("💥 +%d" % pts, get_cell_rect(center_r, center_c).get_center(), COLOR_GOLD_GLOW, 30)
	queue_redraw()

	var summary: Dictionary = {
		"score_gained": pts,
		"obstacles_broken": obs_broken,
		"coins_gained": 0,
		"occupied_count": get_occupied_count()
	}
	booster_executed.emit("bomb", summary)
	return true


## Revive (İkinci Şans): Merkez (2*radius+1)x(2*radius+1) alanı ve value <= 1 kalan kritik bombaları temizler.
func clear_center_area(radius: int = 1) -> void:
	var cr: int = int(rows / 2)
	var cc: int = int(cols / 2)
	for r in range(maxi(0, cr - radius), mini(rows, cr + radius + 1)):
		for c in range(maxi(0, cc - radius), mini(cols, cc + radius + 1)):
			if bool(cells[r][c]["active"]) and bool(cells[r][c]["occupied"]):
				cells[r][c] = _make_empty_cell(true)
				_spawn_pooled_wave_pop(r, c, COLOR_GOLD_GLOW, 0.0)

	# Tahtada patlamak üzere olan (curse_timer <= 1) kritik bombaları da etkisizleştir
	for r in range(rows):
		for c in range(cols):
			var cell: Dictionary = cells[r][c]
			if bool(cell["occupied"]) and int(cell["obstacle"]) == LevelGenerator.ObstacleType.CURSED_SEAL:
				if int(cell["curse_timer"]) <= 1:
					cells[r][c] = _make_empty_cell(true)
					_spawn_pooled_wave_pop(r, c, Color("#F87171"), 0.04)

	AudioFeedbackManager.play_rescue()
	JuicyEffectsManager.shake(7.5, 0.25)
	queue_redraw()


func revive_clear_space() -> void:
	clear_center_area(1)


# --- KAYIT / YÜKLEME ---

func export_occupied_cells() -> Array:
	var out: Array = []
	for r in range(rows):
		for c in range(cols):
			var cell: Dictionary = cells[r][c]
			if bool(cell["active"]) and bool(cell["occupied"]):
				var obs: int = int(cell["obstacle"])
				var block_val: int = int(cell["hp"])
				if obs == LevelGenerator.ObstacleType.FROZEN_RELIC:
					block_val = int(cell["ice_layers"])
				elif obs == LevelGenerator.ObstacleType.CURSED_SEAL:
					block_val = int(cell["curse_timer"])
				out.append({
					"x": c,
					"y": r,
					"color": str(cell["palette_id"]),
					"block_type": obs,
					"block_value": block_val,
					"rune_id": int(cell["rune_id"]),
					"special_rune": bool(cell.get("special_rune", false)),
					"skip_next_tick": bool(cell.get("skip_next_tick", false))
				})
	return out


func import_occupied_cells(saved_cells: Array) -> void:
	for r in range(rows):
		for c in range(cols):
			var was_active: bool = bool(cells[r][c]["active"])
			cells[r][c] = _make_empty_cell(was_active)

	for item_var in saved_cells:
		if typeof(item_var) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_var
		var c: int = int(item.get("x", -1))
		var r: int = int(item.get("y", -1))
		if not _in_bounds(r, c) or not bool(cells[r][c]["active"]):
			continue
		var obs: int = int(item.get("block_type", 0))
		var bval: int = maxi(1, int(item.get("block_value", 1)))
		cells[r][c] = {
			"active": true,
			"occupied": true,
			"obstacle": obs,
			"hp": bval if obs == LevelGenerator.ObstacleType.CRACKED_STONE else 1,
			"max_hp": maxi(2, bval) if obs == LevelGenerator.ObstacleType.CRACKED_STONE else 1,
			"ice_layers": bval if obs == LevelGenerator.ObstacleType.FROZEN_RELIC else 0,
			"curse_timer": bval if obs == LevelGenerator.ObstacleType.CURSED_SEAL else 0,
			"curse_max": maxi(5, bval),
			"skip_next_tick": bool(item.get("skip_next_tick", false)),
			"palette_id": str(item.get("color", "jade")),
			"rune_id": int(item.get("rune_id", 0)),
			"special_rune": bool(item.get("special_rune", false)),
			"pop_t": 1.0,
			"flash_t": 0.0
		}
	queue_redraw()


# --- PARÇA UYUM VE YERLEŞTİRME ---

func can_place_piece(piece_data: Dictionary, anchor: Vector2i) -> bool:
	if piece_data.is_empty() or not piece_data.has("cells"):
		return false
	# Joker (+) dolu hücrenin üstüne bile bırakılabilir!
	if bool(piece_data.get("is_joker", false)):
		return _in_bounds(anchor.y, anchor.x) and bool(cells[anchor.y][anchor.x]["active"])

	for offset in piece_data["cells"]:
		var vp: Vector2i = offset
		var c: int = anchor.x + vp.x
		var r: int = anchor.y + vp.y
		if not _in_bounds(r, c):
			return false
		var cell: Dictionary = cells[r][c]
		if not bool(cell["active"]) or bool(cell["occupied"]):
			return false
	return true


func has_any_valid_move(pieces: Array) -> bool:
	for p in pieces:
		if typeof(p) != TYPE_DICTIONARY or p.is_empty():
			continue
		if can_piece_fit_anywhere(p):
			return true
	return false


func can_piece_fit_anywhere(piece_data: Dictionary) -> bool:
	for r in range(rows):
		for c in range(cols):
			if can_place_piece(piece_data, Vector2i(c, r)):
				return true
	return false


func get_fittable_shapes(shapes: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for sh in shapes:
		if can_piece_fit_anywhere(sh):
			result.append(sh)
	return result


func get_occupancy_ratio() -> float:
	var active_total: int = 0
	var occ_total: int = 0
	for r in range(rows):
		for c in range(cols):
			if bool(cells[r][c]["active"]):
				active_total += 1
				if bool(cells[r][c]["occupied"]):
					occ_total += 1
	if active_total == 0:
		return 0.0
	return float(occ_total) / float(active_total)


func get_remaining_obstacle_count() -> int:
	var total: int = 0
	for r in range(rows):
		for c in range(cols):
			var cell: Dictionary = cells[r][c]
			if bool(cell["occupied"]) and int(cell["obstacle"]) != LevelGenerator.ObstacleType.NONE:
				total += 1
	return total


func update_hover_preview(piece_data: Dictionary, global_visual_center: Vector2) -> Dictionary:
	if piece_data.is_empty():
		clear_ghost_preview()
		return {"valid": false, "anchor": Vector2i(-1, -1)}

	var local_center: Vector2 = get_global_transform().affine_inverse() * global_visual_center
	var step: float = cell_size + cell_gap
	var pw: float = float(piece_data["width"]) * step - cell_gap
	var ph: float = float(piece_data["height"]) * step - cell_gap
	var local_top_left: Vector2 = local_center - Vector2(pw, ph) * 0.5

	var margin: float = step * 1.15
	var board_rect := Rect2(board_origin - Vector2(margin, margin), board_pixel_size + Vector2(margin * 2.0, margin * 2.0))
	if not board_rect.has_point(local_center):
		clear_ghost_preview()
		return {"valid": false, "anchor": Vector2i(-1, -1)}

	var exact_x: float = (local_top_left.x - board_origin.x) / step
	var exact_y: float = (local_top_left.y - board_origin.y) / step
	var best_anchor := Vector2i(int(round(exact_x)), int(round(exact_y)))
	var valid: bool = can_place_piece(piece_data, best_anchor)

	if not valid:
		var best_dist: float = 0.44
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var cand := Vector2i(best_anchor.x + dx, best_anchor.y + dy)
				if can_place_piece(piece_data, cand):
					var dist: float = Vector2(exact_x - float(cand.x), exact_y - float(cand.y)).length()
					if dist < best_dist:
						best_dist = dist
						best_anchor = cand
						valid = true

	ghost_active = valid
	ghost_valid = valid
	ghost_anchor = best_anchor
	ghost_piece = piece_data
	ghost_clear_rows.clear()
	ghost_clear_cols.clear()

	if valid:
		if bool(piece_data.get("is_joker", false)):
			ghost_clear_rows.append(best_anchor.y)
			ghost_clear_cols.append(best_anchor.x)
		else:
			var sim: Dictionary = _simulate_completed_lines(piece_data, best_anchor)
			for rr in sim["rows"]:
				ghost_clear_rows.append(int(rr))
			for cc in sim["cols"]:
				ghost_clear_cols.append(int(cc))

	queue_redraw()
	return {"valid": valid, "anchor": best_anchor}


func clear_ghost_preview() -> void:
	if ghost_active or not ghost_clear_rows.is_empty() or not ghost_clear_cols.is_empty():
		ghost_active = false
		ghost_valid = false
		ghost_piece = {}
		ghost_clear_rows.clear()
		ghost_clear_cols.clear()
		queue_redraw()


func _simulate_completed_lines(piece_data: Dictionary, anchor: Vector2i) -> Dictionary:
	var placed_set: Dictionary = {}
	for offset in piece_data["cells"]:
		var vp: Vector2i = offset
		placed_set[Vector2i(anchor.x + vp.x, anchor.y + vp.y)] = true

	var full_rows: Array[int] = []
	for r in range(rows):
		var active_cnt: int = 0
		var full: bool = true
		for c in range(cols):
			var cell: Dictionary = cells[r][c]
			if not bool(cell["active"]):
				continue
			active_cnt += 1
			if not bool(cell["occupied"]) and not placed_set.has(Vector2i(c, r)):
				full = false
				break
		if active_cnt > 0 and full:
			full_rows.append(r)

	var full_cols: Array[int] = []
	for c in range(cols):
		var active_cnt: int = 0
		var full: bool = true
		for r in range(rows):
			var cell: Dictionary = cells[r][c]
			if not bool(cell["active"]):
				continue
			active_cnt += 1
			if not bool(cell["occupied"]) and not placed_set.has(Vector2i(c, r)):
				full = false
				break
		if active_cnt > 0 and full:
			full_cols.append(c)

	return {"rows": full_rows, "cols": full_cols}


func place_piece(piece_data: Dictionary, anchor: Vector2i) -> Dictionary:
	clear_ghost_preview()
	if not can_place_piece(piece_data, anchor):
		return {"placed": false}

	_turn_counter += 1
	var is_joker: bool = bool(piece_data.get("is_joker", false))
	var pal_id: String = str(piece_data.get("palette_id", "jade"))
	var rune_id: int = int(piece_data.get("rune_id", 0))
	var piece_is_special: bool = bool(piece_data.get("special_rune", false))
	var specs: Dictionary = piece_data.get("specs", {})
	var placed_coords: Array[Vector2i] = []

	if is_joker:
		placed_coords.append(anchor)
	else:
		var idx_in_piece: int = 0
		for offset in piece_data["cells"]:
			var vp: Vector2i = offset
			var c: int = anchor.x + vp.x
			var r: int = anchor.y + vp.y
			var cell_special: bool = (piece_is_special and idx_in_piece == 0)
			var obs_t: int = LevelGenerator.ObstacleType.NONE
			var ice_val: int = 0
			var bomb_val: int = 0
			var skip_tick: bool = false

			# DDA özel parça özellikleri (ilk hücrede buz veya bomba gelebilir)
			if idx_in_piece == 0 and not specs.is_empty():
				var spec_type: String = str(specs.get("type", ""))
				if spec_type == "ice":
					obs_t = LevelGenerator.ObstacleType.FROZEN_RELIC
					ice_val = maxi(1, int(specs.get("value", 2)))
				elif spec_type == "bomb":
					obs_t = LevelGenerator.ObstacleType.CURSED_SEAL
					bomb_val = maxi(4, int(specs.get("value", 8)))
					skip_tick = true # Bomba ilk tur koruması!

			cells[r][c] = {
				"active": true,
				"occupied": true,
				"obstacle": obs_t,
				"hp": 1,
				"max_hp": 1,
				"ice_layers": ice_val,
				"curse_timer": bomb_val,
				"curse_max": maxi(5, bomb_val),
				"skip_next_tick": skip_tick,
				"palette_id": pal_id,
				"rune_id": rune_id,
				"special_rune": cell_special,
				"pop_t": 0.0,
				"flash_t": 0.25
			}
			placed_coords.append(Vector2i(c, r))
			idx_in_piece += 1

	AudioFeedbackManager.play_place()

	# Tamamlanan satır ve sütunları tespit et (Joker kendi satır + sütununu anında temizler)
	var full_rows: Array[int] = []
	var full_cols: Array[int] = []
	if is_joker:
		full_rows.append(anchor.y)
		full_cols.append(anchor.x)
	else:
		for r in range(rows):
			var active_cnt: int = 0
			var all_occ: bool = true
			for c in range(cols):
				if not bool(cells[r][c]["active"]):
					continue
				active_cnt += 1
				if not bool(cells[r][c]["occupied"]):
					all_occ = false
					break
			if active_cnt > 0 and all_occ:
				full_rows.append(r)

		for c in range(cols):
			var active_cnt: int = 0
			var all_occ: bool = true
			for r in range(rows):
				if not bool(cells[r][c]["active"]):
					continue
				active_cnt += 1
				if not bool(cells[r][c]["occupied"]):
					all_occ = false
					break
			if active_cnt > 0 and all_occ:
				full_cols.append(c)

	var lines_count: int = full_rows.size() + full_cols.size()
	var obstacles_broken: int = 0
	var obstacles_damaged: int = 0
	var special_runes_cleared: int = 0
	var ice_cracked_any: bool = false

	var wave_origin: Vector2 = Vector2(float(anchor.x), float(anchor.y))

	if lines_count > 0:
		streak_count += 1
		moves_since_clear = 0

		# Satır ve sütun ışık dalgaları (JuicyEffectsManager.flash_line)
		for r in full_rows:
			var r_center: Vector2 = get_global_transform() * Vector2(
				board_origin.x + board_pixel_size.x * 0.5,
				get_cell_rect(r, 0).get_center().y
			)
			JuicyEffectsManager.flash_line(r_center, Vector2(board_pixel_size.x, cell_size * 0.72), COLOR_GOLD_GLOW)
		for c in full_cols:
			var c_center: Vector2 = get_global_transform() * Vector2(
				get_cell_rect(0, c).get_center().x,
				board_origin.y + board_pixel_size.y * 0.5
			)
			JuicyEffectsManager.flash_line(c_center, Vector2(cell_size * 0.72, board_pixel_size.y), COLOR_GOLD_GLOW)

		var line_cells_map: Dictionary = {}
		for r in full_rows:
			for c in range(cols):
				if bool(cells[r][c]["active"]) and (bool(cells[r][c]["occupied"]) or is_joker):
					line_cells_map[Vector2i(c, r)] = true
		for c in full_cols:
			for r in range(rows):
				if bool(cells[r][c]["active"]) and (bool(cells[r][c]["occupied"]) or is_joker):
					line_cells_map[Vector2i(c, r)] = true

		var cleared_normal_positions: Array[Vector2i] = []
		var handled_cracked: Dictionary = {}

		for coord_var in line_cells_map.keys():
			var coord: Vector2i = coord_var
			var cell: Dictionary = cells[coord.y][coord.x]
			if not bool(cell["occupied"]):
				continue
			var obs: int = int(cell["obstacle"])
			var dist: float = Vector2(float(coord.x) - wave_origin.x, float(coord.y) - wave_origin.y).length()
			var wave_delay: float = dist * 0.035

			if obs == LevelGenerator.ObstacleType.NONE:
				var burst_col: Color = COLOR_GOLD_GLOW if bool(cell.get("special_rune", false)) else PieceLibrary.get_palette(str(cell["palette_id"]))["highlight"]
				if bool(cell.get("special_rune", false)):
					special_runes_cleared += 1
				_spawn_pooled_wave_pop(coord.y, coord.x, burst_col, wave_delay)
				cells[coord.y][coord.x] = _make_empty_cell(true)
				cleared_normal_positions.append(coord)

			elif obs == LevelGenerator.ObstacleType.FROZEN_RELIC:
				var layers: int = int(cell["ice_layers"])
				if layers > 1:
					# Buz çatlar, canı 1'e iner (tamamen silinmez)
					cell["ice_layers"] = layers - 1
					cell["flash_t"] = 1.0
					cell["pop_t"] = 0.25
					obstacles_damaged += 1
					ice_cracked_any = true
					JuicyEffectsManager.burst_at(get_cell_global_center(coord.y, coord.x), Color("#BAE6FD"), 10)
				else:
					# Son buz katmanı kırılır ve taş temizlenir
					cell["ice_layers"] = 0
					cell["obstacle"] = LevelGenerator.ObstacleType.NONE
					cells[coord.y][coord.x] = _make_empty_cell(true)
					obstacles_broken += 1
					obstacles_damaged += 1
					ice_cracked_any = true
					cleared_normal_positions.append(coord)
					_spawn_pooled_wave_pop(coord.y, coord.x, Color("#93C5FD"), wave_delay)

			elif obs == LevelGenerator.ObstacleType.CRACKED_STONE:
				handled_cracked[coord] = true
				cell["hp"] = int(cell["hp"]) - 1
				obstacles_damaged += 1
				if int(cell["hp"]) <= 0:
					cells[coord.y][coord.x] = _make_empty_cell(true)
					obstacles_broken += 1
					cleared_normal_positions.append(coord)
					_spawn_pooled_wave_pop(coord.y, coord.x, Color("#D6C7AE"), wave_delay)
				else:
					cell["flash_t"] = 1.0
					cell["pop_t"] = 0.3
					JuicyEffectsManager.burst_at(get_cell_global_center(coord.y, coord.x), Color("#F59E0B"), 8)

			elif obs == LevelGenerator.ObstacleType.CURSED_SEAL:
				cells[coord.y][coord.x] = _make_empty_cell(true)
				obstacles_broken += 1
				cleared_normal_positions.append(coord)
				_spawn_pooled_wave_pop(coord.y, coord.x, Color("#C084FC"), wave_delay)

		var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for clr_pos in cleared_normal_positions:
			for d in dirs:
				var nb: Vector2i = clr_pos + d
				if not _in_bounds(nb.y, nb.x) or handled_cracked.has(nb):
					continue
				var nb_cell: Dictionary = cells[nb.y][nb.x]
				if bool(nb_cell["occupied"]) and int(nb_cell["obstacle"]) == LevelGenerator.ObstacleType.CRACKED_STONE:
					handled_cracked[nb] = true
					nb_cell["hp"] = int(nb_cell["hp"]) - 1
					obstacles_damaged += 1
					if int(nb_cell["hp"]) <= 0:
						cells[nb.y][nb.x] = _make_empty_cell(true)
						obstacles_broken += 1
						_spawn_pooled_wave_pop(nb.y, nb.x, Color("#D6C7AE"), 0.05)
					else:
						nb_cell["flash_t"] = 1.0
						nb_cell["pop_t"] = 0.35
						JuicyEffectsManager.burst_at(get_cell_global_center(nb.y, nb.x), Color("#FDE68A"), 8)
	else:
		# 2 hamlelik Combo Grace: hemen sıfırlama, 2 boş hamleye kadar koru!
		if streak_count > 0:
			moves_since_clear += 1
			if moves_since_clear >= COMBO_GRACE_MAX:
				streak_count = 0
				moves_since_clear = 0

	var curse_spread_count: int = _tick_cursed_seals()

	if spawn_dynamic_endless and (_turn_counter % 3 == 0):
		_spawn_dynamic_special_tile()

	# Puanlama
	var place_pts: int = placed_coords.size() * 10
	var combo_factor: float = _combo_multiplier_for_lines(lines_count)
	var total_gained: int = 0
	var streak_mult: float = 1.0

	if scoring_mode == LevelGenerator.MODE_NORMAL_ENDLESS:
		var line_pts: int = int(round(float(lines_count * 100) * combo_factor))
		total_gained = place_pts + line_pts
	elif scoring_mode == LevelGenerator.MODE_SPECIAL_ENDLESS:
		var base_clear: float = float(lines_count * 100) * combo_factor
		var obs_pts: float = float(obstacles_broken * 150 + (obstacles_damaged - obstacles_broken) * 35)
		var spec_pts: float = float(special_runes_cleared * 250)
		if lines_count > 0 and streak_count >= 2:
			streak_mult = pow(1.25, float(streak_count - 1))
		total_gained = place_pts + int(round((base_clear + obs_pts + spec_pts) * streak_mult))
	else:
		var line_pts_std: int = int(round(float(lines_count * 100) * combo_factor))
		var streak_bonus: int = (streak_count - 1) * 45 if (lines_count > 0 and streak_count >= 2) else 0
		var obs_pts_std: int = obstacles_broken * 100 + (obstacles_damaged - obstacles_broken) * 25
		total_gained = place_pts + line_pts_std + streak_bonus + obs_pts_std

	var coins_gained: int = 0
	if lines_count > 0:
		coins_gained = lines_count * 4 + maxi(0, lines_count - 1) * 3 + obstacles_broken * 3 + special_runes_cleared * 6

	# Ses, Kamera Sarsıntısı ve Yüzen Puanlar
	var anchor_center: Vector2 = _compute_piece_visual_center(placed_coords)
	if lines_count > 0:
		AudioFeedbackManager.play_line_clear(maxi(lines_count, streak_count))
		if ice_cracked_any:
			AudioFeedbackManager.play_ice_crack()
		if lines_count >= 2 or is_joker or streak_count >= 3:
			var shake_amt: float = 5.5 + float(lines_count) * 2.5 + (3.0 if is_joker else 0.0)
			JuicyEffectsManager.shake(shake_amt, 0.24)
		_spawn_floating_text("+%d" % total_gained, anchor_center, COLOR_GOLD_GLOW, 28)
		if special_runes_cleared > 0:
			_spawn_floating_text("✦ +%d" % (special_runes_cleared * 250), anchor_center + Vector2(0, 30), COLOR_GOLD_GLOW, 22)
	else:
		_spawn_floating_text("+%d" % total_gained, anchor_center, COLOR_PARCHMENT, 21)

	if curse_spread_count > 0:
		AudioFeedbackManager.play_bomb_explode()
		JuicyEffectsManager.shake(7.5, 0.24)

	_emit_combo_state()
	queue_redraw()

	var summary: Dictionary = {
		"placed": true,
		"is_joker": is_joker,
		"score_gained": total_gained,
		"coins_gained": coins_gained,
		"lines_cleared": lines_count,
		"combo_count": lines_count,
		"combo_factor": combo_factor,
		"streak_count": streak_count,
		"streak_mult": streak_mult,
		"obstacles_broken": obstacles_broken,
		"special_runes_cleared": special_runes_cleared,
		"remaining_obstacles": get_remaining_obstacle_count(),
		"occupied_count": get_occupied_count(),
		"board_center_global": get_board_center_global(),
		"curse_spread": curse_spread_count
	}
	board_resolved.emit(summary)
	return summary


func _combo_multiplier_for_lines(lines_count: int) -> float:
	if lines_count <= 0:
		return 0.0
	elif lines_count == 1:
		return 1.0
	elif lines_count == 2:
		return 1.5
	elif lines_count == 3:
		return 2.0
	return 3.0


func _spawn_dynamic_special_tile() -> void:
	var empties: Array[Vector2i] = []
	for r in range(rows):
		for c in range(cols):
			if bool(cells[r][c]["active"]) and not bool(cells[r][c]["occupied"]):
				empties.append(Vector2i(c, r))
	if empties.size() < 12:
		return

	var pick: Vector2i = empties[_rng.randi_range(0, empties.size() - 1)]
	var roll: float = _rng.randf()
	var pal_id: String = str(PieceLibrary.PALETTE_ORDER[_rng.randi_range(0, PieceLibrary.PALETTE_ORDER.size() - 1)])
	var rune_id: int = _rng.randi_range(0, 5)

	if roll < 0.34:
		cells[pick.y][pick.x] = {
			"active": true, "occupied": true, "obstacle": LevelGenerator.ObstacleType.NONE,
			"hp": 1, "max_hp": 1, "ice_layers": 0, "curse_timer": 0, "curse_max": 7,
			"skip_next_tick": false, "palette_id": pal_id, "rune_id": rune_id,
			"special_rune": true, "pop_t": 0.0, "flash_t": 1.0
		}
	elif roll < 0.62:
		cells[pick.y][pick.x] = {
			"active": true, "occupied": true, "obstacle": LevelGenerator.ObstacleType.CRACKED_STONE,
			"hp": 1 if _rng.randf() < 0.6 else 2, "max_hp": 2, "ice_layers": 0, "curse_timer": 0, "curse_max": 7,
			"skip_next_tick": false, "palette_id": "relic_stone", "rune_id": 0,
			"special_rune": false, "pop_t": 0.0, "flash_t": 0.8
		}
	elif roll < 0.84:
		cells[pick.y][pick.x] = {
			"active": true, "occupied": true, "obstacle": LevelGenerator.ObstacleType.FROZEN_RELIC,
			"hp": 1, "max_hp": 1, "ice_layers": 2, "curse_timer": 0, "curse_max": 7,
			"skip_next_tick": false, "palette_id": pal_id, "rune_id": rune_id,
			"special_rune": false, "pop_t": 0.0, "flash_t": 0.8
		}
	else:
		cells[pick.y][pick.x] = {
			"active": true, "occupied": true, "obstacle": LevelGenerator.ObstacleType.CURSED_SEAL,
			"hp": 1, "max_hp": 1, "ice_layers": 0, "curse_timer": 7, "curse_max": 7,
			"skip_next_tick": true, "palette_id": "amethyst", "rune_id": rune_id,
			"special_rune": false, "pop_t": 0.0, "flash_t": 0.8
		}


## Bomba / Lanetli Mühür sayacı: skip_next_tick == true ise ilk turda azalmaz!
func _tick_cursed_seals() -> int:
	var seals: Array[Vector2i] = []
	var empty_active_total: int = 0
	for r in range(rows):
		for c in range(cols):
			var cell: Dictionary = cells[r][c]
			if not bool(cell["active"]):
				continue
			if not bool(cell["occupied"]):
				empty_active_total += 1
			elif int(cell["obstacle"]) == LevelGenerator.ObstacleType.CURSED_SEAL:
				seals.append(Vector2i(c, r))

	var spread_total: int = 0
	var min_danger_tick: int = 99
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]

	for sp in seals:
		var cell: Dictionary = cells[sp.y][sp.x]
		if not bool(cell["occupied"]) or int(cell["obstacle"]) != LevelGenerator.ObstacleType.CURSED_SEAL:
			continue
		if bool(cell.get("skip_next_tick", false)):
			cell["skip_next_tick"] = false
			continue

		var cur_t: int = int(cell["curse_timer"]) - 1
		if cur_t <= 0:
			if empty_active_total >= 2:
				var neighbor_empties: Array[Vector2i] = []
				for d in dirs:
					var nb: Vector2i = sp + d
					if _in_bounds(nb.y, nb.x) and bool(cells[nb.y][nb.x]["active"]) and not bool(cells[nb.y][nb.x]["occupied"]):
						neighbor_empties.append(nb)
				if not neighbor_empties.is_empty():
					var target: Vector2i = neighbor_empties[_rng.randi_range(0, neighbor_empties.size() - 1)]
					cells[target.y][target.x] = {
						"active": true, "occupied": true, "obstacle": LevelGenerator.ObstacleType.CRACKED_STONE,
						"hp": 1, "max_hp": 1, "ice_layers": 0, "curse_timer": 0, "curse_max": 7,
						"skip_next_tick": false, "palette_id": "relic_stone", "rune_id": 0,
						"special_rune": false, "pop_t": 0.0, "flash_t": 1.0
					}
					empty_active_total -= 1
					spread_total += 1
					JuicyEffectsManager.burst_at(get_cell_global_center(target.y, target.x), Color("#C084FC"), 10)
			cell["curse_timer"] = maxi(5, int(cell.get("curse_max", 7)))
			cell["flash_t"] = 1.0
		else:
			cell["curse_timer"] = cur_t
			if cur_t <= 3:
				cell["pop_t"] = 0.25
				min_danger_tick = mini(min_danger_tick, cur_t)

	if min_danger_tick <= 3 and spread_total == 0:
		AudioFeedbackManager.play_bomb_tick(min_danger_tick)

	return spread_total


func _compute_piece_visual_center(coords: Array[Vector2i]) -> Vector2:
	if coords.is_empty():
		return size * 0.5
	var sum := Vector2.ZERO
	for p in coords:
		sum += get_cell_rect(p.y, p.x).get_center()
	return sum / float(coords.size())


func _spawn_floating_text(text_val: String, pos: Vector2, col: Color, font_sz: int) -> void:
	var lbl := Label.new()
	lbl.text = text_val
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color("#06100C"))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.size = Vector2(260, 44)
	lbl.position = pos - Vector2(130, 22)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 20
	add_child(lbl)

	if is_inside_tree():
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(lbl, "position:y", lbl.position.y - 52.0, 0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(lbl, "modulate:a", 0.0, 0.72).set_delay(0.16)
		tw.chain().tween_callback(lbl.queue_free)


func _draw() -> void:
	if cells.is_empty():
		return

	var td: Dictionary = ThemeManager.get_theme_data()
	var c_frame_bg: Color = td["card_dark"]
	var c_frame_border: Color = td["border_gold"]
	var c_empty_a: Color = td["cell_a"]
	var c_empty_b: Color = td["cell_b"]
	var c_stroke: Color = td["cell_stroke"]
	var c_void: Color = td["void_hole"]

	var outer_pad: float = 14.0
	var frame_rect := Rect2(
		board_origin - Vector2(outer_pad, outer_pad),
		board_pixel_size + Vector2(outer_pad * 2.0, outer_pad * 2.0)
	)
	draw_rect(Rect2(frame_rect.position + Vector2(0, 7), frame_rect.size), Color(0, 0, 0, 0.48), true)
	draw_rect(frame_rect, c_frame_bg, true)
	draw_rect(frame_rect, c_frame_border, false, 3.0)
	_draw_corner_ornaments(frame_rect)

	var gold_wave: float = 0.5 + 0.5 * sin(_pulse_time * 7.5)

	for r in range(rows):
		for c in range(cols):
			var rect: Rect2 = get_cell_rect(r, c)
			var cell: Dictionary = cells[r][c]

			if not bool(cell["active"]):
				draw_rect(rect.grow(-2.0), c_void, true)
				continue

			var base_col: Color = c_empty_a if ((r + c) % 2 == 0) else c_empty_b
			draw_rect(rect, base_col, true)
			draw_rect(rect, c_stroke, false, 1.2)

			if bool(cell["occupied"]):
				var pop_t: float = float(cell.get("pop_t", 1.0))
				var scale_f: float = 1.0
				if pop_t < 1.0:
					scale_f = 0.65 + 0.35 * sin(pop_t * PI * 0.5) + 0.10 * sin(pop_t * PI)
				var tile_rect: Rect2 = _scaled_rect(rect, scale_f)
				var in_clear_preview: bool = ghost_clear_rows.has(r) or ghost_clear_cols.has(c)
				var glow_amt: float = (0.55 + 0.45 * gold_wave) if in_clear_preview else float(cell.get("flash_t", 0.0))
				_draw_occupied_cell(tile_rect, cell, glow_amt, in_clear_preview)

	# Hayalet Önizleme
	if ghost_active and ghost_valid and not ghost_piece.is_empty():
		var g_is_joker: bool = bool(ghost_piece.get("is_joker", false))
		var g_pal: String = str(ghost_piece.get("palette_id", "jade"))
		var g_rune: int = int(ghost_piece.get("rune_id", 0))
		var g_spec: bool = bool(ghost_piece.get("special_rune", false))
		var will_clear: bool = (not ghost_clear_rows.is_empty() or not ghost_clear_cols.is_empty())
		var g_idx: int = 0
		for offset in ghost_piece["cells"]:
			var vp: Vector2i = offset
			var gr: int = ghost_anchor.y + vp.y
			var gc: int = ghost_anchor.x + vp.x
			if _in_bounds(gr, gc):
				var grect: Rect2 = get_cell_rect(gr, gc)
				if g_is_joker:
					PieceLibrary.draw_joker_tile(self, grect, 0.72, gold_wave)
				else:
					PieceLibrary.draw_relic_tile(self, grect, g_pal, g_rune, 0.48, 0.85 if will_clear else 0.15, g_spec and g_idx == 0)
			g_idx += 1

	for rr in ghost_clear_rows:
		_draw_line_preview_row(rr, gold_wave)
	for cc in ghost_clear_cols:
		_draw_line_preview_col(cc, gold_wave)

	if active_booster != "":
		draw_rect(frame_rect.grow(3.0), Color(0.98, 0.35, 0.25, 0.45 + 0.45 * gold_wave), false, 3.0)
		if _booster_hover_cell.x >= 0:
			var rad: int = 0 if active_booster == "hammer" else 1
			for dr in range(-rad, rad + 1):
				for dc in range(-rad, rad + 1):
					var tr: int = _booster_hover_cell.y + dr
					var tc: int = _booster_hover_cell.x + dc
					if _in_bounds(tr, tc) and bool(cells[tr][tc]["active"]):
						var hrect: Rect2 = get_cell_rect(tr, tc)
						draw_rect(hrect, Color(0.98, 0.35, 0.20, 0.30 + 0.20 * gold_wave), true)
						draw_rect(hrect, COLOR_GOLD_GLOW, false, 2.5)


func _draw_occupied_cell(rect: Rect2, cell: Dictionary, glow_amt: float, in_preview: bool) -> void:
	var obs: int = int(cell["obstacle"])
	var pal_id: String = str(cell["palette_id"])
	var rune_id: int = int(cell["rune_id"])
	var is_spec: bool = bool(cell.get("special_rune", false))

	match obs:
		LevelGenerator.ObstacleType.NONE:
			var spec_pulse: float = (0.4 + 0.5 * (0.5 + 0.5 * sin(_pulse_time * 5.0))) if is_spec else glow_amt
			PieceLibrary.draw_relic_tile(self, rect, pal_id, rune_id, 1.0, maxf(glow_amt, spec_pulse), is_spec)
		LevelGenerator.ObstacleType.CRACKED_STONE:
			_draw_cracked_stone(rect, int(cell["hp"]), glow_amt)
		LevelGenerator.ObstacleType.FROZEN_RELIC:
			PieceLibrary.draw_relic_tile(self, rect, pal_id, rune_id, 1.0, glow_amt)
			_draw_frozen_overlay(rect, int(cell["ice_layers"]), glow_amt, in_preview)
		LevelGenerator.ObstacleType.CURSED_SEAL:
			_draw_cursed_seal(rect, int(cell["curse_timer"]), glow_amt)


func _draw_cracked_stone(rect: Rect2, hp: int, glow_amt: float) -> void:
	var stone_dark := Color("#38332C")
	var stone_mid := Color("#5C5346") if hp >= 2 else Color("#4F463B")
	var stone_hi := Color("#9E907A")
	draw_rect(rect, stone_dark, true)
	draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 6)), stone_mid, true)
	draw_rect(rect.grow(-1.0), stone_hi.lerp(COLOR_GOLD_GLOW, glow_amt), false, 2.0)

	var c: Vector2 = rect.get_center()
	var s: float = rect.size.x * 0.36
	var crack_col: Color = Color("#1B1714") if hp >= 2 else Color("#F59E0B")
	var crack_w: float = 2.0 if hp >= 2 else 2.6

	draw_line(c + Vector2(-s * 0.8, -s * 0.7), c + Vector2(-s * 0.1, -s * 0.05), crack_col, crack_w, true)
	draw_line(c + Vector2(-s * 0.1, -s * 0.05), c + Vector2(s * 0.75, s * 0.65), crack_col, crack_w, true)
	if hp == 1:
		draw_line(c + Vector2(s * 0.65, -s * 0.75), c + Vector2(-s * 0.1, -s * 0.05), Color("#FDE68A"), 2.0, true)
		draw_line(c + Vector2(-s * 0.1, -s * 0.05), c + Vector2(-s * 0.65, s * 0.8), Color("#F59E0B"), 2.0, true)
	else:
		draw_rect(Rect2(c + Vector2(-7, -5), Vector2(4, 10)), COLOR_PARCHMENT, true)
		draw_rect(Rect2(c + Vector2(3, -5), Vector2(4, 10)), COLOR_PARCHMENT, true)


func _draw_frozen_overlay(rect: Rect2, ice_layers: int, glow_amt: float, in_preview: bool) -> void:
	var ice_fill := Color(0.58, 0.88, 1.0, 0.60 if ice_layers >= 2 else 0.44)
	if in_preview and ice_layers > 1:
		ice_fill = Color(0.92, 0.98, 1.0, 0.76)
	var ice_border: Color = COLOR_ICE_PREVIEW if (in_preview and ice_layers > 1) else Color(0.86, 0.96, 1.0, 0.95).lerp(COLOR_GOLD_GLOW, glow_amt * 0.5)
	draw_rect(rect.grow(-1.0), ice_fill, true)
	draw_rect(rect.grow(-1.5), ice_border, false, 2.8)

	var p0: Vector2 = rect.position
	var sz: float = rect.size.x
	draw_line(p0 + Vector2(sz * 0.16, sz * 0.34), p0 + Vector2(sz * 0.36, sz * 0.14), Color(1, 1, 1, 0.82), 2.2, true)
	# Çatlamış buz (can 1) iken çatlak çizgisi göster
	if ice_layers == 1:
		var c: Vector2 = rect.get_center()
		draw_line(c + Vector2(-sz * 0.25, -sz * 0.20), c + Vector2(sz * 0.26, sz * 0.22), Color(1, 1, 1, 0.88), 2.0, true)
		draw_line(c + Vector2(sz * 0.15, -sz * 0.25), c + Vector2(-sz * 0.18, sz * 0.24), Color(1, 1, 1, 0.72), 1.6, true)

	# Kalan buz canı (*2 / 1)
	var font: Font = ThemeDB.fallback_font
	if font != null and ice_layers >= 1:
		var lbl_txt: String = "*2" if ice_layers >= 2 else "1"
		var fsize: int = maxi(15, int(sz * 0.34))
		draw_string(
			font,
			Vector2(rect.position.x, rect.get_center().y + float(fsize) * 0.35),
			lbl_txt,
			HORIZONTAL_ALIGNMENT_CENTER,
			sz,
			fsize,
			Color("#FFFFFF")
		)


func _draw_cursed_seal(rect: Rect2, timer_val: int, glow_amt: float) -> void:
	var is_danger: bool = (timer_val <= 3)
	var pulse: float = 0.5 + 0.5 * sin(_pulse_time * (9.5 if is_danger else 4.0))
	var draw_r: Rect2 = _scaled_rect(rect, 1.0 + 0.04 * pulse) if is_danger else rect
	var bg := Color("#3B1018") if is_danger else Color("#23112E")
	var rim := Color("#EF4444").lerp(Color("#FCA5A5"), pulse * 0.5) if is_danger else Color("#A855F7")
	rim = rim.lerp(COLOR_GOLD_GLOW, glow_amt * 0.6)

	draw_rect(draw_r, Color("#120818"), true)
	draw_rect(draw_r.grow(-2.0), bg, true)
	draw_rect(draw_r.grow(-1.5), rim, false, 2.6)

	var c: Vector2 = draw_r.get_center()
	var ring_r: float = draw_r.size.x * (0.31 + 0.03 * pulse)
	draw_arc(c, ring_r, 0.0, TAU, 20, rim * Color(1, 1, 1, 0.85), 2.0, true)

	var font: Font = ThemeDB.fallback_font
	if font != null:
		var fsize: int = maxi(16, int(draw_r.size.x * 0.40))
		var num_str: String = str(maxi(0, timer_val))
		var num_col: Color = Color("#FECACA") if is_danger else COLOR_GOLD_GLOW
		draw_string(
			font,
			Vector2(draw_r.position.x, c.y + float(fsize) * 0.34),
			num_str,
			HORIZONTAL_ALIGNMENT_CENTER,
			draw_r.size.x,
			fsize,
			num_col
		)


func _draw_line_preview_row(r: int, wave: float) -> void:
	for c in range(cols):
		var cell: Dictionary = cells[r][c]
		if not bool(cell["active"]):
			continue
		var rect: Rect2 = get_cell_rect(r, c)
		var is_thick_ice: bool = bool(cell["occupied"]) and int(cell["obstacle"]) == LevelGenerator.ObstacleType.FROZEN_RELIC and int(cell["ice_layers"]) > 1
		if is_thick_ice:
			draw_rect(rect, Color(0.88, 0.97, 1.0, 0.30 + 0.18 * wave), true)
			draw_rect(rect.grow(1.0), COLOR_ICE_PREVIEW, false, 2.4)
		else:
			draw_rect(rect, Color(0.96, 0.62, 0.04, 0.20 + 0.14 * wave), true)
			draw_rect(rect.grow(1.0), Color(0.99, 0.90, 0.54, 0.72 + 0.25 * wave), false, 2.2)


func _draw_line_preview_col(c: int, wave: float) -> void:
	for r in range(rows):
		var cell: Dictionary = cells[r][c]
		if not bool(cell["active"]):
			continue
		var rect: Rect2 = get_cell_rect(r, c)
		var is_thick_ice: bool = bool(cell["occupied"]) and int(cell["obstacle"]) == LevelGenerator.ObstacleType.FROZEN_RELIC and int(cell["ice_layers"]) > 1
		if is_thick_ice:
			draw_rect(rect, Color(0.88, 0.97, 1.0, 0.30 + 0.18 * wave), true)
			draw_rect(rect.grow(1.0), COLOR_ICE_PREVIEW, false, 2.4)
		else:
			draw_rect(rect, Color(0.96, 0.62, 0.04, 0.20 + 0.14 * wave), true)
			draw_rect(rect.grow(1.0), Color(0.99, 0.90, 0.54, 0.72 + 0.25 * wave), false, 2.2)


func _draw_corner_ornaments(frame_rect: Rect2) -> void:
	var arm: float = 18.0
	var col := COLOR_GOLD_GLOW
	var tl := frame_rect.position
	var tr := Vector2(frame_rect.end.x, frame_rect.position.y)
	var bl := Vector2(frame_rect.position.x, frame_rect.end.y)
	var br := frame_rect.end

	draw_line(tl, tl + Vector2(arm, 0), col, 3.5)
	draw_line(tl, tl + Vector2(0, arm), col, 3.5)
	draw_line(tr, tr + Vector2(-arm, 0), col, 3.5)
	draw_line(tr, tr + Vector2(0, arm), col, 3.5)
	draw_line(bl, bl + Vector2(arm, 0), col, 3.5)
	draw_line(bl, bl + Vector2(0, -arm), col, 3.5)
	draw_line(br, br + Vector2(-arm, 0), col, 3.5)
	draw_line(br, br + Vector2(0, -arm), col, 3.5)


func _scaled_rect(rect: Rect2, scale_f: float) -> Rect2:
	var new_sz: Vector2 = rect.size * scale_f
	return Rect2(rect.get_center() - new_sz * 0.5, new_sz)
