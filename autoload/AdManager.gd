extends Node
## Reklam yöneticisi (yer tutucu). Gerçek reklam SDK'sı (AdMob, AppLovin vb.)
## eklendiğinde sadece _play_test_ad() değişir; oyunun geri kalanı aynı kalır.
##
## - Ödüllü reklam (rewarded): oyuncu kendi seçer, karşılığında ödül alır.
## - Geçiş reklamı (interstitial): OYNAMA SÜRESİNE göre. Oyunlar uzun sürebildiği için
##   (40+ dk) oyun sayısına değil, aktif oynanan süreye bakılır. Süre dolunca reklam
##   ilk doğal arada çıkar: tepsideki 3 parça bitip yenisi gelince ya da oyun bitince.
##   NO ADS alan oyuncuya gösterilmez. Her geçiş reklamından sonra Hediye Çarkı çıkar.
## - Günlük ödüllü reklam hakları (mağazada güçlendirici) günde sınırlıdır.

signal rewarded_ad_finished(placement: String, completed: bool)
signal interstitial_finished(placement: String)

const SAVE_PATH: String = "user://ads.json"
const TEST_AD_SECONDS: float = 1.5

## Geçiş reklamı sıklığı: bu kadar saniye AKTİF oynandıktan sonra (duraklatma,
## menüler ve reklam süresi sayılmaz) ilk doğal arada reklam çıkar.
const INTERSTITIAL_PLAY_SECONDS: float = 180.0
## Yeni oyuncu: ilk reklam ancak toplamda bu kadar oynadıktan sonra.
const INTERSTITIAL_NEW_PLAYER_SECONDS: float = 300.0

const DAILY_SHOP_REWARDED_LIMIT: int = 5

const GiftWheelScript := preload("res://scripts/GiftWheel.gd")

var _showing: bool = false
var _total_play_seconds: float = 0.0
var _play_seconds_since_ad: float = 0.0
var _unsaved_play_seconds: float = 0.0
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
	# Oyuncu zaten reklam izledi; sayaç sıfırlanır, hemen ardından geçiş reklamı gelmez.
	_play_seconds_since_ad = 0.0
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

## Oyun ekranı aktif oynanan süreyi buraya bildirir (her karede delta).
func add_play_time(delta: float) -> void:
	if _showing:
		return
	_total_play_seconds += delta
	_play_seconds_since_ad += delta
	_unsaved_play_seconds += delta
	if _unsaved_play_seconds >= 15.0:
		_save()


func is_showing() -> bool:
	return _showing


## Oyun içi doğal ara (tepsi yenilendi): süre dolduysa reklam + çark, sonra then_do.
## Reklam gösterildiyse true döner.
func try_mid_game_break(then_do: Callable) -> bool:
	if not _should_show_interstitial():
		return false
	_run_interstitial("mid_game", then_do)
	return true


## Oyun bitiş ekranından ayrılırken (Tekrar / Ana Menü / Sonraki Bölüm) çağrılır.
## Süre dolduysa geçiş reklamı + Hediye Çarkı gösterir, sonra then_do çalışır.
func on_game_end_continue(then_do: Callable) -> void:
	if not _should_show_interstitial():
		_save()
		then_do.call()
		return
	_run_interstitial("game_end", then_do)


func _run_interstitial(placement: String, then_do: Callable) -> void:
	# _showing çark kapanana kadar açık kalır: o sırada oynama süresi sayılmaz.
	_showing = true
	await _play_test_ad("REKLAM (TEST)")
	_play_seconds_since_ad = 0.0
	_save()
	interstitial_finished.emit(placement)
	_show_gift_wheel(then_do)


func _should_show_interstitial() -> bool:
	if GameState.no_ads or _showing:
		return false
	if _total_play_seconds < INTERSTITIAL_NEW_PLAYER_SECONDS:
		return false
	return _play_seconds_since_ad >= INTERSTITIAL_PLAY_SECONDS


func _show_gift_wheel(then_do: Callable) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 91
	var wheel: Control = GiftWheelScript.new()
	wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(wheel)
	get_tree().root.add_child(layer)
	wheel.closed.connect(func() -> void:
		layer.queue_free()
		_showing = false
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
	_unsaved_play_seconds = 0.0
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"total_play_seconds": _total_play_seconds,
		"play_seconds_since_ad": _play_seconds_since_ad,
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
	_total_play_seconds = float(d.get("total_play_seconds", 0.0))
	_play_seconds_since_ad = float(d.get("play_seconds_since_ad", 0.0))
	_daily_key = str(d.get("daily_key", ""))
	_daily_shop_rewarded_used = int(d.get("daily_shop_rewarded_used", 0))
