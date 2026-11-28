extends Node
## Kalıcı oyun durumu, kayıt/yükleme (user://relicgrid_save.json),
## 500 bölümlük kampanya, Günlük Mozaik, Normal/Özel Sonsuz modlar,
## Altın (coins), No Ads, Güçlendiriciler (boosters) ve Temalar yöneticisi.

signal state_updated

const SAVE_PATH: String = "user://relicgrid_save.json"
const MAX_CAMPAIGN_STAGE: int = 500

enum PlayMode {
	CAMPAIGN = 0,
	DAILY_MOSAIC = 1,
	MODE_NORMAL_ENDLESS = 2,
	MODE_SPECIAL_ENDLESS = 3
}

const BOOSTER_COSTS: Dictionary = {
	"hammer": 120,
	"rotate": 100,
	"refresh": 90,
	"bomb": 180
}

const LEAGUE_TIERS: Array = [
	{"id": "bronze", "name": "Bronz", "min_pts": 0, "accent": Color("#CD7F32"), "rival_base": 450, "rival_span": 1800},
	{"id": "silver", "name": "Gümüş", "min_pts": 2200, "accent": Color("#C0C8D4"), "rival_base": 1900, "rival_span": 3200},
	{"id": "gold", "name": "Altın", "min_pts": 5500, "accent": Color("#F59E0B"), "rival_base": 4800, "rival_span": 5200},
	{"id": "emerald", "name": "Zümrüt", "min_pts": 11000, "accent": Color("#10B981"), "rival_base": 9500, "rival_span": 8500},
	{"id": "mystic", "name": "Mistik", "min_pts": 20000, "accent": Color("#C084FC"), "rival_base": 17500, "rival_span": 16000}
]

const RIVAL_NAMES: Array = [
	"AethelRün", "ZümrütKahin", "KayaMühür", "AltınGözcü", "LapisGezgin",
	"ObsidyenOk", "TapınakBekçisi", "MistikÇekiç", "KadimMozaik", "SafirGölge",
	"Kehribarİz", "YakutÜstad", "SfenksTaşı", "DerinOrman", "SessizDikilitaş",
	"AmetistKule", "GüneşMührü", "AyTapınağı", "RünAvcısı"
]

# Çalışma zamanı oturum seçimi
var active_mode: PlayMode = PlayMode.CAMPAIGN
var selected_stage: int = 1
var campaign_page: int = 0

# Kalıcı oyuncu verileri
var unlocked_stage: int = 1
var stage_stars: Dictionary = {} # "1": 1..3
var stage_best_scores: Dictionary = {} # "1": int
var best_normal_endless: int = 0
var best_special_endless: int = 0
var endless_high_score: int = 0 # Geriye dönük uyumluluk özeti
var sound_enabled: bool = true

# Ekonomi, No Ads, Güçlendiriciler ve Temalar
var coins: int = 300
var no_ads: bool = false
var boosters: Dictionary = {
	"hammer": 2,
	"rotate": 2,
	"refresh": 2,
	"bomb": 1
}
var unlocked_themes: Array = ["emerald_temple"]
var active_theme: String = "emerald_temple"

# Günlük Mozaik verileri
var daily_streak: int = 0
var best_daily_streak: int = 0
var last_daily_completed_key: String = "" # "YYYY-MM-DD"
var mosaic_week_id: String = ""
var mosaic_week_days: Array[bool] = [false, false, false, false, false, false, false] # Pzt..Paz (0..6)

# Haftalık Kohort verileri
var weekly_key: String = ""
var weekly_points: int = 0
var cohort_tier_index: int = 0 # 0: Bronz .. 4: Mistik
var player_callsign: String = "Mistik Mimar"


func _ready() -> void:
	load_save()
	_sync_calendar_states()


func get_today_dict() -> Dictionary:
	return Time.get_date_dict_from_system()


func get_date_key(d: Dictionary) -> String:
	return "%04d-%02d-%02d" % [int(d.get("year", 2026)), int(d.get("month", 1)), int(d.get("day", 1))]


func get_today_key() -> String:
	return get_date_key(get_today_dict())


func get_today_seed() -> int:
	var d: Dictionary = get_today_dict()
	return int(d.get("year", 2026)) * 10000 + int(d.get("month", 1)) * 100 + int(d.get("day", 1))


func _date_to_epoch_day(d: Dictionary) -> int:
	var unix_val: int = int(Time.get_unix_time_from_datetime_dict({
		"year": int(d.get("year", 2026)),
		"month": int(d.get("month", 1)),
		"day": int(d.get("day", 1)),
		"hour": 12,
		"minute": 0,
		"second": 0
	}))
	return int(unix_val / 86400)


func _parse_date_key(key: String) -> Dictionary:
	var parts: PackedStringArray = key.split("-")
	if parts.size() != 3:
		return {}
	return {
		"year": int(parts[0]),
		"month": int(parts[1]),
		"day": int(parts[2])
	}


func get_current_week_id() -> String:
	var d: Dictionary = get_today_dict()
	var epoch_day: int = _date_to_epoch_day(d)
	var week_index: int = int(floor(float(epoch_day + 3) / 7.0))
	return "W-%d" % week_index


func get_today_weekday_index() -> int:
	var d: Dictionary = get_today_dict()
	var wd: int = int(d.get("weekday", 1))
	if wd == 0:
		return 6
	return clampi(wd - 1, 0, 6)


func _sync_calendar_states() -> void:
	var changed: bool = false
	var cur_week: String = get_current_week_id()

	if weekly_key != cur_week:
		if weekly_key != "" and weekly_points > 0:
			var prev_rank: int = compute_player_rank_in_cohort(weekly_key, cohort_tier_index, weekly_points)
			if prev_rank <= 5 and cohort_tier_index < LEAGUE_TIERS.size() - 1:
				cohort_tier_index += 1
			elif prev_rank >= 13 and cohort_tier_index > 0:
				cohort_tier_index -= 1
		weekly_key = cur_week
		weekly_points = 0
		changed = true

	if mosaic_week_id != cur_week:
		mosaic_week_id = cur_week
		mosaic_week_days = [false, false, false, false, false, false, false]
		changed = true

	if last_daily_completed_key != "":
		var prev_dict: Dictionary = _parse_date_key(last_daily_completed_key)
		if not prev_dict.is_empty():
			var diff_days: int = _date_to_epoch_day(get_today_dict()) - _date_to_epoch_day(prev_dict)
			if diff_days > 1 and daily_streak > 0:
				daily_streak = 0
				changed = true

	var auto_tier: int = _tier_for_points(weekly_points)
	if auto_tier > cohort_tier_index:
		cohort_tier_index = auto_tier
		changed = true

	if changed:
		save_game()


func _tier_for_points(pts: int) -> int:
	var best: int = 0
	for i in range(LEAGUE_TIERS.size()):
		if pts >= int(LEAGUE_TIERS[i]["min_pts"]):
			best = i
	return best


func is_daily_completed_today() -> bool:
	return last_daily_completed_key == get_today_key()


func get_total_stars() -> int:
	var total: int = 0
	for k in stage_stars.keys():
		total += int(stage_stars[k])
	return total


func get_stage_stars(stage: int) -> int:
	return int(stage_stars.get(str(stage), 0))


func get_stage_best_score(stage: int) -> int:
	return int(stage_best_scores.get(str(stage), 0))


# --- EKONOMİ, NO ADS, GÜÇLENDİRİCİ VE TEMA API ---

func add_coins(amount: int, should_save: bool = true) -> void:
	if amount <= 0:
		return
	coins += amount
	if should_save:
		save_game()
		state_updated.emit()


## Gerçek mağaza IAP entegrasyonuna hazır No Ads satın alma fonksiyonu.
func purchase_no_ads() -> bool:
	if no_ads:
		return false
	no_ads = true
	save_game()
	state_updated.emit()
	return true


func get_booster_count(booster_id: String) -> int:
	return maxi(0, int(boosters.get(booster_id, 0)))


func buy_booster(booster_id: String) -> bool:
	if not BOOSTER_COSTS.has(booster_id):
		return false
	var cost: int = int(BOOSTER_COSTS[booster_id])
	if coins < cost:
		return false
	coins -= cost
	boosters[booster_id] = get_booster_count(booster_id) + 1
	save_game()
	state_updated.emit()
	return true


func consume_booster(booster_id: String) -> bool:
	var cur: int = get_booster_count(booster_id)
	if cur <= 0:
		return false
	boosters[booster_id] = cur - 1
	save_game()
	state_updated.emit()
	DailyQuests.report("booster", 1)
	return true


func grant_lowest_booster(cap: int = 9) -> String:
	var candidates: Array[String] = ["hammer", "rotate", "refresh"]
	var best_id: String = ""
	var min_val: int = cap
	for bid in candidates:
		var c: int = get_booster_count(bid)
		if c < min_val:
			min_val = c
			best_id = bid
	if best_id == "":
		return ""
	boosters[best_id] = mini(cap, get_booster_count(best_id) + 1)
	save_game()
	state_updated.emit()
	return best_id


func restore_booster_counts(hammer_cnt: int, rotate_cnt: int, refresh_cnt: int) -> void:
	boosters["hammer"] = maxi(0, hammer_cnt)
	boosters["rotate"] = maxi(0, rotate_cnt)
	boosters["refresh"] = maxi(0, refresh_cnt)
	save_game()
	state_updated.emit()


func is_theme_unlocked(theme_id: String) -> bool:
	return unlocked_themes.has(theme_id)


func unlock_and_equip_theme(theme_id: String, cost: int) -> bool:
	if is_theme_unlocked(theme_id):
		active_theme = theme_id
		save_game()
		state_updated.emit()
		return true
	if coins < cost:
		return false
	coins -= cost
	unlocked_themes.append(theme_id)
	active_theme = theme_id
	save_game()
	state_updated.emit()
	return true


# --- OYUN SONU KAYITLARI ---

func record_campaign_victory(stage: int, score: int, stars: int) -> Dictionary:
	_sync_calendar_states()
	var key: String = str(stage)
	var prev_stars: int = int(stage_stars.get(key, 0))
	var prev_best: int = int(stage_best_scores.get(key, 0))
	stage_stars[key] = maxi(prev_stars, clampi(stars, 1, 3))
	stage_best_scores[key] = maxi(prev_best, score)
	if stage >= unlocked_stage and stage < MAX_CAMPAIGN_STAGE:
		unlocked_stage = stage + 1

	var coin_gain: int = 25 + stars * 15
	coins += coin_gain
	var league_gain: int = maxi(40, int(round(float(score) * 0.25)) + stars * 35)
	add_weekly_points(league_gain, false)
	save_game()
	state_updated.emit()
	return {
		"league_gain": league_gain,
		"coin_gain": coin_gain,
		"new_best": score > prev_best,
		"stars_earned": clampi(stars, 1, 3)
	}


func record_daily_victory(score: int) -> Dictionary:
	_sync_calendar_states()
	var today_key: String = get_today_key()
	var already_done: bool = (last_daily_completed_key == today_key)

	if not already_done:
		if last_daily_completed_key != "":
			var prev_dict: Dictionary = _parse_date_key(last_daily_completed_key)
			var diff_days: int = _date_to_epoch_day(get_today_dict()) - _date_to_epoch_day(prev_dict)
			if diff_days == 1:
				daily_streak += 1
			else:
				daily_streak = 1
		else:
			daily_streak = 1
		last_daily_completed_key = today_key
		best_daily_streak = maxi(best_daily_streak, daily_streak)

	var wd_idx: int = get_today_weekday_index()
	if wd_idx >= 0 and wd_idx < mosaic_week_days.size():
		mosaic_week_days[wd_idx] = true

	var coin_gain: int = 80 if not already_done else 25
	coins += coin_gain
	var league_gain: int = maxi(80, int(round(float(score) * 0.35)) + (150 if not already_done else 30))
	add_weekly_points(league_gain, false)
	save_game()
	state_updated.emit()
	return {
		"league_gain": league_gain,
		"coin_gain": coin_gain,
		"streak": daily_streak,
		"first_clear_today": not already_done,
		"weekday_index": wd_idx
	}


## already_rewarded_score: Revive sonrası ikinci Game Over'da, ilk seferde ödülü
## verilmiş skor. Rekor tam skorla güncellenir ama altın/LP sadece yeni kısım için verilir.
func record_endless_run(score: int, is_special: bool = false, already_rewarded_score: int = 0) -> Dictionary:
	_sync_calendar_states()
	var is_record: bool = false
	if is_special:
		is_record = score > best_special_endless
		if is_record:
			best_special_endless = score
	else:
		is_record = score > best_normal_endless
		if is_record:
			best_normal_endless = score

	endless_high_score = maxi(best_normal_endless, best_special_endless)
	var reward_score: int = maxi(0, score - already_rewarded_score)
	var coin_gain: int = 0
	var league_gain: int = 0
	if already_rewarded_score <= 0:
		coin_gain = maxi(10, int(floor(float(reward_score) / 35.0)))
		league_gain = maxi(15, int(round(float(reward_score) * (0.28 if is_special else 0.22))))
	elif reward_score > 0:
		coin_gain = int(floor(float(reward_score) / 35.0))
		league_gain = int(round(float(reward_score) * (0.28 if is_special else 0.22)))
	coins += coin_gain
	add_weekly_points(league_gain, false)
	save_game()
	state_updated.emit()
	return {
		"league_gain": league_gain,
		"coin_gain": coin_gain,
		"new_best": is_record
	}


func record_failed_attempt_points(score: int, already_rewarded_score: int = 0) -> Dictionary:
	_sync_calendar_states()
	var reward_score: int = maxi(0, score - already_rewarded_score)
	if reward_score <= 0:
		return {"league_gain": 0, "coin_gain": 0}
	var first_time: bool = already_rewarded_score <= 0
	var coin_gain: int = int(floor(float(reward_score) / 60.0))
	var league_gain: int = int(round(float(reward_score) * 0.10))
	if first_time:
		coin_gain = maxi(5, coin_gain)
		league_gain = maxi(10, league_gain)
	coins += coin_gain
	add_weekly_points(league_gain, false)
	save_game()
	state_updated.emit()
	return {"league_gain": league_gain, "coin_gain": coin_gain}


func add_weekly_points(amount: int, should_save: bool = true) -> void:
	if amount <= 0:
		return
	weekly_points += amount
	var auto_tier: int = _tier_for_points(weekly_points)
	if auto_tier > cohort_tier_index:
		cohort_tier_index = auto_tier
	if should_save:
		save_game()
		state_updated.emit()


func get_current_league_info() -> Dictionary:
	return LEAGUE_TIERS[clampi(cohort_tier_index, 0, LEAGUE_TIERS.size() - 1)]


func get_cohort_standings(tier_idx: int = -1) -> Array[Dictionary]:
	_sync_calendar_states()
	var use_tier: int = cohort_tier_index if tier_idx < 0 else clampi(tier_idx, 0, LEAGUE_TIERS.size() - 1)
	var entries: Array[Dictionary] = _generate_simulated_rivals(weekly_key, use_tier)

	if use_tier == cohort_tier_index:
		entries.append({
			"member_id": "local_player",
			"name": player_callsign + " (Sen)",
			"points": weekly_points,
			"is_player": true,
			"badge_seed": 777
		})
	else:
		var extra_rng := RandomNumberGenerator.new()
		extra_rng.seed = int(abs(weekly_key.hash()) + use_tier * 9137 + 99)
		var tier_cfg: Dictionary = LEAGUE_TIERS[use_tier]
		entries.append({
			"member_id": "rival_extra",
			"name": "TapınakGezgini",
			"points": int(tier_cfg["rival_base"]) + extra_rng.randi_range(80, int(tier_cfg["rival_span"])),
			"is_player": false,
			"badge_seed": 512
		})

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["points"]) == int(b["points"]):
			return bool(a["is_player"]) and not bool(b["is_player"])
		return int(a["points"]) > int(b["points"])
	)

	for i in range(entries.size()):
		entries[i]["rank"] = i + 1
		entries[i]["zone"] = "promote" if (i + 1) <= 5 else ("demote" if (i + 1) >= 13 and use_tier > 0 else "safe")

	return entries


func compute_player_rank_in_cohort(week_id: String, tier_idx: int, pts: int) -> int:
	var rivals: Array[Dictionary] = _generate_simulated_rivals(week_id, tier_idx)
	var rank: int = 1
	for r in rivals:
		if int(r["points"]) > pts:
			rank += 1
	return rank


func _generate_simulated_rivals(week_id: String, tier_idx: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(abs(week_id.hash())) + (tier_idx + 1) * 7919
	var tier_cfg: Dictionary = LEAGUE_TIERS[clampi(tier_idx, 0, LEAGUE_TIERS.size() - 1)]
	var base_pts: int = int(tier_cfg["rival_base"])
	var span_pts: int = int(tier_cfg["rival_span"])
	var day_progress: float = clampf((float(get_today_weekday_index()) + 0.65) / 7.0, 0.15, 1.0)

	var pool: Array = RIVAL_NAMES.duplicate()
	var results: Array[Dictionary] = []
	for i in range(14):
		var pick_idx: int = rng.randi_range(0, pool.size() - 1)
		var r_name: String = str(pool[pick_idx])
		pool.remove_at(pick_idx)

		var skill_factor: float = pow(float(i + 1) / 14.0, 1.35)
		var raw_pts: float = (float(base_pts) + float(span_pts) * skill_factor) * day_progress
		var jitter: int = rng.randi_range(-65, 95)
		var final_pts: int = maxi(50, int(round(raw_pts)) + jitter)

		results.append({
			"member_id": "sim_%d_%d" % [tier_idx, i],
			"name": r_name,
			"points": final_pts,
			"is_player": false,
			"badge_seed": rng.randi_range(1, 999)
		})
	return results


func get_week_remaining_label() -> String:
	var wd: int = get_today_weekday_index()
	var days_left: int = maxi(0, 6 - wd)
	var t: Dictionary = Time.get_time_dict_from_system()
	var hours_left: int = maxi(0, 23 - int(t.get("hour", 12)))
	if days_left > 0:
		return "%dG %dS" % [days_left, hours_left]
	return "%dS" % maxi(1, hours_left)


func save_game() -> void:
	var payload: Dictionary = {
		"version": 2,
		"unlocked_stage": unlocked_stage,
		"stage_stars": stage_stars,
		"stage_best_scores": stage_best_scores,
		"best_normal_endless": best_normal_endless,
		"best_special_endless": best_special_endless,
		"endless_high_score": maxi(best_normal_endless, best_special_endless),
		"coins": coins,
		"no_ads": no_ads,
		"boosters": boosters,
		"unlocked_themes": unlocked_themes,
		"active_theme": active_theme,
		"sound_enabled": sound_enabled,
		"daily_streak": daily_streak,
		"best_daily_streak": best_daily_streak,
		"last_daily_completed_key": last_daily_completed_key,
		"mosaic_week_id": mosaic_week_id,
		"mosaic_week_days": mosaic_week_days,
		"weekly_key": weekly_key,
		"weekly_points": weekly_points,
		"cohort_tier_index": cohort_tier_index,
		"player_callsign": player_callsign
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))
		file.close()


func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed

	unlocked_stage = clampi(int(data.get("unlocked_stage", 1)), 1, MAX_CAMPAIGN_STAGE)
	var legacy_endless: int = maxi(0, int(data.get("endless_high_score", 0)))
	best_normal_endless = maxi(0, int(data.get("best_normal_endless", legacy_endless)))
	best_special_endless = maxi(0, int(data.get("best_special_endless", 0)))
	endless_high_score = maxi(best_normal_endless, best_special_endless)

	coins = maxi(0, int(data.get("coins", 300)))
	no_ads = bool(data.get("no_ads", false))

	var raw_boosters: Variant = data.get("boosters", {})
	if typeof(raw_boosters) == TYPE_DICTIONARY:
		boosters = {
			"hammer": maxi(0, int(raw_boosters.get("hammer", 2))),
			"rotate": maxi(0, int(raw_boosters.get("rotate", 2))),
			"refresh": maxi(0, int(raw_boosters.get("refresh", 2))),
			"bomb": maxi(0, int(raw_boosters.get("bomb", 1)))
		}

	unlocked_themes = ["emerald_temple"]
	var raw_themes: Variant = data.get("unlocked_themes", ["emerald_temple"])
	if typeof(raw_themes) == TYPE_ARRAY:
		for t in raw_themes:
			var ts: String = str(t)
			if ts != "" and not unlocked_themes.has(ts):
				unlocked_themes.append(ts)

	var saved_theme: String = str(data.get("active_theme", "emerald_temple"))
	active_theme = saved_theme if unlocked_themes.has(saved_theme) else "emerald_temple"

	sound_enabled = bool(data.get("sound_enabled", true))
	daily_streak = maxi(0, int(data.get("daily_streak", 0)))
	best_daily_streak = maxi(daily_streak, int(data.get("best_daily_streak", 0)))
	last_daily_completed_key = str(data.get("last_daily_completed_key", ""))
	mosaic_week_id = str(data.get("mosaic_week_id", ""))
	weekly_key = str(data.get("weekly_key", ""))
	weekly_points = maxi(0, int(data.get("weekly_points", 0)))
	cohort_tier_index = clampi(int(data.get("cohort_tier_index", 0)), 0, LEAGUE_TIERS.size() - 1)
	player_callsign = str(data.get("player_callsign", "Mistik Mimar"))

	stage_stars.clear()
	var raw_stars: Variant = data.get("stage_stars", {})
	if typeof(raw_stars) == TYPE_DICTIONARY:
		for k in raw_stars.keys():
			stage_stars[str(k)] = clampi(int(raw_stars[k]), 0, 3)

	stage_best_scores.clear()
	var raw_scores: Variant = data.get("stage_best_scores", {})
	if typeof(raw_scores) == TYPE_DICTIONARY:
		for k in raw_scores.keys():
			stage_best_scores[str(k)] = maxi(0, int(raw_scores[k]))

	var raw_days: Variant = data.get("mosaic_week_days", [])
	if typeof(raw_days) == TYPE_ARRAY and raw_days.size() == 7:
		mosaic_week_days = [
			bool(raw_days[0]), bool(raw_days[1]), bool(raw_days[2]),
			bool(raw_days[3]), bool(raw_days[4]), bool(raw_days[5]), bool(raw_days[6])
		]
