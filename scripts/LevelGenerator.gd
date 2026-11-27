class_name LevelGenerator
extends RefCounted
## 500 bölümlük deterministik kampanya, Günlük Mozaik ve iki ayrı Sonsuz Mod
## (MODE_NORMAL_ENDLESS & MODE_SPECIAL_ENDLESS) seviye üreteci.

const MODE_CAMPAIGN: String = "campaign"
const MODE_DAILY: String = "daily"
const MODE_NORMAL_ENDLESS: String = "normal_endless"
const MODE_SPECIAL_ENDLESS: String = "special_endless"

enum ObstacleType {
	NONE = 0,
	CRACKED_STONE = 1,
	FROZEN_RELIC = 2,
	CURSED_SEAL = 3
}

enum ArchType {
	CLASSIC_8X8 = 0,
	OCTAGON_SANCTUM = 1,
	COURTYARD_RING = 2,
	GRAND_9X9 = 3,
	TWIN_CORRIDORS = 4,
	SACRED_CROSS = 5,
	STEPPED_SHRINE = 6
}

const BIOME_NAMES: Array = [
	"Zümrüt",
	"Kehribar",
	"Buzul",
	"Koridor",
	"Ametist",
	"Yakut",
	"Safir",
	"Obsidyen",
	"Dikilitaş",
	"Ebedi"
]


static func get_biome_name_for_stage(stage: int) -> String:
	var idx: int = clampi(int((stage - 1) / 50), 0, BIOME_NAMES.size() - 1)
	return str(BIOME_NAMES[idx])


static func get_architecture_name(arch: int) -> String:
	match arch:
		ArchType.CLASSIC_8X8: return "8x8"
		ArchType.OCTAGON_SANCTUM: return "Sekizgen"
		ArchType.COURTYARD_RING: return "Avlu"
		ArchType.GRAND_9X9: return "9x9"
		ArchType.TWIN_CORRIDORS: return "Koridor"
		ArchType.SACRED_CROSS: return "Artı"
		ArchType.STEPPED_SHRINE: return "Sunak"
		_: return "Izgara"


static func build_architecture_mask(arch: int) -> Dictionary:
	var rows: int = 8
	var cols: int = 8
	if arch in [ArchType.GRAND_9X9, ArchType.TWIN_CORRIDORS, ArchType.SACRED_CROSS, ArchType.STEPPED_SHRINE]:
		rows = 9
		cols = 9

	var mask: Array = []
	var active_count: int = 0

	for r in range(rows):
		var row_arr: Array[bool] = []
		for c in range(cols):
			var is_active: bool = true
			match arch:
				ArchType.CLASSIC_8X8, ArchType.GRAND_9X9:
					is_active = true
				ArchType.OCTAGON_SANCTUM:
					var corner_dist: int = mini(r, rows - 1 - r) + mini(c, cols - 1 - c)
					is_active = (corner_dist >= 2)
				ArchType.COURTYARD_RING:
					is_active = not ((r == 3 or r == 4) and (c == 3 or c == 4))
				ArchType.TWIN_CORRIDORS:
					var pillar_r: bool = (r == 2 or r == 6)
					var pillar_c: bool = (c == 2 or c == 6)
					is_active = not (pillar_r and pillar_c)
				ArchType.SACRED_CROSS:
					var in_corner_2x2: bool = (r < 2 or r > 6) and (c < 2 or c > 6)
					is_active = not in_corner_2x2
				ArchType.STEPPED_SHRINE:
					var edge_sum: int = mini(r, rows - 1 - r) + mini(c, cols - 1 - c)
					var center_hole: bool = (r == 4 and c == 4)
					is_active = (edge_sum >= 2) and not center_hole

			row_arr.append(is_active)
			if is_active:
				active_count += 1
		mask.append(row_arr)

	return {
		"rows": rows,
		"cols": cols,
		"mask": mask,
		"active_count": active_count
	}


static func generate_campaign_level(stage_num: int) -> Dictionary:
	var stage: int = clampi(stage_num, 1, 500)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(stage) * 1103515245 + 12345

	var progress: float = float(stage - 1) / 499.0
	var allowed_archs: Array[int] = [ArchType.CLASSIC_8X8]
	if stage >= 5:
		allowed_archs.append(ArchType.OCTAGON_SANCTUM)
	if stage >= 12:
		allowed_archs.append(ArchType.COURTYARD_RING)
	if stage >= 22:
		allowed_archs.append(ArchType.GRAND_9X9)
	if stage >= 38:
		allowed_archs.append(ArchType.SACRED_CROSS)
	if stage >= 55:
		allowed_archs.append(ArchType.TWIN_CORRIDORS)
	if stage >= 75:
		allowed_archs.append(ArchType.STEPPED_SHRINE)

	var arch: int = ArchType.CLASSIC_8X8
	if stage == 1:
		arch = ArchType.CLASSIC_8X8
	elif stage == 5:
		arch = ArchType.OCTAGON_SANCTUM
	elif stage == 12:
		arch = ArchType.COURTYARD_RING
	elif stage == 22:
		arch = ArchType.GRAND_9X9
	elif stage == 38:
		arch = ArchType.SACRED_CROSS
	elif stage == 55:
		arch = ArchType.TWIN_CORRIDORS
	elif stage == 75:
		arch = ArchType.STEPPED_SHRINE
	else:
		arch = allowed_archs[rng.randi_range(0, allowed_archs.size() - 1)]

	var arch_data: Dictionary = build_architecture_mask(arch)
	var rows: int = int(arch_data["rows"])
	var cols: int = int(arch_data["cols"])
	var mask: Array = arch_data["mask"]
	var active_count: int = int(arch_data["active_count"])

	var base_obs: int = 2 + int(floor(progress * 11.0)) + (1 if stage % 10 == 0 else 0)
	var max_safe_obs: int = maxi(3, int(floor(float(active_count) * 0.24)))
	var obstacle_count: int = clampi(base_obs, 2, max_safe_obs)
	if stage == 1:
		obstacle_count = 2
	elif stage == 2:
		obstacle_count = 3

	var allow_cracked_2hp: bool = (stage >= 10)
	var allow_frozen: bool = (stage >= 16)
	var allow_cursed: bool = (stage >= 32)

	var initial_cells: Array[Dictionary] = _place_deterministic_obstacles(
		rng, rows, cols, mask, obstacle_count, allow_cracked_2hp, allow_frozen, allow_cursed, stage
	)

	var target_obstacles: int = initial_cells.size()
	var raw_score: int = 320 + stage * 14 + int(pow(float(stage), 1.32) * 1.8)
	var target_score: int = int(round(float(raw_score) / 25.0)) * 25

	var max_shape_tier: int = 0
	if stage >= 4:
		max_shape_tier = 1
	if stage >= 18:
		max_shape_tier = 2

	var star_1: int = target_score
	var star_2: int = int(round(float(target_score) * 1.35 / 25.0)) * 25
	var star_3: int = int(round(float(target_score) * 1.75 / 25.0)) * 25

	return {
		"mode": MODE_CAMPAIGN,
		"scoring_mode": "standard",
		"spawn_dynamic": false,
		"stage": stage,
		"title": "BÖLÜM %d" % stage,
		"arch": arch,
		"arch_name": get_architecture_name(arch),
		"biome_name": get_biome_name_for_stage(stage),
		"rows": rows,
		"cols": cols,
		"active_mask": mask,
		"initial_cells": initial_cells,
		"target_score": target_score,
		"target_obstacles": target_obstacles,
		"star_thresholds": [star_1, star_2, star_3],
		"piece_seed": int(stage) * 747796405 + 98765,
		"max_shape_tier": max_shape_tier
	}


static func generate_daily_level(date_dict: Dictionary) -> Dictionary:
	var y: int = int(date_dict.get("year", 2026))
	var m: int = int(date_dict.get("month", 1))
	var d: int = int(date_dict.get("day", 1))
	var date_seed: int = y * 10000 + m * 100 + d

	var rng := RandomNumberGenerator.new()
	rng.seed = date_seed * 2654435761 + 40503

	var daily_archs: Array[int] = [
		ArchType.OCTAGON_SANCTUM,
		ArchType.COURTYARD_RING,
		ArchType.GRAND_9X9,
		ArchType.TWIN_CORRIDORS,
		ArchType.SACRED_CROSS,
		ArchType.STEPPED_SHRINE
	]
	var arch: int = daily_archs[rng.randi_range(0, daily_archs.size() - 1)]
	var arch_data: Dictionary = build_architecture_mask(arch)
	var rows: int = int(arch_data["rows"])
	var cols: int = int(arch_data["cols"])
	var mask: Array = arch_data["mask"]
	var active_count: int = int(arch_data["active_count"])

	var obs_count: int = clampi(rng.randi_range(6, 9), 5, int(floor(float(active_count) * 0.20)))
	var initial_cells: Array[Dictionary] = _place_deterministic_obstacles(
		rng, rows, cols, mask, obs_count, true, true, true, 90
	)

	var target_score: int = 950 + rng.randi_range(0, 6) * 75
	return {
		"mode": MODE_DAILY,
		"scoring_mode": "standard",
		"spawn_dynamic": false,
		"stage": 0,
		"title": "GÜNLÜK %02d/%02d" % [d, m],
		"arch": arch,
		"arch_name": get_architecture_name(arch),
		"biome_name": "Günlük",
		"rows": rows,
		"cols": cols,
		"active_mask": mask,
		"initial_cells": initial_cells,
		"target_score": target_score,
		"target_obstacles": initial_cells.size(),
		"star_thresholds": [target_score, int(target_score * 1.35), int(target_score * 1.75)],
		"piece_seed": date_seed * 1597334677 + 31337,
		"max_shape_tier": 2
	}


## 1) Normal Sonsuz: Klasik 8x8, engel yok, klasik kombo puanlaması.
static func generate_normal_endless_level() -> Dictionary:
	var arch_data: Dictionary = build_architecture_mask(ArchType.CLASSIC_8X8)
	var seed_now: int = int(Time.get_ticks_usec() & 0x3FFFFFFF) + int(Time.get_unix_time_from_system())
	return {
		"mode": MODE_NORMAL_ENDLESS,
		"scoring_mode": MODE_NORMAL_ENDLESS,
		"spawn_dynamic": false,
		"stage": 0,
		"title": "NORMAL ∞",
		"arch": ArchType.CLASSIC_8X8,
		"arch_name": "8x8",
		"biome_name": "Normal",
		"rows": int(arch_data["rows"]),
		"cols": int(arch_data["cols"]),
		"active_mask": arch_data["mask"],
		"initial_cells": [],
		"target_score": 0,
		"target_obstacles": 0,
		"star_thresholds": [500, 1500, 3000],
		"piece_seed": seed_now,
		"max_shape_tier": 2
	}


## 2) Özel Sonsuz: Dinamik engeller + Özel Rün blokları + katlanan seri çarpanı.
static func generate_special_endless_level() -> Dictionary:
	var arch_data: Dictionary = build_architecture_mask(ArchType.CLASSIC_8X8)
	var rows: int = int(arch_data["rows"])
	var cols: int = int(arch_data["cols"])
	var mask: Array = arch_data["mask"]
	var seed_now: int = int(Time.get_ticks_usec() & 0x3FFFFFFF) + int(Time.get_unix_time_from_system()) + 777
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_now

	var initial_cells: Array[Dictionary] = _place_deterministic_obstacles(
		rng, rows, cols, mask, 4, true, true, true, 120
	)
	# Başlangıçta 2 adet parlak Özel Rün taşı da ekle
	initial_cells.append({
		"col": 2,
		"row": 2,
		"obstacle": ObstacleType.NONE,
		"hp": 1,
		"ice_layers": 0,
		"curse_timer": 0,
		"curse_max": 5,
		"palette_id": "amber",
		"rune_id": 0,
		"special_rune": true
	})
	initial_cells.append({
		"col": 5,
		"row": 5,
		"obstacle": ObstacleType.NONE,
		"hp": 1,
		"ice_layers": 0,
		"curse_timer": 0,
		"curse_max": 5,
		"palette_id": "jade",
		"rune_id": 3,
		"special_rune": true
	})

	return {
		"mode": MODE_SPECIAL_ENDLESS,
		"scoring_mode": MODE_SPECIAL_ENDLESS,
		"spawn_dynamic": true,
		"stage": 0,
		"title": "ÖZEL ∞",
		"arch": ArchType.CLASSIC_8X8,
		"arch_name": "8x8",
		"biome_name": "Özel",
		"rows": rows,
		"cols": cols,
		"active_mask": mask,
		"initial_cells": initial_cells,
		"target_score": 0,
		"target_obstacles": 0,
		"star_thresholds": [800, 2200, 4500],
		"piece_seed": seed_now,
		"max_shape_tier": 2
	}


static func generate_endless_level() -> Dictionary:
	return generate_normal_endless_level()


static func _place_deterministic_obstacles(
	rng: RandomNumberGenerator,
	rows: int,
	cols: int,
	mask: Array,
	count: int,
	allow_cracked_2hp: bool,
	allow_frozen: bool,
	allow_cursed: bool,
	stage_hint: int
) -> Array[Dictionary]:
	var candidates: Array[Vector2i] = []
	for r in range(rows):
		var row_mask: Array = mask[r]
		for c in range(cols):
			if bool(row_mask[c]):
				candidates.append(Vector2i(c, r))

	for i in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	var row_counts: Array[int] = []
	row_counts.resize(rows)
	row_counts.fill(0)
	var col_counts: Array[int] = []
	col_counts.resize(cols)
	col_counts.fill(0)

	var placed: Array[Dictionary] = []
	var cursed_placed: int = 0
	var max_cursed: int = 1 if stage_hint < 90 else (2 if stage_hint < 240 else 3)

	for pos in candidates:
		if placed.size() >= count:
			break
		if row_counts[pos.y] >= 3 or col_counts[pos.x] >= 3:
			continue

		var obs_type: int = ObstacleType.CRACKED_STONE
		var roll: float = rng.randf()

		if allow_cursed and cursed_placed < max_cursed and roll < 0.22:
			obs_type = ObstacleType.CURSED_SEAL
			cursed_placed += 1
		elif allow_frozen and roll < 0.56:
			obs_type = ObstacleType.FROZEN_RELIC
		else:
			obs_type = ObstacleType.CRACKED_STONE

		if stage_hint == 16 and placed.is_empty():
			obs_type = ObstacleType.FROZEN_RELIC
		elif stage_hint == 32 and placed.is_empty():
			obs_type = ObstacleType.CURSED_SEAL
			cursed_placed += 1

		var pal_id: String = str(PieceLibrary.PALETTE_ORDER[rng.randi_range(0, PieceLibrary.PALETTE_ORDER.size() - 1)])
		var rune_id: int = rng.randi_range(0, 5)
		var hp: int = 1
		var ice_layers: int = 0
		var curse_timer: int = 0

		match obs_type:
			ObstacleType.CRACKED_STONE:
				hp = 2 if (allow_cracked_2hp and rng.randf() < clampf(0.28 + float(stage_hint) * 0.0012, 0.28, 0.72)) else 1
				pal_id = "relic_stone"
			ObstacleType.FROZEN_RELIC:
				hp = 1
				ice_layers = 1
			ObstacleType.CURSED_SEAL:
				hp = 1
				curse_timer = clampi(6 - int(stage_hint / 180), 4, 6)

		placed.append({
			"col": pos.x,
			"row": pos.y,
			"obstacle": obs_type,
			"hp": hp,
			"ice_layers": ice_layers,
			"curse_timer": curse_timer,
			"curse_max": curse_timer,
			"palette_id": pal_id,
			"rune_id": rune_id,
			"special_rune": false
		})
		row_counts[pos.y] += 1
		col_counts[pos.x] += 1

	return placed
