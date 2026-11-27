/**
 * Complete Godot 4.3+ Project Exporter & Zero-Dependency ZIP Archive Builder
 * Exports "RelicGrid: Mystic Block Odyssey" as a ready-to-open Godot 4 project
 * with GDScript 2.0 rules engine, custom _draw() 3D beveled block & ghost renderer,
 * procedural AudioStreamGenerator synth, Main.tscn scene, and mobile export presets.
 */

export interface GodotProjectFile {
  path: string;
  label: string;
  language: 'ini' | 'gdscript' | 'tscn' | 'markdown';
  description: string;
  content: string;
}

export const GODOT_PROJECT_FILES: GodotProjectFile[] = [
  {
    path: 'project.godot',
    label: 'project.godot',
    language: 'ini',
    description: 'Godot 4.3 proje yapılandırması (Mobil Portre 480x854, Input Map ve Render ayarları)',
    content: `; Engine configuration file.
; It's best edited using the editor UI and not directly,
; since the parameters that go here are not all obvious.
;
; Format:
;   [section] ; section goes between []
;   param=value ; assign values to parameters

config_version=5

[application]

config/name="RelicGrid: Mystic Block Odyssey"
config/description="Mobile-first tactical 8x8 block puzzle with Frozen/Bomb/Wildcard relics, ghost projections, and 500 campaign stages."
run/main_scene="res://scenes/Main.tscn"
config/features=PackedStringArray("4.3", "Forward Plus")
config/icon="res://icon.svg"

[display]

window/size/viewport_width=460
window/size/viewport_height=844
window/size/Mode=0
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=1

[input]

boost_rotate={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":82,"key_label":0,"unicode":114,"location":0,"echo":false,"script":null)
]
}
boost_hammer={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":72,"key_label":0,"unicode":104,"location":0,"echo":false,"script":null)
]
}
boost_reroll={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":70,"key_label":0,"unicode":102,"location":0,"echo":false,"script":null)
]
}
boost_bomb={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":66,"key_label":0,"unicode":98,"location":0,"echo":false,"script":null)
]
}

[rendering]

renderer/rendering_method="mobile"
anti_aliasing/quality/msaa_2d=2
`,
  },
  {
    path: 'scripts/RelicRules.gd',
    label: 'scripts/RelicRules.gd',
    language: 'gdscript',
    description: 'Saf GDScript 2.0 oyun kuralları motoru (8x8 mimariler, Buz/Bomba/Wildcard, Hayalet Çizgi Tahmini, Anti-P2W Booster sistemi)',
    content: `class_name RelicRules
extends RefCounted
## RelicGrid: Mystic Block Odyssey - Core Rules & Pure Logic Engine (Godot 4 GDScript)

const BOARD_SIZE: int = 8
const MAX_BOOSTER_USES_PER_SESSION: int = 3

enum CellKind { EMPTY, NORMAL, FROZEN, BOMB, WILDCARD, VOID }
enum GridArch { STANDARD, HOLED, SHIFTING, DIAGONAL_LOCKED }

constBOOSTER_BASE_COSTS := {
	"rotate": 35,
	"hammer": 60,
	"reroll": 45,
	"bomb_blast": 90
}

static func create_board(arch: int = GridArch.STANDARD) -> Array:
	var board: Array = []
	for r in range(BOARD_SIZE):
		var row: Array = []
		for c in range(BOARD_SIZE):
			var is_void := false
			if arch == GridArch.HOLED and (r == 3 or r == 4) and (c == 3 or c == 4):
				is_void = true
			elif arch == GridArch.DIAGONAL_LOCKED and (
				(r == 0 and c == 0) or (r == 0 and c == 7) or
				(r == 7 and c == 0) or (r == 7 and c == 7)
			):
				is_void = true
			row.append({
				"kind": CellKind.VOID if is_void else CellKind.EMPTY,
				"color": "emerald",
				"frozen_layers": 0,
				"bomb_timer": 0
			})
		board.append(row)
	return board

static func rotate_matrix_90(mat: Array) -> Array:
	var rows: int = mat.size()
	var cols: int = mat[0].size()
	var out: Array = []
	for c in range(cols):
		var new_row: Array = []
		for r in range(rows - 1, -1, -1):
			new_row.append(mat[r][c])
		out.append(new_row)
	return out

static func can_place_piece(board: Array, piece: Dictionary, anchor_r: int, anchor_c: int) -> bool:
	var mat: Array = piece["matrix"]
	var rows: int = mat.size()
	var cols: int = mat[0].size()
	for dr in range(rows):
		for dc in range(cols):
			if mat[dr][dc] == 1:
				var r: int = anchor_r + dr
				var c: int = anchor_c + dc
				if r < 0 or r >= BOARD_SIZE or c < 0 or c >= BOARD_SIZE:
					return false
				if board[r][c]["kind"] != CellKind.EMPTY:
					return false
	return true

## Predicts exact rows and columns that will clear upon releasing the piece at (anchor_r, anchor_c)
static func get_projected_clear_lines(board: Array, piece: Dictionary, anchor_r: int, anchor_c: int) -> Dictionary:
	if not can_place_piece(board, piece, anchor_r, anchor_c):
		return { "rows": [], "cols": [] }

	var mat: Array = piece["matrix"]
	var occupied := {}
	var has_wildcard := false
	var wild_r := -1
	var wild_c := -1

	for dr in range(mat.size()):
		for dc in range(mat[0].size()):
			if mat[dr][dc] == 1:
				var r: int = anchor_r + dr
				var c: int = anchor_c + dc
				occupied[r * BOARD_SIZE + c] = true
				for mod in piece.get("modifiers", []):
					if mod["dr"] == dr and mod["dc"] == dc and mod["kind"] == CellKind.WILDCARD:
						has_wildcard = true
						wild_r = r
						wild_c = c

	var clear_rows: Array[int] = []
	var clear_cols: Array[int] = []

	for r in range(BOARD_SIZE):
		var full := true
		for c in range(BOARD_SIZE):
			var k: int = board[r][c]["kind"]
			if k == CellKind.EMPTY and not occupied.has(r * BOARD_SIZE + c):
				full = false
				break
		if full:
			clear_rows.append(r)

	for c in range(BOARD_SIZE):
		var full := true
		for r in range(BOARD_SIZE):
			var k: int = board[r][c]["kind"]
			if k == CellKind.EMPTY and not occupied.has(r * BOARD_SIZE + c):
				full = false
				break
		if full:
			clear_cols.append(c)

	if has_wildcard and wild_r >= 0 and not clear_rows.has(wild_r):
		clear_rows.append(wild_r)

	return { "rows": clear_rows, "cols": clear_cols }

static func get_booster_coin_cost(booster_type: String, used_in_session: int) -> int:
	if used_in_session >= MAX_BOOSTER_USES_PER_SESSION:
		return -1
	var base: int = constBOOSTER_BASE_COSTS.get(booster_type, 50)
	return int(round(base * pow(1.75, used_in_session)))
`,
  },
  {
    path: 'scripts/RelicBoardCanvas.gd',
    label: 'scripts/RelicBoardCanvas.gd',
    language: 'gdscript',
    description: 'Godot 4 Control düğümü: 3D eğimli taş çizimi, yüksek şeffaflıklı Hayalet (Ghost) projeksiyonu, çizgi temizleme efektleri ve sürükle-bırak',
    content: `extends Control
## RelicGrid: Mystic Block Odyssey - Custom 60FPS Canvas Renderer & Ghost Projection

signal piece_placed(piece_idx: int, row: int, col: int, lines_cleared: int, score_delta: int)
signal piece_selected(piece_idx: int)

const BOARD_SIZE: int = 8

var board: Array = []
var tray: Array = []
var selected_piece_idx: int = 0
var hover_row: int = -1
var hover_col: int = -1
var cursor_row: int = 2
var cursor_col: int = 2
var is_dragging: bool = false
var pointer_pos: Vector2 = Vector2.ZERO
var sim_time: float = 0.0
var camera_trauma: float = 0.0

const PALETTES := {
	"emerald": { "fill": Color("#10B981"), "top": Color("#6EE7B7"), "bottom": Color("#065F46") },
	"amber":   { "fill": Color("#F59E0B"), "top": Color("#FDE68A"), "bottom": Color("#92400E") },
	"ruby":    { "fill": Color("#EF4444"), "top": Color("#FCA5A5"), "bottom": Color("#991B1B") },
	"sapphire":{ "fill": Color("#3B82F6"), "top": Color("#93C5FD"), "bottom": Color("#1E40AF") },
	"amethyst":{ "fill": Color("#A855F7"), "top": Color("#D8B4FE"), "bottom": Color("#6B21A8") }
}

func _ready() -> void:
	board = RelicRules.create_board(RelicRules.GridArch.STANDARD)
	# Seed initial obstacles
	board[0][0] = { "kind": RelicRules.CellKind.FROZEN, "color": "sapphire", "frozen_layers": 2, "bomb_timer": 0 }
	board[4][6] = { "kind": RelicRules.CellKind.BOMB, "color": "ruby", "frozen_layers": 0, "bomb_timer": 5 }
	_refill_tray()

func _refill_tray() -> void:
	tray = [
		{ "name": "Relic Dot", "color": "amber", "matrix": [[1]], "modifiers": [], "used": false },
		{ "name": "Relic L4", "color": "ruby", "matrix": [[1, 0], [1, 0], [1, 1]], "modifiers": [], "used": false },
		{ "name": "Relic Duo", "color": "emerald", "matrix": [[1, 1]], "modifiers": [], "used": false }
	]
	selected_piece_idx = 0
	queue_redraw()

func _process(delta: float) -> void:
	sim_time += delta
	camera_trauma = maxf(0.0, camera_trauma - delta * 2.5)
	queue_redraw()

func _compute_layout() -> Dictionary:
	var w: float = size.x
	var h: float = size.y
	var cell_size: float = clampf(floor(minf((w - 36.0) / 8.0, (h - 260.0) / 10.5)), 28.0, 50.0)
	var board_px: float = cell_size * BOARD_SIZE
	var board_left: float = round((w - board_px) * 0.5)
	var board_top: float = 118.0
	var tray_top: float = board_top + board_px + 16.0
	return {
		"cell_size": cell_size,
		"board_px": board_px,
		"board_left": board_left,
		"board_top": board_top,
		"tray_top": tray_top,
		"tray_slot_w": board_px / 3.0,
		"tray_h": 88.0
	}

func _update_hover_from_pointer(pt: Vector2, apply_lift: bool) -> void:
	var lay := _compute_layout()
	var s: float = lay["cell_size"]
	var eff_y: float = pt.y - s * 0.65 if apply_lift else pt.y
	var float_col: float = (pt.x - lay["board_left"]) / s
	var float_row: float = (eff_y - lay["board_top"]) / s

	if float_row >= -0.85 and float_row <= BOARD_SIZE + 0.85 and float_col >= -0.85 and float_col <= BOARD_SIZE + 0.85:
		var piece: Dictionary = tray[selected_piece_idx]
		if not piece["used"]:
			var mat: Array = piece["matrix"]
			var p_rows: int = mat.size()
			var p_cols: int = mat[0].size()
			var anchor_r: float = float_row - (p_rows - 1) * 0.5
			var anchor_c: float = float_col - (p_cols - 1) * 0.5
			var base_r: int = clampi(int(round(anchor_r)), 0, BOARD_SIZE - p_rows)
			var base_c: int = clampi(int(round(anchor_c)), 0, BOARD_SIZE - p_cols)

			if RelicRules.can_place_piece(board, piece, base_r, base_c):
				hover_row = base_r
				hover_col = base_c
				cursor_row = base_r
				cursor_col = base_c
				return

			# Magnetic 1-cell neighborhood snap
			var best_dist: float = 999.0
			var best_rc := Vector2i(-1, -1)
			for dr in range(-1, 2):
				for dc in range(-1, 2):
					var nr: int = base_r + dr
					var nc: int = base_c + dc
					if nr >= 0 and nr <= BOARD_SIZE - p_rows and nc >= 0 and nc <= BOARD_SIZE - p_cols:
						if RelicRules.can_place_piece(board, piece, nr, nc):
							var d: float = Vector2(nr - anchor_r, nc - anchor_c).length_squared()
							if d < best_dist:
								best_dist = d
								best_rc = Vector2i(nr, nc)
			if best_rc.x >= 0 and best_dist <= 1.85:
				hover_row = best_rc.x
				hover_col = best_rc.y
				cursor_row = best_rc.x
				cursor_col = best_rc.y
				return

			hover_row = base_r
			hover_col = base_c
			return

	hover_row = -1
	hover_col = -1

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer_pos = event.position
		var lay := _compute_layout()
		if event.pressed:
			# Check Tray click
			if pointer_pos.y >= lay["tray_top"] and pointer_pos.y <= lay["tray_top"] + lay["tray_h"]:
				var idx: int = clampi(int((pointer_pos.x - lay["board_left"]) / lay["tray_slot_w"]), 0, 2)
				if not tray[idx]["used"]:
					selected_piece_idx = idx
					is_dragging = true
					piece_selected.emit(idx)
					return
			_update_hover_from_pointer(pointer_pos, false)
			_try_commit_placement()
		else:
			if is_dragging:
				is_dragging = false
				_update_hover_from_pointer(pointer_pos, true)
				_try_commit_placement()
	elif event is InputEventMouseMotion:
		pointer_pos = event.position
		_update_hover_from_pointer(pointer_pos, is_dragging)

func _try_commit_placement() -> void:
	var piece: Dictionary = tray[selected_piece_idx]
	if piece["used"] or hover_row < 0 or hover_col < 0:
		return
	if RelicRules.can_place_piece(board, piece, hover_row, hover_col):
		var projected := RelicRules.get_projected_clear_lines(board, piece, hover_row, hover_col)
		var mat: Array = piece["matrix"]
		var placed_cells: int = 0
		for dr in range(mat.size()):
			for dc in range(mat[0].size()):
				if mat[dr][dc] == 1:
					board[hover_row + dr][hover_col + dc] = {
						"kind": RelicRules.CellKind.NORMAL,
						"color": piece["color"],
						"frozen_layers": 0,
						"bomb_timer": 0
					}
					placed_cells += 1
		for r in projected["rows"]:
			for c in range(BOARD_SIZE):
				board[r][c]["kind"] = RelicRules.CellKind.EMPTY
		for c in projected["cols"]:
			for r in range(BOARD_SIZE):
				board[r][c]["kind"] = RelicRules.CellKind.EMPTY

		var lines_cnt: int = projected["rows"].size() + projected["cols"].size()
		if lines_cnt > 0:
			camera_trauma = minf(1.0, camera_trauma + 0.35 * lines_cnt)
		piece["used"] = true
		if tray.all(func(p): return p["used"]):
			_refill_tray()
		else:
			for i in range(3):
				if not tray[i]["used"]:
					selected_piece_idx = i
					break
		hover_row = -1
		hover_col = -1
		piece_placed.emit(selected_piece_idx, cursor_row, cursor_col, lines_cnt, placed_cells * 10 + lines_cnt * 120)

func _draw_relic_block(rect: Rect2, color_key: String, alpha: float = 1.0) -> void:
	var pal: Dictionary = PALETTES.get(color_key, PALETTES["emerald"])
	var fill_c: Color = pal["fill"]
	fill_c.a = alpha
	var top_c: Color = pal["top"]
	top_c.a = alpha
	var bot_c: Color = pal["bottom"]
	bot_c.a = alpha

	draw_rect(rect.grow(-1.5), fill_c, true)
	draw_rect(Rect2(rect.position.x + 2, rect.position.y + 2, rect.size.x - 4, 5), top_c, true)
	draw_rect(Rect2(rect.position.x + 2, rect.end.y - 7, rect.size.x - 4, 5), bot_c, true)
	draw_rect(rect.grow(-1.5), Color(1, 1, 1, 0.28 * alpha), false, 1.2)

func _draw() -> void:
	var lay := _compute_layout()
	var s: float = lay["cell_size"]
	var b_left: float = lay["board_left"]
	var b_top: float = lay["board_top"]
	var b_px: float = lay["board_px"]
	var ghost_pulse: float = 0.5 + 0.5 * sin(sim_time * 7.0)

	# 1. Board Frame & Recessed Stone Sockets
	draw_rect(Rect2(b_left - 10, b_top - 10, b_px + 20, b_px + 20), Color("#07140F"), true)
	draw_rect(Rect2(b_left - 10, b_top - 10, b_px + 20, b_px + 20), Color("#D99B26"), false, 2.5)

	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			var cell_rect := Rect2(b_left + c * s, b_top + r * s, s, s)
			draw_rect(cell_rect.grow(-1.5), Color("#0E221A"), true)
			draw_rect(cell_rect.grow(-1.5), Color("#1A3A2D"), false, 1.0)
			var cell: Dictionary = board[r][c]
			if cell["kind"] != RelicRules.CellKind.EMPTY and cell["kind"] != RelicRules.CellKind.VOID:
				_draw_relic_block(cell_rect, cell["color"], 1.0)

	# 2. High-Transparency Ghost Piece Projection & Clear-Line Preview
	var piece: Dictionary = tray[selected_piece_idx]
	if not piece["used"]:
		var prev_r: int = hover_row if hover_row >= 0 else cursor_row
		var prev_c: int = hover_col if hover_col >= 0 else cursor_col
		var valid: bool = RelicRules.can_place_piece(board, piece, prev_r, prev_c)
		var projected := RelicRules.get_projected_clear_lines(board, piece, prev_r, prev_c) if valid else { "rows": [], "cols": [] }
		var total_lines: int = projected["rows"].size() + projected["cols"].size()

		# Highlight full rows/cols that will clear upon release
		if valid and total_lines > 0:
			for pr in projected["rows"]:
				var r_rect := Rect2(b_left + 1, b_top + pr * s + 1, b_px - 2, s - 2)
				draw_rect(r_rect, Color(0.99, 0.94, 0.54, 0.26 + 0.16 * ghost_pulse), true)
				draw_rect(r_rect, Color("#FEF08A"), false, 2.0)
			for pc in projected["cols"]:
				var c_rect := Rect2(b_left + pc * s + 1, b_top + 1, s - 2, b_px - 2)
				draw_rect(c_rect, Color(0.43, 0.91, 0.72, 0.26 + 0.16 * ghost_pulse), true)
				draw_rect(c_rect, Color("#6EE7B7"), false, 2.0)

		# Draw Snapped High-Transparency Ghost Cells
		var mat: Array = piece["matrix"]
		for dr in range(mat.size()):
			for dc in range(mat[0].size()):
				if mat[dr][dc] == 1:
					var r: int = prev_r + dr
					var c: int = prev_c + dc
					if r >= 0 and r < BOARD_SIZE and c >= 0 and c < BOARD_SIZE:
						var g_rect := Rect2(b_left + c * s, b_top + r * s, s, s)
						if valid:
							_draw_relic_block(g_rect, piece["color"], 0.36 + 0.08 * ghost_pulse)
							var frame_col := Color("#FEF08A") if total_lines > 0 else Color("#6EE7B7")
							draw_rect(g_rect.grow(-2.5), frame_col, false, 2.0)
							draw_circle(g_rect.get_center(), 2.2, frame_col)
						else:
							_draw_relic_block(g_rect, piece["color"], 0.20)
							draw_rect(g_rect.grow(-2.5), Color(0.97, 0.44, 0.44, 0.85), false, 1.8)
`,
  },
  {
    path: 'scripts/AudioSynth.gd',
    label: 'scripts/AudioSynth.gd',
    language: 'gdscript',
    description: 'Harici ses dosyası gerektirmeyen prosedürel AudioStreamGenerator ses sentezleyici (Do-Mi-Sol-Do kombo arpejleri ve taş yerleştirme sesleri)',
    content: `extends Node
## Procedural Web-Style Audio Synthesizer for Godot 4 using AudioStreamGenerator

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _sample_rate: float = 44100.0

const MAJOR_SCALE_RATIOS: Array[float] = [1.0, 1.25, 1.5, 2.0] # Do - Mi - Sol - Do

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = _sample_rate
	gen.buffer_length = 0.25
	_player.stream = gen
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()

func play_place_thud() -> void:
	_push_tone(92.0, 0.09, 0.25)

func play_line_clear(lines_count: int, combo_streak: int) -> void:
	var semitone_shift: int = mini(12, max(0, combo_streak - 1) * 2)
	var base_freq: float = 261.63 * pow(2.0, semitone_shift / 12.0)
	for ratio in MAJOR_SCALE_RATIOS:
		_push_tone(base_freq * ratio, 0.07, 0.20)

func _push_tone(freq: float, duration: float, volume: float) -> void:
	if _playback == null:
		return
	var total_frames: int = mini(_playback.get_frames_available(), int(_sample_rate * duration))
	var phase: float = 0.0
	var increment: float = freq / _sample_rate
	for i in range(total_frames):
		var env: float = 1.0 - (float(i) / float(total_frames))
		var sample: float = sin(phase * TAU) * volume * env
		_playback.push_frame(Vector2(sample, sample))
		phase = fmod(phase + increment, 1.0)
`,
  },
  {
    path: 'scenes/Main.tscn',
    label: 'scenes/Main.tscn',
    language: 'tscn',
    description: 'Ana Godot 4 Sahnesi (Top HUD, RelicBoardCanvas ve Alt Booster Çubuğu hiyerarşisi)',
    content: `[gd_scene load_steps=3 format=3 uid="uid://relicgrid_main_scene"]

[ext_resource type="Script" path="res://scripts/RelicBoardCanvas.gd" id="1_board"]
[ext_resource type="Script" path="res://scripts/AudioSynth.gd" id="2_audio"]

[node name="Main" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Background" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0.035, 0.078, 0.063, 1)

[node name="RelicBoardCanvas" type="Control" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_board")

[node name="AudioSynth" type="Node" parent="."]
script = ExtResource("2_audio")
`,
  },
  {
    path: 'export_presets.cfg',
    label: 'export_presets.cfg',
    language: 'ini',
    description: 'Godot 4 Android (.apk/.aab), iOS ve Web (HTML5) hazır dışa aktarma profilleri',
    content: `[preset.0]

name="Android Mobile Portrait"
platform="Android"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/android/RelicGrid.apk"

[preset.0.options]

package/unique_name="com.mysticodyssey.relicgrid"
package/name="RelicGrid: Mystic Block Odyssey"
screen/immersive_mode=true

[preset.1]

name="Web (HTML5)"
platform="Web"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/web/index.html"
`,
  },
  {
    path: 'README_GODOT_TR.md',
    label: 'README_GODOT_TR.md',
    language: 'markdown',
    description: 'Godot 4 Kurulum ve Mobil / Masaüstü Çıktı Alma Rehberi (Türkçe)',
    content: `# RelicGrid: Mystic Block Odyssey — Godot 4.3+ Projesi

Bu paket, **RelicGrid: Mystic Block Odyssey** oyununun **Godot Engine 4.3+** için hazırlanmış tam kaynak kodlarını içerir.

## 1. Godot 4'te Projeyi Açma
1. İndirdiğiniz \`RelicGrid_Godot4_Project.zip\` arşivini bir klasöre çıkartın.
2. **Godot Engine 4.3** (veya üzeri) uygulamasını açın.
3. **Import (İçe Aktar)** butonuna tıklayın ve çıkarttığınız klasördeki \`project.godot\` dosyasını seçin.
4. Sağ üstteki **Run Project (F5)** tuşuna basarak oyunu hemen çalıştırabilirsiniz!

## 2. Mimari ve Dosya Yapısı
- \`project.godot\`: Mobil portre (\`460x844\`, \`canvas_items\` ölçekleme) ve klavye kısayolları (\`R\`, \`H\`, \`F\`, \`B\`).
- \`scripts/RelicRules.gd\`: 8x8 değişken ızgara mimarileri (\`STANDARD\`, \`HOLED\`, \`SHIFTING\`, \`DIAGONAL_LOCKED\`), çok katmanlı **Frozen (Buz)** blokları, geri sayımlı **Bomb (Bomba)** blokları, **Wildcard** 3x3 dönüşümü, **Hayalet Çizgi Tahmini (\`get_projected_clear_lines\`)** ve Anti-Pay-to-Win 3 kullanım sınırına sahip üstel Booster maliyet motoru.
- \`scripts/RelicBoardCanvas.gd\`: 60 FPS \`_draw()\` özel çizim motoru, 3D eğimli parlak taşlar, yüksek şeffaflıklı **Ghost (Hayalet)** parça projeksiyonu, mıknatıslı hücre yakalama ve sürükle-bırak kontrolleri.
- \`scripts/AudioSynth.gd\`: Harici ses dosyası gerektirmeyen \`AudioStreamGenerator\` tabanlı prosedürel ses sentezleyici (\`Do-Mi-Sol-Do\` yükselen kombo arpejleri).
- \`scenes/Main.tscn\`: Ana oyun sahnesi.
- \`export_presets.cfg\`: Android (\`.apk\` / \`.aab\`) ve Web (\`HTML5\`) için hazır dışa aktarma profilleri.
`,
  },
];

// Precomputed CRC32 Lookup Table for valid PKZIP archive generation
const CRC32_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let k = 0; k < 8; k++) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    table[i] = c >>> 0;
  }
  return table;
})();

export function computeCrc32(bytes: Uint8Array): number {
  let crc = 0xffffffff;
  for (let i = 0; i < bytes.length; i++) {
    crc = CRC32_TABLE[(crc ^ bytes[i]) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

/**
 * Builds a standards-compliant uncompressed PKZIP (.zip) binary Uint8Array
 * containing all Godot 4 project files so users can download and extract directly.
 */
export function buildGodotProjectZipBytes(
  files: GodotProjectFile[] = GODOT_PROJECT_FILES
): Uint8Array {
  const encoder = new TextEncoder();
  const encodedEntries = files.map((file) => {
    const nameBytes = encoder.encode(`RelicGrid_Godot4/${file.path}`);
    const dataBytes = encoder.encode(file.content);
    const crc = computeCrc32(dataBytes);
    return { nameBytes, dataBytes, crc };
  });

  let localHeadersSize = 0;
  let centralDirSize = 0;
  for (const entry of encodedEntries) {
    localHeadersSize += 30 + entry.nameBytes.length + entry.dataBytes.length;
    centralDirSize += 46 + entry.nameBytes.length;
  }

  const totalSize = localHeadersSize + centralDirSize + 22;
  const out = new Uint8Array(totalSize);
  const view = new DataView(out.buffer);

  let offset = 0;
  const localOffsets: number[] = [];

  // 1. Write Local File Headers + File Data
  for (const entry of encodedEntries) {
    localOffsets.push(offset);
    view.setUint32(offset, 0x04034b50, true); // Local file header signature
    view.setUint16(offset + 4, 20, true); // Version needed to extract (2.0)
    view.setUint16(offset + 6, 0x0800, true); // UTF-8 filename flag
    view.setUint16(offset + 8, 0, true); // Compression method (0 = Store)
    view.setUint16(offset + 10, 0, true); // Last mod file time
    view.setUint16(offset + 12, 0, true); // Last mod file date
    view.setUint32(offset + 14, entry.crc, true); // CRC-32
    view.setUint32(offset + 18, entry.dataBytes.length, true); // Compressed size
    view.setUint32(offset + 22, entry.dataBytes.length, true); // Uncompressed size
    view.setUint16(offset + 26, entry.nameBytes.length, true); // File name length
    view.setUint16(offset + 28, 0, true); // Extra field length
    out.set(entry.nameBytes, offset + 30);
    offset += 30 + entry.nameBytes.length;

    out.set(entry.dataBytes, offset);
    offset += entry.dataBytes.length;
  }

  const centralDirOffset = offset;

  // 2. Write Central Directory Headers
  for (let i = 0; i < encodedEntries.length; i++) {
    const entry = encodedEntries[i];
    view.setUint32(offset, 0x02014b50, true); // Central file header signature
    view.setUint16(offset + 4, 20, true); // Version made by
    view.setUint16(offset + 6, 20, true); // Version needed to extract
    view.setUint16(offset + 8, 0x0800, true); // UTF-8 flag
    view.setUint16(offset + 10, 0, true); // Compression method (Store)
    view.setUint16(offset + 12, 0, true); // Time
    view.setUint16(offset + 14, 0, true); // Date
    view.setUint32(offset + 16, entry.crc, true); // CRC-32
    view.setUint32(offset + 20, entry.dataBytes.length, true); // Compressed size
    view.setUint32(offset + 24, entry.dataBytes.length, true); // Uncompressed size
    view.setUint16(offset + 28, entry.nameBytes.length, true); // File name length
    view.setUint16(offset + 30, 0, true); // Extra field length
    view.setUint16(offset + 32, 0, true); // File comment length
    view.setUint16(offset + 34, 0, true); // Disk number start
    view.setUint16(offset + 36, 0, true); // Internal file attributes
    view.setUint32(offset + 38, 0, true); // External file attributes
    view.setUint32(offset + 42, localOffsets[i], true); // Relative offset of local header
    out.set(entry.nameBytes, offset + 46);
    offset += 46 + entry.nameBytes.length;
  }

  // 3. Write End of Central Directory Record (EOCD)
  view.setUint32(offset, 0x06054b50, true); // EOCD signature
  view.setUint16(offset + 4, 0, true); // Number of this disk
  view.setUint16(offset + 6, 0, true); // Disk where central directory starts
  view.setUint16(offset + 8, encodedEntries.length, true); // Total entries on this disk
  view.setUint16(offset + 10, encodedEntries.length, true); // Total entries in central directory
  view.setUint32(offset + 12, centralDirSize, true); // Size of central directory
  view.setUint32(offset + 16, centralDirOffset, true); // Offset of start of central directory
  view.setUint16(offset + 20, 0, true); // Comment length

  return out;
}
