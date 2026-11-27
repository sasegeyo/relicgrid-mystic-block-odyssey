class_name PieceTray
extends Control
## 3 parçalı alt tepsi: Dinamik Zorluk Eğrisi (300 -> 6000), Joker (+) & Acil Kurtarma (DDA),
## dokunmatiğe özel lift ofseti, en yakın yuva seçimi, %40 sığmayan parça opaklığı,
## Döndür güçlendiricisi simetri koruması ve Kayıt/Yükleme.

signal piece_placed_from_tray(summary: Dictionary)
signal no_moves_remaining
signal rescue_triggered
signal piece_rotated
signal symmetric_rotate_rejected

const SLOT_COUNT: int = 3
const TOUCH_LIFT_OFFSET := Vector2(0.0, -96.0)
const MAX_JOKERS: int = 3
const MAX_RESCUES: int = 3

@export var lift_only_on_touch: bool = true

var grid_board: GridBoard = null
var slots: Array = [{}, {}, {}]
var special_mode: bool = false
var current_score_hint: int = 0
var jokers_used: int = 0
var rescues_used: int = 0
var rotate_mode_active: bool = false

var _rng := RandomNumberGenerator.new()
var _max_shape_tier: int = 2
var _interaction_locked: bool = false

var _dragging_slot: int = -1
var _is_touch_drag: bool = false
var _drag_pointer_global: Vector2 = Vector2.ZERO
var _drag_scale: float = 1.0
var _slot_spawn_scales: Array[float] = [1.0, 1.0, 1.0]
var _return_anim_slot: int = -1
var _return_anim_pos: Vector2 = Vector2.ZERO
var _return_anim_t: float = 1.0
var _pulse_acc: float = 0.0


func _ready() -> void:
	resized.connect(queue_redraw)
	ThemeManager.theme_changed.connect(_on_theme_changed)


func _on_theme_changed(_tid: String) -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_pulse_acc += delta
	var dirty: bool = (_dragging_slot >= 0) or rotate_mode_active
	for i in range(SLOT_COUNT):
		if _slot_spawn_scales[i] < 1.0:
			_slot_spawn_scales[i] = minf(1.0, _slot_spawn_scales[i] + delta * 5.2)
			dirty = true

	if _dragging_slot >= 0 and _drag_scale < 1.0:
		_drag_scale = minf(1.0, _drag_scale + delta * 9.0)
		dirty = true

	if _return_anim_slot >= 0:
		_return_anim_t = minf(1.0, _return_anim_t + delta * 7.5)
		dirty = true
		if _return_anim_t >= 1.0:
			_return_anim_slot = -1

	if dirty:
		queue_redraw()


func setup_tray(board: GridBoard, seed_val: int, max_tier: int, is_special: bool = false) -> void:
	grid_board = board
	_rng.seed = seed_val
	_max_shape_tier = clampi(max_tier, 0, 2)
	special_mode = is_special
	current_score_hint = 0
	jokers_used = 0
	rescues_used = 0
	rotate_mode_active = false
	_dragging_slot = -1
	_return_anim_slot = -1
	_interaction_locked = false
	slots = [{}, {}, {}]
	refill_tray()


func restore_counters(saved_jokers: int, saved_rescues: int) -> void:
	jokers_used = clampi(saved_jokers, 0, MAX_JOKERS)
	rescues_used = clampi(saved_rescues, 0, MAX_RESCUES)


func set_rotate_targeting(active: bool) -> void:
	rotate_mode_active = active
	if active and _dragging_slot >= 0:
		_dragging_slot = -1
		if grid_board != null:
			grid_board.clear_ghost_preview()
	queue_redraw()


func set_interaction_locked(locked: bool) -> void:
	_interaction_locked = locked
	if locked and _dragging_slot >= 0:
		_dragging_slot = -1
		if grid_board != null:
			grid_board.clear_ghost_preview()
		queue_redraw()


func get_active_pieces() -> Array:
	var list: Array = []
	for s in slots:
		if typeof(s) == TYPE_DICTIONARY and not s.is_empty():
			list.append(s)
	return list


func is_tray_empty() -> bool:
	return get_active_pieces().is_empty()


func use_refresh_booster() -> void:
	AudioManager.play_booster()
	refill_tray()


## Döndür güçlendiricisinin herhangi bir mevcut parçayı tahtaya sığdırıp sığdıramayacağını kontrol eder.
func can_any_rotation_fit() -> bool:
	if grid_board == null:
		return false
	for s in slots:
		if typeof(s) != TYPE_DICTIONARY or s.is_empty():
			continue
		var cells: Array[Vector2i] = []
		for p in s["cells"]:
			cells.append(p as Vector2i)
		if PieceLibrary.is_rotationally_symmetric(cells):
			continue
		var cur: Array[Vector2i] = cells
		for _step in range(3):
			cur = PieceLibrary.rotate_cells_90(cur)
			var b: Vector2i = PieceLibrary.compute_bounds(cur)
			var test_piece: Dictionary = {"cells": cur, "width": b.x, "height": b.y, "is_joker": false}
			if grid_board.can_piece_fit_anywhere(test_piece):
				return true
	return false


## DDA (300 -> 6000) + Akıllı Parça Üreteci (%50 küçük, %70 1x1, %85 Joker maks. 3)
## guarantee_fit: true ise (ör. Revive sonrası) tahta ne kadar dolu olursa olsun
## en az bir parçanın sığması garanti edilir.
func refill_tray(guarantee_fit: bool = false) -> void:
	var all_shapes: Array[Dictionary] = PieceLibrary.get_all_shapes()
	var tier_filtered: Array[Dictionary] = []
	for sh in all_shapes:
		if int(sh["tier"]) <= _max_shape_tier:
			tier_filtered.append(sh)
	if tier_filtered.is_empty():
		tier_filtered = all_shapes

	var dda_t: float = clampf((float(current_score_hint) - 300.0) / 5700.0, 0.0, 1.0)
	var ice_chance: float = lerpf(0.12, 0.26, dda_t)
	var bomb_chance: float = lerpf(0.05, 0.13, dda_t)
	var bomb_counter: int = int(round(lerpf(9.0, 7.0, dda_t)))
	var max_bombs: int = 1 if dda_t < 0.55 else 2

	var fittable: Array[Dictionary] = []
	var occupancy: float = 0.0
	var current_bombs: int = 0
	if grid_board != null:
		fittable = grid_board.get_fittable_shapes(tier_filtered)
		occupancy = grid_board.get_occupancy_ratio()
		current_bombs = grid_board.get_bomb_count()

	# Sadece tahta henüz çok dolmamışken (< %72) 1 sığan parça yardımı ver;
	# %72 üstünde tamamen doğal çekiliş yap ki oyuncu sıkıştığında gerçekten kaybedebilsin.
	var guaranteed_slot: int = _rng.randi_range(0, SLOT_COUNT - 1) if (occupancy < 0.72 or guarantee_fit) else -1
	if guarantee_fit and grid_board != null and fittable.is_empty():
		fittable = grid_board.get_fittable_shapes(all_shapes)
		if fittable.is_empty():
			fittable = [PieceLibrary.get_shape_by_id("mono_1")]

	for i in range(SLOT_COUNT):
		var chosen_shape: Dictionary
		if i == guaranteed_slot and not fittable.is_empty():
			chosen_shape = _pick_weighted_shape(fittable, occupancy, dda_t)
		else:
			chosen_shape = _pick_weighted_shape(tier_filtered, occupancy, dda_t)

		var specs: Dictionary = {}
		if special_mode:
			var roll_spec: float = _rng.randf()
			if current_bombs < max_bombs and roll_spec < bomb_chance:
				specs = {"type": "bomb", "value": bomb_counter}
				current_bombs += 1
			elif roll_spec < bomb_chance + ice_chance:
				specs = {"type": "ice", "value": 2}

		var make_special: bool = special_mode and specs.is_empty() and (_rng.randf() < 0.28)
		slots[i] = PieceLibrary.create_piece_instance(chosen_shape, _rng, make_special, specs)
		_slot_spawn_scales[i] = 0.15

	queue_redraw()
	check_moves_still_possible()


func _pick_weighted_shape(pool: Array[Dictionary], occupancy: float, dda_t: float) -> Dictionary:
	var total_weight: int = 0
	var weights: Array[int] = []
	for sh in pool:
		var w: float = float(maxi(1, int(sh.get("weight", 5))))
		var tier: int = int(sh.get("tier", 0))
		if occupancy >= 0.50:
			if tier == 0:
				w *= 2.1
			elif tier == 2:
				w *= 0.45
		elif occupancy < 0.35:
			if tier == 2:
				w *= lerpf(1.1, 1.85, dda_t)
		var wi: int = maxi(1, int(round(w)))
		weights.append(wi)
		total_weight += wi

	var roll: int = _rng.randi_range(1, maxi(1, total_weight))
	var acc: int = 0
	for idx in range(pool.size()):
		acc += weights[idx]
		if roll <= acc:
			return pool[idx]
	return pool[0]


## Hamle kalmadığında maks. 3 kez acil kurtarma parçası (1x1 veya Joker) verir.
func try_emergency_rescue() -> bool:
	if grid_board == null or rescues_used >= MAX_RESCUES:
		return false

	var target_slot: int = -1
	for i in range(SLOT_COUNT):
		if typeof(slots[i]) == TYPE_DICTIONARY and not slots[i].is_empty():
			target_slot = i
			break
	if target_slot < 0:
		return false

	var mono: Dictionary = PieceLibrary.create_piece_instance(PieceLibrary.get_shape_by_id("mono_1"), _rng)
	if grid_board.can_piece_fit_anywhere(mono):
		slots[target_slot] = mono
	elif jokers_used < MAX_JOKERS:
		slots[target_slot] = PieceLibrary.create_joker_piece()
		jokers_used += 1
	else:
		return false

	rescues_used += 1
	_slot_spawn_scales[target_slot] = 0.15
	AudioManager.play_rescue()
	queue_redraw()
	rescue_triggered.emit()
	return true


# --- KAYIT / YÜKLEME ---

func export_tray_slots() -> Array:
	var out: Array = []
	for i in range(SLOT_COUNT):
		var s: Dictionary = slots[i]
		if s.is_empty():
			continue
		var cell_pairs: Array = []
		for p in s["cells"]:
			var vp: Vector2i = p
			cell_pairs.append([vp.x, vp.y])
		out.append({
			"slot_index": i,
			"shape_id": str(s.get("id", "mono_1")),
			"cells": cell_pairs,
			"color": str(s.get("palette_id", "jade")),
			"rune_id": int(s.get("rune_id", 0)),
			"is_joker": bool(s.get("is_joker", false)),
			"special_rune": bool(s.get("special_rune", false)),
			"specs": s.get("specs", {})
		})
	return out


func import_tray_slots(saved_slots: Array) -> void:
	slots = [{}, {}, {}]
	for item_var in saved_slots:
		if typeof(item_var) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_var
		var idx: int = int(item.get("slot_index", -1))
		if idx < 0 or idx >= SLOT_COUNT:
			continue
		var cells_arr: Array[Vector2i] = []
		var raw_cells: Variant = item.get("cells", [])
		if typeof(raw_cells) == TYPE_ARRAY:
			for pair in raw_cells:
				if typeof(pair) == TYPE_ARRAY and pair.size() >= 2:
					cells_arr.append(Vector2i(int(pair[0]), int(pair[1])))
		if cells_arr.is_empty():
			cells_arr.append(Vector2i(0, 0))
		var norm: Array[Vector2i] = PieceLibrary.normalize_cells(cells_arr)
		var b: Vector2i = PieceLibrary.compute_bounds(norm)
		slots[idx] = {
			"id": str(item.get("shape_id", "mono_1")),
			"tier": 0,
			"cells": norm,
			"width": b.x,
			"height": b.y,
			"palette_id": str(item.get("color", "jade")),
			"rune_id": int(item.get("rune_id", 0)),
			"is_joker": bool(item.get("is_joker", false)),
			"special_rune": bool(item.get("special_rune", false)),
			"specs": item.get("specs", {}) if typeof(item.get("specs", {})) == TYPE_DICTIONARY else {}
		}
		_slot_spawn_scales[idx] = 1.0
	queue_redraw()


# --- SÜRÜKLE-BIRAK & EN YAKIN YUVA SEÇİMİ ---

func _get_slot_rect(slot_idx: int) -> Rect2:
	var pad_x: float = 12.0
	var gap_x: float = 12.0
	var slot_w: float = (size.x - pad_x * 2.0 - gap_x * float(SLOT_COUNT - 1)) / float(SLOT_COUNT)
	var slot_h: float = maxf(72.0, size.y - 12.0)
	var x: float = pad_x + float(slot_idx) * (slot_w + gap_x)
	return Rect2(Vector2(x, 6.0), Vector2(slot_w, slot_h))


func _find_closest_hit_slot(local_pos: Vector2) -> int:
	var best_idx: int = -1
	var best_dist: float = INF
	for i in range(SLOT_COUNT):
		if slots[i].is_empty():
			continue
		var r: Rect2 = _get_slot_rect(i).grow(10.0)
		if r.has_point(local_pos):
			var d: float = local_pos.distance_squared_to(r.get_center())
			if d < best_dist:
				best_dist = d
				best_idx = i
	return best_idx


func _get_active_lift_offset() -> Vector2:
	if lift_only_on_touch:
		return TOUCH_LIFT_OFFSET if _is_touch_drag else Vector2.ZERO
	return TOUCH_LIFT_OFFSET


func _gui_input(event: InputEvent) -> void:
	if _interaction_locked or _dragging_slot >= 0:
		return
	if grid_board != null and grid_board.active_booster != "":
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if rotate_mode_active:
				_try_rotate_at(mb.position)
			else:
				_try_begin_drag(mb.position, get_global_transform() * mb.position, false)
			accept_event()
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			if rotate_mode_active:
				_try_rotate_at(st.position)
			else:
				_try_begin_drag(st.position, get_global_transform() * st.position, true)
			accept_event()


func _try_rotate_at(local_pos: Vector2) -> void:
	var idx: int = _find_closest_hit_slot(local_pos)
	if idx < 0:
		return
	var piece: Dictionary = slots[idx]
	var cells_arr: Array[Vector2i] = []
	for p in piece["cells"]:
		cells_arr.append(p as Vector2i)

	if PieceLibrary.is_rotationally_symmetric(cells_arr):
		AudioManager.play_invalid()
		symmetric_rotate_rejected.emit()
		return

	var rot: Array[Vector2i] = PieceLibrary.rotate_cells_90(cells_arr)
	var b: Vector2i = PieceLibrary.compute_bounds(rot)
	piece["cells"] = rot
	piece["width"] = b.x
	piece["height"] = b.y
	rotate_mode_active = false
	_slot_spawn_scales[idx] = 0.72
	AudioManager.play_booster()
	queue_redraw()
	piece_rotated.emit()


func _input(event: InputEvent) -> void:
	if _dragging_slot < 0:
		return

	# _input olayları ekran (viewport) koordinatındadır; kamera/sarsıntı dönüşümünü
	# geri alarak _gui_input ve get_global_transform ile aynı uzaya çeviriyoruz.
	var to_canvas: Transform2D = get_viewport().get_canvas_transform().affine_inverse()

	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		_update_drag(to_canvas * mm.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		_is_touch_drag = true
		_update_drag(to_canvas * sd.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_finish_drag(to_canvas * mb.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if not st.pressed:
			_finish_drag(to_canvas * st.position)
			get_viewport().set_input_as_handled()


func _try_begin_drag(local_pos: Vector2, global_pos: Vector2, is_touch: bool) -> void:
	var idx: int = _find_closest_hit_slot(local_pos)
	if idx < 0:
		return
	_dragging_slot = idx
	_is_touch_drag = is_touch
	_return_anim_slot = -1
	_drag_pointer_global = global_pos
	_drag_scale = 0.65
	AudioManager.play_pickup()
	_update_drag(global_pos)
	queue_redraw()


func _update_drag(global_pointer: Vector2) -> void:
	_drag_pointer_global = global_pointer
	if grid_board != null and _dragging_slot >= 0:
		var piece: Dictionary = slots[_dragging_slot]
		grid_board.update_hover_preview(piece, _drag_pointer_global + _get_active_lift_offset())
	queue_redraw()


func _finish_drag(global_pointer: Vector2) -> void:
	if _dragging_slot < 0:
		return
	_drag_pointer_global = global_pointer
	var slot_idx: int = _dragging_slot
	var piece: Dictionary = slots[slot_idx]
	var lift: Vector2 = _get_active_lift_offset()
	_dragging_slot = -1

	var placed_ok: bool = false
	var summary: Dictionary = {}

	if grid_board != null and not piece.is_empty():
		var hover: Dictionary = grid_board.update_hover_preview(piece, _drag_pointer_global + lift)
		grid_board.clear_ghost_preview()
		if bool(hover.get("valid", false)):
			var anchor: Vector2i = hover["anchor"]
			summary = grid_board.place_piece(piece, anchor)
			placed_ok = bool(summary.get("placed", false))

	if placed_ok:
		slots[slot_idx] = {}
		queue_redraw()
		piece_placed_from_tray.emit(summary)

		if not _interaction_locked:
			if is_tray_empty():
				refill_tray()
			else:
				check_moves_still_possible()
	else:
		AudioManager.play_invalid()
		_return_anim_slot = slot_idx
		_return_anim_pos = get_global_transform().affine_inverse() * (_drag_pointer_global + lift)
		_return_anim_t = 0.0
		queue_redraw()


func check_moves_still_possible() -> void:
	if _interaction_locked or grid_board == null:
		return
	var active: Array = get_active_pieces()
	if not active.is_empty() and not grid_board.has_any_valid_move(active):
		no_moves_remaining.emit()


func _draw() -> void:
	var td: Dictionary = ThemeManager.get_theme_data()
	var slot_bg: Color = td["card_bg"]
	var slot_border: Color = td["border_gold"] if rotate_mode_active else td["border_stone"]
	var pulse: float = 0.5 + 0.5 * sin(_pulse_acc * 6.0)

	for i in range(SLOT_COUNT):
		var srect: Rect2 = _get_slot_rect(i)
		draw_rect(Rect2(srect.position + Vector2(0, 4), srect.size), Color(0, 0, 0, 0.38), true)
		draw_rect(srect, slot_bg, true)
		draw_rect(srect, slot_border, false, 2.6 if rotate_mode_active else 2.0)

		var piece: Dictionary = slots[i]
		if piece.is_empty() or i == _dragging_slot:
			continue

		var fits: bool = true if grid_board == null else grid_board.can_piece_fit_anywhere(piece)
		var piece_alpha: float = 1.0 if fits else 0.40

		var max_dim: int = maxi(int(piece["width"]), int(piece["height"]))
		var fit_cell: float = minf(
			(srect.size.x - 24.0) / float(maxi(1, max_dim)),
			(srect.size.y - 24.0) / float(maxi(1, max_dim))
		)
		fit_cell = clampf(fit_cell, 16.0, 34.0) * _slot_spawn_scales[i]

		var draw_center: Vector2 = srect.get_center()
		if i == _return_anim_slot and _return_anim_t < 1.0:
			var ease_t: float = 1.0 - pow(1.0 - _return_anim_t, 3.0)
			draw_center = _return_anim_pos.lerp(srect.get_center(), ease_t)

		_draw_piece_centered(piece, draw_center, fit_cell, 3.0, piece_alpha, false, pulse)

	if _dragging_slot >= 0 and not slots[_dragging_slot].is_empty():
		var dpiece: Dictionary = slots[_dragging_slot]
		var target_cell: float = grid_board.cell_size if grid_board != null else 56.0
		var target_gap: float = grid_board.cell_gap if grid_board != null else 5.0
		var cur_cell: float = lerpf(32.0, target_cell, _drag_scale)
		var local_visual_center: Vector2 = get_global_transform().affine_inverse() * (_drag_pointer_global + _get_active_lift_offset())

		_draw_piece_centered(dpiece, local_visual_center + Vector2(0, 10), cur_cell, target_gap, 0.25, true, pulse)
		_draw_piece_centered(dpiece, local_visual_center, cur_cell, target_gap, 0.96, false, pulse)


func _draw_piece_centered(
	piece: Dictionary,
	center: Vector2,
	tile_sz: float,
	gap: float,
	alpha: float,
	shadow_only: bool = false,
	pulse: float = 0.0
) -> void:
	var step: float = tile_sz + gap
	var total_w: float = float(piece["width"]) * step - gap
	var total_h: float = float(piece["height"]) * step - gap
	var top_left: Vector2 = center - Vector2(total_w, total_h) * 0.5
	var pal_id: String = str(piece.get("palette_id", "jade"))
	var rune_id: int = int(piece.get("rune_id", 0))
	var is_spec: bool = bool(piece.get("special_rune", false))
	var is_joker: bool = bool(piece.get("is_joker", false))

	var idx: int = 0
	for offset in piece["cells"]:
		var vp: Vector2i = offset
		var r := Rect2(top_left + Vector2(float(vp.x) * step, float(vp.y) * step), Vector2(tile_sz, tile_sz))
		if shadow_only:
			draw_rect(r, Color(0, 0, 0, alpha), true)
		elif is_joker:
			PieceLibrary.draw_joker_tile(self, r, alpha, pulse)
		else:
			PieceLibrary.draw_relic_tile(self, r, pal_id, rune_id, alpha, 0.15, is_spec and idx == 0)
		idx += 1
