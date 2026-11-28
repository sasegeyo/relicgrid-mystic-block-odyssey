extends Node
## Günlük Görevler: her gün 3 görev (gün anahtarına göre seçilir, herkes için aynı
## gün aynı görevler). Görev bitince oyuncu ödülünü "AL" ile alır: sezon XP'si +
## altın. Üçü de alınınca bonus güçlendirici.
##
## Oyun ilerlemeyi report(...) ile bildirir; reklam izleme görevi YOKTUR.

signal quests_updated
signal quest_completed(text: String)

const SAVE_PATH: String = "user://daily_quests.json"
const QUESTS_PER_DAY: int = 3

## type: ilerleme türü. targets: [kolay, orta, zor]. text: %d hedefle doldurulur.
## max_type: true ise ilerleme toplanmaz, tek oyundaki en iyi değer alınır.
const POOL: Array = [
	{"type": "games", "text": "%d oyun bitir", "targets": [2, 3, 5], "xp": [60, 90, 140], "coins": [20, 30, 50]},
	{"type": "score_game", "text": "Tek oyunda %d puan yap", "targets": [800, 1500, 2500], "xp": [70, 110, 160], "coins": [25, 40, 60], "max_type": true},
	{"type": "lines", "text": "%d satır temizle", "targets": [15, 30, 50], "xp": [60, 100, 150], "coins": [20, 35, 55]},
	{"type": "combo", "text": "%d kez aynı anda 2+ satır temizle", "targets": [2, 4, 7], "xp": [70, 110, 160], "coins": [25, 40, 60]},
	{"type": "booster", "text": "%d güçlendirici kullan", "targets": [1, 2, 3], "xp": [50, 80, 110], "coins": [15, 25, 35]},
	{"type": "stage_win", "text": "%d kampanya bölümü geç", "targets": [1, 2, 3], "xp": [70, 110, 150], "coins": [25, 40, 55]},
	{"type": "daily", "text": "Günlük oyunu tamamla", "targets": [1, 1, 1], "xp": [90, 90, 90], "coins": [30, 30, 30]},
]
## Üç görevin hepsi alınınca verilen bonus.
const ALL_DONE_BONUS: Dictionary = {"booster": "bomb", "amount": 1}

var day_key: String = ""
var quests: Array = []   # [{type, text, target, progress, xp, coins, claimed}]
var bonus_claimed: bool = false


func _ready() -> void:
	_load()
	_sync_day()


# --- OKUMA ---

func get_quests() -> Array:
	_sync_day()
	return quests


func is_done(i: int) -> bool:
	return int(quests[i]["progress"]) >= int(quests[i]["target"])


func get_claimable_count() -> int:
	_sync_day()
	var n: int = 0
	for i in range(quests.size()):
		if is_done(i) and not bool(quests[i]["claimed"]):
			n += 1
	if can_claim_bonus():
		n += 1
	return n


func all_claimed() -> bool:
	for q in quests:
		if not bool(q["claimed"]):
			return false
	return quests.size() > 0


func can_claim_bonus() -> bool:
	return all_claimed() and not bonus_claimed


## Yenilenmeye kalan süre ("5 sa 12 dk").
func get_time_left_label() -> String:
	var t: Dictionary = Time.get_datetime_dict_from_system()
	var left: int = 86400 - (int(t["hour"]) * 3600 + int(t["minute"]) * 60 + int(t["second"]))
	return "%d sa %d dk" % [left / 3600, (left % 3600) / 60]


# --- İLERLEME ---

## Oyundan ilerleme bildirimi. score_game gibi max_type görevlerde amount o
## oyundaki değerdir; diğerlerinde eklenecek miktardır.
func report(type: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	_sync_day()
	var changed: bool = false
	for q in quests:
		if str(q["type"]) != type or bool(q["claimed"]):
			continue
		var was_done: bool = int(q["progress"]) >= int(q["target"])
		if was_done:
			continue
		if bool(q.get("max_type", false)):
			q["progress"] = maxi(int(q["progress"]), amount)
		else:
			q["progress"] = int(q["progress"]) + amount
		q["progress"] = mini(int(q["progress"]), int(q["target"]))
		changed = true
		if int(q["progress"]) >= int(q["target"]):
			quest_completed.emit(str(q["text"]))
	if changed:
		_save()
		quests_updated.emit()


# --- ÖDÜL ---

func claim(i: int) -> bool:
	_sync_day()
	if i < 0 or i >= quests.size() or not is_done(i) or bool(quests[i]["claimed"]):
		return false
	var q: Dictionary = quests[i]
	q["claimed"] = true
	BattlePass.add_bonus_xp(int(q["xp"]))
	GameState.add_coins(int(q["coins"]), true)
	_save()
	quests_updated.emit()
	return true


func claim_bonus() -> bool:
	if not can_claim_bonus():
		return false
	bonus_claimed = true
	var bid: String = str(ALL_DONE_BONUS["booster"])
	GameState.boosters[bid] = GameState.get_booster_count(bid) + int(ALL_DONE_BONUS["amount"])
	GameState.save_game()
	GameState.state_updated.emit()
	_save()
	quests_updated.emit()
	return true


# --- GÜN DEĞİŞİMİ ---

func _sync_day() -> void:
	var today: String = GameState.get_today_key()
	if day_key == today and quests.size() == QUESTS_PER_DAY:
		return
	day_key = today
	bonus_claimed = false
	quests = _generate_for_day(today)
	_save()
	quests_updated.emit()


## Gün anahtarından tohumlu seçim: aynı gün herkese aynı 3 görev, zorluk sırayla
## kolay / orta / zor. Günlük oyun görevi en fazla bir kez gelir.
func _generate_for_day(key: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("relicgrid-quests-" + key)
	var idx: Array = []
	for i in range(POOL.size()):
		idx.append(i)
	# Fisher-Yates
	for i in range(idx.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = idx[i]
		idx[i] = idx[j]
		idx[j] = tmp
	var out: Array = []
	for k in range(QUESTS_PER_DAY):
		var p: Dictionary = POOL[idx[k]]
		var tier: int = k  # 0 kolay, 1 orta, 2 zor
		var target: int = int(p["targets"][tier])
		var text: String = str(p["text"])
		if text.contains("%d"):
			text = text % target
		out.append({
			"type": str(p["type"]),
			"text": text,
			"target": target,
			"progress": 0,
			"xp": int(p["xp"][tier]),
			"coins": int(p["coins"][tier]),
			"claimed": false,
			"max_type": bool(p.get("max_type", false)),
		})
	return out


# --- KAYIT ---

func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"day_key": day_key, "quests": quests, "bonus_claimed": bonus_claimed}, "\t"))
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
	var d: Dictionary = parsed
	day_key = str(d.get("day_key", ""))
	bonus_claimed = bool(d.get("bonus_claimed", false))
	quests = []
	var raw: Variant = d.get("quests", [])
	if typeof(raw) == TYPE_ARRAY:
		for q in raw:
			if typeof(q) == TYPE_DICTIONARY:
				var qd: Dictionary = q
				qd["target"] = int(qd.get("target", 1))
				qd["progress"] = int(qd.get("progress", 0))
				qd["xp"] = int(qd.get("xp", 0))
				qd["coins"] = int(qd.get("coins", 0))
				quests.append(qd)
