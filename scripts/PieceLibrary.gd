class_name PieceLibrary
extends RefCounted
## Tüm blok şekilleri, (0,0) koordinat normalizasyonu, dönme simetrisi tespiti,
## Joker (+) parçası, temaya duyarlı değerli taş paletleri ve vektörel rün çizimleri.

const PALETTE_ORDER: Array = [
	"jade",
	"amber",
	"amethyst",
	"ruby",
	"sapphire",
	"relic_stone"
]

const PALETTES: Dictionary = {
	"jade": {
		"name": "Yeşim",
		"fill": Color("#168760"),
		"highlight": Color("#4AE3A7"),
		"shadow": Color("#0B4A34"),
		"inner": Color("#116B4C"),
		"rune": Color("#B8FFDF")
	},
	"amber": {
		"name": "Kehribar",
		"fill": Color("#D97706"),
		"highlight": Color("#FCD34D"),
		"shadow": Color("#7C3A03"),
		"inner": Color("#B45309"),
		"rune": Color("#FEF3C7")
	},
	"amethyst": {
		"name": "Ametist",
		"fill": Color("#7C3AED"),
		"highlight": Color("#C4B5FD"),
		"shadow": Color("#431987"),
		"inner": Color("#6326C9"),
		"rune": Color("#EDE9FE")
	},
	"ruby": {
		"name": "Yakut",
		"fill": Color("#DC2626"),
		"highlight": Color("#FCA5A5"),
		"shadow": Color("#7F1D1D"),
		"inner": Color("#B91C1C"),
		"rune": Color("#FEE2E2")
	},
	"sapphire": {
		"name": "Safir",
		"fill": Color("#2563EB"),
		"highlight": Color("#93C5FD"),
		"shadow": Color("#1E3A8A"),
		"inner": Color("#1D4ED8"),
		"rune": Color("#DBEAFE")
	},
	"relic_stone": {
		"name": "Antik Taş",
		"fill": Color("#8D7B60"),
		"highlight": Color("#D6C7AE"),
		"shadow": Color("#4A3F30"),
		"inner": Color("#706049"),
		"rune": Color("#FDE68A")
	}
}

static var _shapes_cache: Array[Dictionary] = []


## Koordinatları (0, 0) tabanına çeker ve kanonik sıraya dizer.
static func normalize_cells(src: Array[Vector2i]) -> Array[Vector2i]:
	if src.is_empty():
		return []
	var min_x: int = src[0].x
	var min_y: int = src[0].y
	for p in src:
		min_x = mini(min_x, p.x)
		min_y = mini(min_y, p.y)

	var out: Array[Vector2i] = []
	for p in src:
		var shifted := Vector2i(p.x - min_x, p.y - min_y)
		if not out.has(shifted):
			out.append(shifted)

	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	return out


## Şekli saat yönünde 90 derece döndürür ve (0, 0) tabanlı normalize eder.
static func rotate_cells_90(src: Array[Vector2i]) -> Array[Vector2i]:
	var rotated: Array[Vector2i] = []
	for p in src:
		rotated.append(Vector2i(-p.y, p.x))
	return normalize_cells(rotated)


## 1x1, 2x2, 3x3 veya Artı gibi 90° dönünce değişmeyen şekilleri tespit eder.
static func is_rotationally_symmetric(cells: Array[Vector2i]) -> bool:
	var norm: Array[Vector2i] = normalize_cells(cells)
	var rot: Array[Vector2i] = rotate_cells_90(norm)
	if norm.size() != rot.size():
		return false
	for i in range(norm.size()):
		if norm[i] != rot[i]:
			return false
	return true


static func compute_bounds(cells: Array[Vector2i]) -> Vector2i:
	var norm: Array[Vector2i] = normalize_cells(cells)
	if norm.is_empty():
		return Vector2i(1, 1)
	var max_x: int = 0
	var max_y: int = 0
	for p in norm:
		max_x = maxi(max_x, p.x)
		max_y = maxi(max_y, p.y)
	return Vector2i(max_x + 1, max_y + 1)


static func get_all_shapes() -> Array[Dictionary]:
	if not _shapes_cache.is_empty():
		return _shapes_cache

	var raw_defs: Array[Dictionary] = [
		{"id": "mono_1", "tier": 0, "weight": 11, "pts": [Vector2i(0, 0)]},
		{"id": "duo_h", "tier": 0, "weight": 12, "pts": [Vector2i(0, 0), Vector2i(1, 0)]},
		{"id": "duo_v", "tier": 0, "weight": 12, "pts": [Vector2i(0, 0), Vector2i(0, 1)]},
		{"id": "trio_h", "tier": 0, "weight": 12, "pts": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]},
		{"id": "trio_v", "tier": 0, "weight": 12, "pts": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]},
		{"id": "sq_2x2", "tier": 0, "weight": 13, "pts": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]},
		{"id": "corner_tl", "tier": 0, "weight": 9, "pts": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]},
		{"id": "corner_tr", "tier": 0, "weight": 9, "pts": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]},
		{"id": "corner_bl", "tier": 0, "weight": 9, "pts": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]},
		{"id": "corner_br", "tier": 0, "weight": 9, "pts": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]},

		{"id": "quad_h", "tier": 1, "weight": 8, "pts": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]},
		{"id": "quad_v", "tier": 1, "weight": 8, "pts": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)]},
		{"id": "l4_up", "tier": 1, "weight": 7, "pts": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)]},
		{"id": "j4_up", "tier": 1, "weight": 7, "pts": [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)]},
		{"id": "l4_right", "tier": 1, "weight": 7, "pts": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1)]},
		{"id": "j4_left", "tier": 1, "weight": 7, "pts": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)]},
		{"id": "t4_down", "tier": 1, "weight": 7, "pts": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)]},
		{"id": "t4_up", "tier": 1, "weight": 7, "pts": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]},
		{"id": "t4_right", "tier": 1, "weight": 6, "pts": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)]},
		{"id": "t4_left", "tier": 1, "weight": 6, "pts": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)]},
		{"id": "z4_h", "tier": 1, "weight": 6, "pts": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)]},
		{"id": "s4_h", "tier": 1, "weight": 6, "pts": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)]},
		{"id": "z4_v", "tier": 1, "weight": 5, "pts": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)]},
		{"id": "s4_v", "tier": 1, "weight": 5, "pts": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)]},

		{"id": "penta_h", "tier": 2, "weight": 4, "pts": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]},
		{"id": "penta_v", "tier": 2, "weight": 4, "pts": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4)]},
		{"id": "big_l_bl", "tier": 2, "weight": 5, "pts": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]},
		{"id": "big_l_br", "tier": 2, "weight": 5, "pts": [Vector2i(2, 0), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]},
		{"id": "big_l_tl", "tier": 2, "weight": 5, "pts": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2)]},
		{"id": "big_l_tr", "tier": 2, "weight": 5, "pts": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]},
		{"id": "plus_5", "tier": 2, "weight": 4, "pts": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]},
		{"id": "diag_2_a", "tier": 1, "weight": 6, "pts": [Vector2i(0, 0), Vector2i(1, 1)]},
		{"id": "diag_2_b", "tier": 1, "weight": 6, "pts": [Vector2i(1, 0), Vector2i(0, 1)]},
		{"id": "diag_3_a", "tier": 2, "weight": 5, "pts": [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2)]},
		{"id": "diag_3_b", "tier": 2, "weight": 5, "pts": [Vector2i(2, 0), Vector2i(1, 1), Vector2i(0, 2)]},
		{"id": "rect_2x3", "tier": 2, "weight": 5, "pts": [
			Vector2i(0, 0), Vector2i(1, 0),
			Vector2i(0, 1), Vector2i(1, 1),
			Vector2i(0, 2), Vector2i(1, 2)
		]},
		{"id": "rect_3x2", "tier": 2, "weight": 5, "pts": [
			Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
			Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)
		]},
		{"id": "u_up", "tier": 2, "weight": 4, "pts": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]},
		{"id": "u_down", "tier": 2, "weight": 4, "pts": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(2, 1)]},
		{"id": "big_t", "tier": 2, "weight": 4, "pts": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(1, 2)]},
		{"id": "steps_5", "tier": 2, "weight": 4, "pts": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)]},
		{"id": "sq_3x3", "tier": 2, "weight": 4, "pts": [
			Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
			Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
			Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)
		]}
	]

	for def in raw_defs:
		var raw_pts: Array[Vector2i] = []
		for p in def["pts"]:
			raw_pts.append(p as Vector2i)
		var norm: Array[Vector2i] = normalize_cells(raw_pts)
		var b: Vector2i = compute_bounds(norm)
		_shapes_cache.append({
			"id": str(def["id"]),
			"tier": int(def["tier"]),
			"weight": int(def["weight"]),
			"cells": norm,
			"width": b.x,
			"height": b.y
		})

	return _shapes_cache


static func get_shape_by_id(shape_id: String) -> Dictionary:
	for sh in get_all_shapes():
		if str(sh["id"]) == shape_id:
			return sh
	return get_all_shapes()[0]


static func create_piece_instance(
	shape: Dictionary,
	rng: RandomNumberGenerator,
	special_rune: bool = false,
	specs: Dictionary = {}
) -> Dictionary:
	var pal_idx: int = rng.randi_range(0, PALETTE_ORDER.size() - 1)
	var pal_id: String = str(PALETTE_ORDER[pal_idx])
	var rune_id: int = rng.randi_range(0, 5)
	var cells_arr: Array[Vector2i] = []
	for p in shape["cells"]:
		cells_arr.append(p as Vector2i)
	var norm: Array[Vector2i] = normalize_cells(cells_arr)
	var b: Vector2i = compute_bounds(norm)
	return {
		"id": str(shape["id"]),
		"tier": int(shape.get("tier", 0)),
		"cells": norm,
		"width": b.x,
		"height": b.y,
		"palette_id": pal_id,
		"rune_id": rune_id,
		"special_rune": special_rune,
		"is_joker": false,
		"specs": specs.duplicate(true)
	}


static func create_joker_piece() -> Dictionary:
	var single: Array[Vector2i] = [Vector2i(0, 0)]
	return {
		"id": "joker_plus",
		"tier": 0,
		"cells": single,
		"width": 1,
		"height": 1,
		"palette_id": "amber",
		"rune_id": 3,
		"special_rune": true,
		"is_joker": true,
		"specs": {}
	}


static func get_palette(palette_id: String) -> Dictionary:
	var base: Dictionary = PALETTES[palette_id] if PALETTES.has(palette_id) else PALETTES["jade"]
	var tid: String = GameState.active_theme
	if tid == "obsidian_gold":
		return {
			"name": base["name"],
			"fill": (base["fill"] as Color).darkened(0.14).lerp(Color("#D97706"), 0.14),
			"highlight": (base["highlight"] as Color).lerp(Color("#FDE68A"), 0.35),
			"shadow": Color("#120D14"),
			"inner": (base["inner"] as Color).darkened(0.18),
			"rune": Color("#FEF08A")
		}
	elif tid == "glacier_rune":
		return {
			"name": base["name"],
			"fill": (base["fill"] as Color).lerp(Color("#0EA5E9"), 0.22),
			"highlight": (base["highlight"] as Color).lerp(Color("#E0F2FE"), 0.38),
			"shadow": (base["shadow"] as Color).lerp(Color("#082F49"), 0.35),
			"inner": (base["inner"] as Color).lerp(Color("#0369A1"), 0.22),
			"rune": Color("#F0F9FF")
		}
	return base


static func draw_joker_tile(canvas: CanvasItem, rect: Rect2, alpha: float = 1.0, pulse: float = 0.0) -> void:
	var bg := Color("#2B1C06")
	var mid := Color("#F59E0B").lerp(Color("#FEF08A"), 0.35 + 0.35 * pulse)
	var hi := Color("#FFFFFF")
	bg.a *= alpha
	mid.a *= alpha
	hi.a *= alpha

	canvas.draw_rect(rect, bg, true)
	canvas.draw_rect(rect.grow(-2.0), mid, true)
	canvas.draw_rect(rect.grow(-1.0), hi, false, 2.4)

	var c: Vector2 = rect.get_center()
	var arm: float = rect.size.x * 0.28
	var w: float = maxf(3.0, rect.size.x * 0.11)
	canvas.draw_line(c + Vector2(-arm, 0), c + Vector2(arm, 0), Color(0.12, 0.07, 0.02, alpha), w + 2.0, true)
	canvas.draw_line(c + Vector2(0, -arm), c + Vector2(0, arm), Color(0.12, 0.07, 0.02, alpha), w + 2.0, true)
	canvas.draw_line(c + Vector2(-arm, 0), c + Vector2(arm, 0), hi, w, true)
	canvas.draw_line(c + Vector2(0, -arm), c + Vector2(0, arm), hi, w, true)


static func draw_relic_tile(
	canvas: CanvasItem,
	rect: Rect2,
	palette_id: String,
	rune_id: int,
	alpha: float = 1.0,
	gold_pulse: float = 0.0,
	is_special_rune: bool = false
) -> void:
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return
	var pal: Dictionary = get_palette(palette_id)
	var c_fill: Color = pal["fill"]
	var c_hi: Color = pal["highlight"]
	var c_sh: Color = pal["shadow"]
	var c_in: Color = pal["inner"]
	var c_rune: Color = pal["rune"]

	if is_special_rune:
		c_hi = c_hi.lerp(Color("#FEF08A"), 0.55)
		c_rune = Color("#FEF08A")

	c_fill.a *= alpha
	c_hi.a *= alpha
	c_sh.a *= alpha
	c_in.a *= alpha
	c_rune.a *= alpha

	var bevel: float = clampf(rect.size.x * 0.12, 2.0, 7.0)

	canvas.draw_rect(rect, c_sh, true)

	var body_rect := Rect2(rect.position + Vector2(1.0, 1.0), rect.size - Vector2(2.0, bevel + 1.0))
	canvas.draw_rect(body_rect, c_fill, true)

	var top_strip := Rect2(rect.position + Vector2(2.0, 2.0), Vector2(rect.size.x - 4.0, bevel * 0.78))
	canvas.draw_rect(top_strip, c_hi.lerp(c_fill, 0.22), true)

	var inset: float = clampf(rect.size.x * 0.20, 4.0, 12.0)
	var inner_rect := Rect2(rect.position + Vector2(inset, inset * 0.92), rect.size - Vector2(inset * 2.0, inset * 2.05))
	if inner_rect.size.x > 4.0 and inner_rect.size.y > 4.0:
		canvas.draw_rect(inner_rect, c_in, true)
		canvas.draw_rect(inner_rect, c_hi * Color(1, 1, 1, 0.42), false, 1.2)

	var border_col: Color = Color("#F59E0B") if is_special_rune else c_hi.lerp(Color("#FDE68A"), clampf(gold_pulse, 0.0, 1.0))
	border_col.a = alpha * (0.95 if is_special_rune else (0.68 + 0.32 * gold_pulse))
	canvas.draw_rect(Rect2(rect.position + Vector2(0.5, 0.5), rect.size - Vector2(1.0, 1.0)), border_col, false, 2.2 if is_special_rune else 1.5)

	if is_special_rune and rect.size.x >= 18.0:
		canvas.draw_rect(rect.grow(-3.0), Color(0.99, 0.94, 0.54, 0.55 * alpha), false, 1.4)

	if rect.size.x >= 20.0:
		draw_rune_glyph(canvas, rect.get_center() - Vector2(0.0, bevel * 0.22), rect.size.x * 0.23, rune_id, c_rune)


static func draw_rune_glyph(canvas: CanvasItem, center: Vector2, radius: float, rune_id: int, col: Color) -> void:
	var r: float = maxf(3.0, radius)
	var w: float = clampf(r * 0.22, 1.4, 2.8)
	var glow_col := Color(col.r, col.g, col.b, col.a * 0.28)
	canvas.draw_circle(center, r * 0.85, glow_col)

	match posmod(rune_id, 6):
		0:
			var pts := PackedVector2Array([
				center + Vector2(0, -r),
				center + Vector2(r * 0.78, 0),
				center + Vector2(0, r),
				center + Vector2(-r * 0.78, 0),
				center + Vector2(0, -r)
			])
			canvas.draw_polyline(pts, col, w, true)
			canvas.draw_circle(center, r * 0.22, col)
		1:
			canvas.draw_line(center + Vector2(0, r), center + Vector2(0, -r), col, w, true)
			canvas.draw_line(center + Vector2(0, -r), center + Vector2(-r * 0.68, -r * 0.25), col, w, true)
			canvas.draw_line(center + Vector2(0, -r), center + Vector2(r * 0.68, -r * 0.25), col, w, true)
		2:
			var pts2 := PackedVector2Array([
				center + Vector2(-r * 0.7, -r * 0.8),
				center + Vector2(r * 0.7, -r * 0.8),
				center + Vector2(-r * 0.7, r * 0.8),
				center + Vector2(r * 0.7, r * 0.8),
				center + Vector2(-r * 0.7, -r * 0.8)
			])
			canvas.draw_polyline(pts2, col, w, true)
		3:
			canvas.draw_arc(center, r * 0.72, 0.0, TAU, 16, col, w, true)
			canvas.draw_line(center + Vector2(-r * 0.35, 0), center + Vector2(r * 0.35, 0), col, w, true)
			canvas.draw_line(center + Vector2(0, -r * 0.35), center + Vector2(0, r * 0.35), col, w, true)
		4:
			canvas.draw_line(center + Vector2(0, r), center + Vector2(0, -r * 0.9), col, w, true)
			canvas.draw_line(center + Vector2(0, -r * 0.1), center + Vector2(-r * 0.72, -r * 0.82), col, w, true)
			canvas.draw_line(center + Vector2(0, -r * 0.1), center + Vector2(r * 0.72, -r * 0.82), col, w, true)
		_:
			canvas.draw_line(center + Vector2(-r * 0.65, -r * 0.85), center + Vector2(-r * 0.65, r * 0.85), col, w, true)
			canvas.draw_line(center + Vector2(r * 0.65, -r * 0.85), center + Vector2(r * 0.65, r * 0.85), col, w, true)
			canvas.draw_line(center + Vector2(-r * 0.65, 0), center + Vector2(r * 0.65, 0), col, w, true)
			canvas.draw_circle(center + Vector2(0, -r * 0.5), r * 0.18, col)
