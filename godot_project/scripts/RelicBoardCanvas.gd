extends Control
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

	var piece: Dictionary = tray[selected_piece_idx]
	if not piece["used"]:
		var prev_r: int = hover_row if hover_row >= 0 else cursor_row
		var prev_c: int = hover_col if hover_col >= 0 else cursor_col
		var valid: bool = RelicRules.can_place_piece(board, piece, prev_r, prev_c)
		var projected := RelicRules.get_projected_clear_lines(board, piece, prev_r, prev_c) if valid else { "rows": [], "cols": [] }
		var total_lines: int = projected["rows"].size() + projected["cols"].size()

		if valid and total_lines > 0:
			for pr in projected["rows"]:
				var r_rect := Rect2(b_left + 1, b_top + pr * s + 1, b_px - 2, s - 2)
				draw_rect(r_rect, Color(0.99, 0.94, 0.54, 0.26 + 0.16 * ghost_pulse), true)
				draw_rect(r_rect, Color("#FEF08A"), false, 2.0)
			for pc in projected["cols"]:
				var c_rect := Rect2(b_left + pc * s + 1, b_top + 1, s - 2, b_px - 2)
				draw_rect(c_rect, Color(0.43, 0.91, 0.72, 0.26 + 0.16 * ghost_pulse), true)
				draw_rect(c_rect, Color("#6EE7B7"), false, 2.0)

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
