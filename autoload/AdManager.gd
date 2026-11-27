extends Node
## Reklam yöneticisi (yer tutucu). Gerçek reklam SDK'sı (AdMob, AppLovin vb.)
## eklendiğinde sadece _play_test_ad() değişir; oyunun geri kalanı aynı kalır.
##
## - Ödüllü reklam (rewarded): oyuncu kendi seçer, karşılığında ödül alır.
## - Geçiş reklamı (interstitial): oyun bitişlerinde, sıklık sınırıyla otomatik.
##   NO ADS alan oyuncuya gösterilmez. Her geçiş reklamından sonra Hediye Çarkı çıkar.
## - Günlük ödüllü reklam hakları (mağazada güçlendirici) günde sınırlıdır.

signal rewarded_ad_finished(placement: String, completed: bool)
signal interstitial_finished(placement: String)

const SAVE_PATH: String = "user://ads.json"
const TEST_AD_SECONDS: float = 1.5

## Geçiş reklamı sıklığı: en az bu kadar oyun bitişi VE bu kadar saniye geçmeli.
const INTERSTITIAL_EVERY_N_GAMES: int = 2
const INTERSTITIAL_MIN_SECONDS: int = 90
## İlk kez oynayan oyuncuyu ilk oyunlarda reklamla karşılama.
const INTERSTITIAL_GRACE_GAMES: int = 3

const DAILY_SHOP_REWARDED_LIMIT: int = 5

const GiftWheelScript := preload("res://scripts/GiftWheel.gd")

var _showing: bool = false
var _total_game_ends: int = 0
var _games_since_interstitial: int = 0
var _last_interstitial_unix: int = 0
var _daily_key: String = ""
var _daily_shop_rewarded_used: int = 0


func _ready() -> void:
	_load()


# --- ÖDÜLLÜ REKLAM ---

func is_rewarded_ready(_placement: String) -> bool:
	return not _showing


## Ödüllü reklam gösterir. Bittiğinde on_done.call(completed) çağrılır.
## completed == false ise oyuncu reklamı yarıda kapatmıştır; ödül verilmez.
func show_rewarded(placement: String, on_done: Callable) -> void:
	if _showing:
		return
	_showing = true
	await _play_test_ad("REKLAM (TEST)")
	_showing = false
	# Oyuncu zaten reklam izledi; hemen ardından geçiş reklamı göstermeyelim.
	_last_interstitial_unix = int(Time.get_unix_time_from_system())
	_save()
	rewarded_ad_finished.emit(placement, true)
	if on_done.is_valid():
		on_done.call(true)


# --- GÜNLÜK ÖDÜLLÜ HAKLAR ---

func get_shop_rewarded_left() -> int:
	_sync_day()
	return maxi(0, DAILY_SHOP_REWARDED_LIMIT - _daily_shop_rewarded_used)


func consume_shop_rewarded() -> void:
	_sync_day()
	_daily_shop_rewarded_used += 1
	_save()


# --- GEÇİŞ REKLAMI + HEDİYE ÇARKI ---

## Oyun bitiş ekranından ayrılırken (Tekrar / Ana Menü / Sonraki Bölüm) çağrılır.
## Sıklık uygunsa geçiş reklamı + Hediye Çarkı gösterir, sonra then_do çalışır.
## Uygun değilse then_do hemen çalışır.
func on_game_end_continue(then_do: Callable) -> void:
	_total_game_ends += 1
	# Tanışma döneminde sayaç birikmesin; ilk reklam ancak dönem bittikten sonra
	# INTERSTITIAL_EVERY_N_GAMES oyun sonra gelsin.
	_games_since_interstitial = 0 if _total_game_ends <= INTERSTITIAL_GRACE_GAMES else _games_since_interstitial + 1
	_save()
	if not _should_show_interstitial():
		then_do.call()
		return
	_showing = true
	await _play_test_ad("REKLAM (TEST)")
	_showing = false
	_games_since_interstitial = 0
	_last_interstitial_unix = int(Time.get_unix_time_from_system())
	_save()
	interstitial_finished.emit("game_end")
	_show_gift_wheel(then_do)


func _should_show_interstitial() -> bool:
	if GameState.no_ads or _showing:
		return false
	if _total_game_ends <= INTERSTITIAL_GRACE_GAMES:
		return false
	if _games_since_interstitial < INTERSTITIAL_EVERY_N_GAMES:
		return false
	var now: int = int(Time.get_unix_time_from_system())
	return now - _last_interstitial_unix >= INTERSTITIAL_MIN_SECONDS


func _show_gift_wheel(then_do: Callable) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 91
	var wheel: Control = GiftWheelScript.new()
	wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(wheel)
	get_tree().root.add_child(layer)
	wheel.closed.connect(func() -> void:
		layer.queue_free()
		then_do.call()
	)


# --- TEST REKLAM EKRANI ---

func _play_test_ad(text_val: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var lbl := Label.new()
	lbl.text = text_val
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_size_override("font_size", 40)
	bg.add_child(lbl)
	layer.add_child(bg)
	get_tree().root.add_child(layer)
	await get_tree().create_timer(TEST_AD_SECONDS).timeout
	layer.queue_free()


# --- KAYIT ---

func _sync_day() -> void:
	var today: String = GameState.get_today_key()
	if _daily_key != today:
		_daily_key = today
		_daily_shop_rewarded_used = 0
		_save()


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"total_game_ends": _total_game_ends,
		"games_since_interstitial": _games_since_interstitial,
		"last_interstitial_unix": _last_interstitial_unix,
		"daily_key": _daily_key,
		"daily_shop_rewarded_used": _daily_shop_rewarded_used
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
	var d: Dictionary = parsed
	_total_game_ends = int(d.get("total_game_ends", 0))
	_games_since_interstitial = int(d.get("games_since_interstitial", 0))
	_last_interstitial_unix = int(d.get("last_interstitial_unix", 0))
	_daily_key = str(d.get("daily_key", ""))
	_daily_shop_rewarded_used = int(d.get("daily_shop_rewarded_used", 0))
