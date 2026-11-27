class_name RelicRules
extends RefCounted
## RelicGrid: Mystic Block Odyssey - Core Rules & Pure Logic Engine (Godot 4 GDScript)

const BOARD_SIZE: int = 8
const MAX_BOOSTER_USES_PER_SESSION: int = 3

enum CellKind { EMPTY, NORMAL, FROZEN, BOMB, WILDCARD, VOID }
enum GridArch { STANDARD, HOLED, SHIFTING, DIAGONAL_LOCKED }

const BOOSTER_BASE_COSTS := {
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

static func get_projected_clear_lines(board: Array, piece: Dictionary, anchor_r: int, anchor_c: int) -> Dictionary:
	if not can_place_piece(board, piece, anchor_r, anchor_c):
		return { "rows": [], "cols": [] }

	var mat: Array = piece["matrix"]
	var occupied := {}
	var has_wildcard := false
	var wild_r := -1

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
	var base: int = BOOSTER_BASE_COSTS.get(booster_type, 50)
	return int(round(base * pow(1.75, used_in_session)))
