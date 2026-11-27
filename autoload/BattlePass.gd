extends Node
## Sezonluk Battle Pass: 28 günlük sezonlar, 30 kademe, Ücretsiz + Premium ödül yolu.
## Oyun bitince XP kazanılır; kademe ödülleri Sezon ekranından elle toplanır.
## Kayıt: user://battle_pass.json (sezon değişince ilerleme sıfırlanır).

signal pass_updated

const SAVE_PATH: String = "user://battle_pass.json"
const SEASON_LENGTH_DAYS: int = 28
const TIER_COUNT: int = 30
const XP_PER_TIER: int = 300

## Ödül tipleri: "coins" (amount), "booster" (id, amount), "theme" (id)
const FREE_REWARDS: Dictionary = {
	5: {"type": "booster", "id": "hammer", "amount": 1},
	10: {"type": "booster", "id": "refresh", "amount": 1},
	15: {"type": "booster", "id": "rotate", "amount": 1},
	20: {"type": "booster", "id": "bomb", "amount": 1},
	25: {"type": "booster", "id": "hammer", "amount": 2},
	30: {"type": "coins", "amount": 500}
}
const PREMIUM_REWARDS: Dictionary = {
	3: {"type": "booster", "id": "bomb", "amount": 1},
	6: {"type": "booster", "id": "hammer", "amount": 2},
	9: {"type": "booster", "id": "rotate", "amount": 2},
	12: {"type": "booster", "id": "refresh", "amount": 2},
	15: {"type": "theme", "id": "obsidian_gold"},
	18: {"type": "booster", "id": "bomb", "amount": 2},
	21: {"type": "booster", "id": "hammer", "amount": 3},
	24: {"type": "booster", "id": "rotate", "amount": 3},
	27: {"type": "booster", "id": "bomb", "amount": 3},
	30: {"type": "theme", "id": "glacier_rune"}
}

var season_id: int = -1
var xp: int = 0
var premium: bool = false
var claimed_free: Array = []
var claimed_premium: Array = []


func _ready() -> void:
	_load()
	_sync_season()


# --- SEZON ---

func get_current_season_id() -> int:
	var unix_now: int = int(Time.get_unix_time_from_system())
	return int(unix_now / 86400) / SEASON_LENGTH_DAYS


func get_days_left() -> int:
	var unix_now: int = int(Time.get_unix_time_from_system())
	var day_index: int = int(unix_now / 86400)
	return SEASON_LENGTH_DAYS - (day_index % SEASON_LENGTH_DAYS)


func _sync_season() -> void:
	var cur: int = get_current_season_id()
	if season_id == cur:
		return
	season_id = cur
	xp = 0
	premium = false
	claimed_free = []
	claimed_premium = []
	_save()


# --- İLERLEME ---

func get_tier() -> int:
	return mini(TIER_COUNT, int(xp / XP_PER_TIER))


func get_xp_into_tier() -> int:
	if get_tier() >= TIER_COUNT:
		return XP_PER_TIER
	return xp % XP_PER_TIER


## Oyun sonunda çağrılır. Döndürdüğü değer: kazanılan XP.
## reward_score: bu oyunun ödüllendirilecek skoru (revive sonrası sadece yeni kısım).
func award_game_xp(reward_score: int, won: bool, stars: int = 0, first_daily: bool = false) -> int:
	_sync_season()
	if reward_score <= 0 and not won:
		return 0
	var gained: int = clampi(int(reward_score / 20), 0, 200)
	if won:
		gained += 80 + clampi(stars, 0, 3) * 25
	if first_daily:
		gained += 150
	gained = maxi(gained, 10)
	var before_tier: int = get_tier()
	xp = mini(xp + gained, TIER_COUNT * XP_PER_TIER)
	_save()
	pass_updated.emit()
	if get_tier() > before_tier:
		AudioManager.play_new_best()
	return gained


# --- ÖDÜLLER ---

## Ücretsiz yolda özel ödül tanımlı olmayan kademeler artan altın verir.
func get_reward(tier: int, is_premium_track: bool) -> Dictionary:
	if is_premium_track:
		if PREMIUM_REWARDS.has(tier):
			return PREMIUM_REWARDS[tier]
		return {"type": "coins", "amount": 60 + tier * 5}
	if FREE_REWARDS.has(tier):
		return FREE_REWARDS[tier]
	return {"type": "coins", "amount": 30 + tier * 3}


func is_claimed(tier: int, is_premium_track: bool) -> bool:
	return (claimed_premium if is_premium_track else claimed_free).has(tier)


func can_claim(tier: int, is_premium_track: bool) -> bool:
	if tier < 1 or tier > get_tier():
		return false
	if is_premium_track and not premium:
		return false
	return not is_claimed(tier, is_premium_track)


func claim(tier: int, is_premium_track: bool) -> bool:
	_sync_season()
	if not can_claim(tier, is_premium_track):
		return false
	_grant(get_reward(tier, is_premium_track))
	if is_premium_track:
		claimed_premium.append(tier)
	else:
		claimed_free.append(tier)
	_save()
	pass_updated.emit()
	return true


func get_claimable_count() -> int:
	var n: int = 0
	for t in range(1, get_tier() + 1):
		if can_claim(t, false):
			n += 1
		if can_claim(t, true):
			n += 1
	return n


func _grant(reward: Dictionary) -> void:
	match str(reward.get("type", "")):
		"coins":
			GameState.add_coins(int(reward.get("amount", 0)), true)
		"booster":
			var bid: String = str(reward.get("id", ""))
			GameState.boosters[bid] = GameState.get_booster_count(bid) + int(reward.get("amount", 1))
			GameState.save_game()
			GameState.state_updated.emit()
		"theme":
			var tid: String = str(reward.get("id", ""))
			if not GameState.is_theme_unlocked(tid):
				GameState.unlocked_themes.append(tid)
				GameState.save_game()
				GameState.state_updated.emit()


## Gerçek mağaza IAP entegrasyonuna hazır Premium Pass satın alma (şimdilik ücretsiz test).
func purchase_premium() -> bool:
	_sync_season()
	if premium:
		return false
	premium = true
	_save()
	pass_updated.emit()
	return true


# --- KAYIT ---

func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"season_id": season_id,
		"xp": xp,
		"premium": premium,
		"claimed_free": claimed_free,
		"claimed_premium": claimed_premium
	}, "\t"))
	file.close()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	season_id = int(data.get("season_id", -1))
	xp = maxi(0, int(data.get("xp", 0)))
	premium = bool(data.get("premium", false))
	claimed_free = []
	for t in data.get("claimed_free", []):
		claimed_free.append(int(t))
	claimed_premium = []
	for t in data.get("claimed_premium", []):
		claimed_premium.append(int(t))
