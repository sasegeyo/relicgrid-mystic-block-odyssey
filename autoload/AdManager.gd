extends Node
## Reklam yöneticisi (yer tutucu). Gerçek reklam SDK'sı (AdMob, AppLovin vb.)
## eklendiğinde sadece _play_test_ad() değişir; oyunun geri kalanı aynı kalır.
##
## - Ödüllü reklam (rewarded): oyuncu kendi seçer, karşılığında ödül alır.
## - Geçiş reklamı (interstitial): SABİT ARALIK YOK. "Reklam baskısı" sayacı oyun
##   içi olaylarla (aktif süre, biten tepsiler, temizlenen satırlar) dolar. Sayaç,
##   her seferinde rastgele seçilen ve oyuncuya göre ayarlanan eşiği geçince reklam
##   ilk uygun doğal arada çıkar (tepsi yenilenince ya da oyun bitince).
##   Eşiği belirleyenler:
##     * Oyuncunun kaç gündür oynadığı (yeni oyuncuya seyrek, eskiye daha sık)
##     * Bugün çok ödüllü reklam izlediyse daha seyrek
##     * Premium sezon kartı aldıysa daha seyrek; NO ADS aldıysa hiç
##     * Reklamdan hemen sonra oyunu kapatma (kaçma belirtisi) varsa geri çekilir
##   Korunan anlar: oyuncu ödüllü reklam teklifini REDDETTİĞİ an zorunlu reklam
##   çıkmaz; Rekor Bölgesi'nde ve büyük kombodan hemen sonra çıkmaz.
##   Her geçiş reklamından sonra Hediye Çarkı çıkar.
## - Günlük ödüllü reklam hakları (mağazada güçlendirici) günde sınırlıdır.

signal rewarded_ad_finished(placement: String, completed: bool)
signal interstitial_finished(placement: String)

const SAVE_PATH: String = "user://ads.json"
const TEST_AD_SECONDS: float = 1.5
const DAILY_SHOP_REWARDED_LIMIT: int = 5

# ---------------- AYAR TABLOSU (A/B testinde buradan oynanır) ----------------
## Baskı kaynakları
const PRESSURE_PER_SECOND: float = 1.0
const PRESSURE_PER_TRAY: float = 8.0
const PRESSURE_PER_LINE: float = 3.0
## Oyuncunun oynadığı gün sayısına göre temel eşik: [en az gün, eşik]
const BASE_THRESHOLDS: Array = [[0, 420.0], [2, 340.0], [4, 290.0], [8, 250.0]]
## Her reklamda eşik bu aralıkta rastgele çarpılır (oyuncu düzen fark etmesin).
const THRESHOLD_JITTER_MIN: float = 0.75
const THRESHOLD_JITTER_MAX: float = 1.35
## Bugün bu kadar ödüllü reklam izleyene eşik çarpanı.
const HEAVY_REWARDED_COUNT: int = 3
const HEAVY_REWARDED_MULT: float = 1.25
## Premium sezon kartı sahibine eşik çarpanı.
const PREMIUM_MULT: float = 1.5
## Kaçma belirtisi: reklamdan sonra bu kadar saniye içinde oyunu kapatırsa geri çekil.
const QUICK_QUIT_SECONDS: float = 20.0
const BACKOFF_STEP: float = 0.35
const BACKOFF_MAX_LEVEL: int = 3
## Reklamdan sonra bu kadar oynarsa geri çekilme bir kademe azalır.
const BACKOFF_RECOVER_SECONDS: float = 120.0
## Güvenlik sınırları (sabit aralık değil, sadece alt sınırlar)
const NEW_PLAYER_SECONDS: float = 300.0     # ilk kez oynayana ilk 5 dk reklam yok
const SESSION_WARMUP_SECONDS: float = 60.0  # her oturumda ilk 1 dk reklam yok
const MIN_GAP_SECONDS: float = 75.0         # iki reklam arası en az (aktif oyun)
const AFTER_DECLINE_SECONDS: float = 45.0   # ödüllü teklif reddedilince en az bu kadar oyun
# ------------------------------------------------------------------------------

const GiftWheelScript := preload("res://scripts/GiftWheel.gd")

var _rng := RandomNumberGenerator.new()
var _showing: bool = false

var _pressure: float = 0.0
var _jitter: float = 0.0
var _total_play_seconds: float = 0.0
var _session_play_seconds: float = 0.0
var _play_seconds_since_ad: float = 99999.0
var _play_seconds_since_decline: float = 99999.0
var _unsaved_play_seconds: float = 0.0

var _days_played: int = 0
var _last_play_day: String = ""
var _backoff_level: int = 0
var _watching_for_quick_quit: bool = false
var _recover_pending: bool = false

var _daily_key: String = ""
var _daily_shop_rewarded_used: int = 0
var _rewarded_today: int = 0


func _ready() -> void:
	_rng.randomize()
	_load()
	if _jitter <= 0.0:
		_roll_jitter()


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
	# Oyuncu zaten reklam izledi; baskı sıfırlanır, hemen ardından geçiş reklamı gelmez.
	_sync_day()
	_rewarded_today += 1
	_pressure = 0.0
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


# --- GEÇİŞ REKLAMI: BASKI SAYACI ---

## Oyun ekranı aktif oynanan süreyi buraya bildirir (her karede delta).
func add_play_time(delta: float) -> void:
	if _showing:
		return
	_sync_day()
	_total_play_seconds += delta
	_session_play_seconds += delta
	_play_seconds_since_ad += delta
	_play_seconds_since_decline += delta
	_pressure += delta * PRESSURE_PER_SECOND
	if _watching_for_quick_quit and _play_seconds_since_ad > QUICK_QUIT_SECONDS:
		_watching_for_quick_quit = false
	if _recover_pending and _play_seconds_since_ad >= BACKOFF_RECOVER_SECONDS:
		_recover_pending = false
		_backoff_level = maxi(0, _backoff_level - 1)
	_unsaved_play_seconds += delta
	if _unsaved_play_seconds >= 15.0:
		_save()


## Tepsideki parçalar bitti (bir tur tamamlandı).
func note_tray_finished() -> void:
	_pressure += PRESSURE_PER_TRAY


func note_lines_cleared(lines: int) -> void:
	if lines > 0:
		_pressure += PRESSURE_PER_LINE * float(lines)


## Oyuncu uygulamayı kapattı / arka plana aldı. Reklamdan hemen sonraysa kaçma belirtisi.
func note_session_interrupted() -> void:
	if _watching_for_quick_quit and _play_seconds_since_ad <= QUICK_QUIT_SECONDS:
		_backoff_level = mini(BACKOFF_MAX_LEVEL, _backoff_level + 1)
		_recover_pending = false
	_watching_for_quick_quit = false
	_session_play_seconds = 0.0
	_save()


func is_showing() -> bool:
	return _showing


## Şu anki eşik (oyuncuya göre ayarlanmış + rastgele).
func get_current_threshold() -> float:
	var base: float = float(BASE_THRESHOLDS[0][1])
	for row in BASE_THRESHOLDS:
		if _days_played >= int(row[0]):
			base = float(row[1])
	var mult: float = _jitter
	if _rewarded_today >= HEAVY_REWARDED_COUNT:
		mult *= HEAVY_REWARDED_MULT
	if BattlePass.premium:
		mult *= PREMIUM_MULT
	mult *= 1.0 + BACKOFF_STEP * float(_backoff_level)
	return base * mult


# --- GEÇİŞ REKLAMI: GÖSTERİM NOKTALARI ---

## Oyun içi doğal ara (tepsi yenilendi). protected_moment: Rekor Bölgesi ya da
## büyük kombo gibi oyuncunun keyif aldığı an; o zaman reklam bir sonraki araya kalır.
## Reklam gösterildiyse true döner; then_do çark kapanınca çalışır.
func try_mid_game_break(then_do: Callable, protected_moment: bool = false) -> bool:
	if protected_moment or not _should_show_interstitial():
		return false
	_run_interstitial("mid_game", then_do)
	return true


## Oyun sonu ekranından ayrılırken (Tekrar / Ana Menü / Sonraki Bölüm) çağrılır.
## declined_rewarded: oyuncu o ekranda ödüllü reklam teklifini (devam et, 2x altın)
## geri çevirdiyse true. O zaman zorunlu reklam GÖSTERİLMEZ; baskı bir sonraki
## oyunun doğal arasına devreder.
func on_game_end_continue(then_do: Callable, declined_rewarded: bool = false) -> void:
	if declined_rewarded:
		_play_seconds_since_decline = 0.0
	if not _should_show_interstitial():
		_save()
		then_do.call()
		return
	_run_interstitial("game_end", then_do)


func _run_interstitial(placement: String, then_do: Callable) -> void:
	# _showing çark kapanana kadar açık kalır: o sırada oynama süresi sayılmaz.
	_showing = true
	await _play_test_ad("REKLAM (TEST)")
	_pressure = 0.0
	_play_seconds_since_ad = 0.0
	_watching_for_quick_quit = true
	_recover_pending = _backoff_level > 0
	_roll_jitter()
	_save()
	interstitial_finished.emit(placement)
	_show_gift_wheel(then_do)


func _should_show_interstitial() -> bool:
	if GameState.no_ads or _showing:
		return false
	if _total_play_seconds < NEW_PLAYER_SECONDS:
		return false
	if _session_play_seconds < SESSION_WARMUP_SECONDS:
		return false
	if _play_seconds_since_ad < MIN_GAP_SECONDS:
		return false
	if _play_seconds_since_decline < AFTER_DECLINE_SECONDS:
		return false
	return _pressure >= get_current_threshold()


func _roll_jitter() -> void:
	_jitter = _rng.randf_range(THRESHOLD_JITTER_MIN, THRESHOLD_JITTER_MAX)


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
		_rewarded_today = 0
		_save()
	if _last_play_day != today and _total_play_seconds > 0.0:
		_last_play_day = today
		_days_played += 1


func _save() -> void:
	_unsaved_play_seconds = 0.0
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"pressure": _pressure,
		"jitter": _jitter,
		"total_play_seconds": _total_play_seconds,
		"play_seconds_since_ad": _play_seconds_since_ad,
		"days_played": _days_played,
		"last_play_day": _last_play_day,
		"backoff_level": _backoff_level,
		"daily_key": _daily_key,
		"daily_shop_rewarded_used": _daily_shop_rewarded_used,
		"rewarded_today": _rewarded_today
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
	_pressure = float(d.get("pressure", 0.0))
	_jitter = float(d.get("jitter", 0.0))
	_total_play_seconds = float(d.get("total_play_seconds", 0.0))
	_play_seconds_since_ad = float(d.get("play_seconds_since_ad", 99999.0))
	_days_played = int(d.get("days_played", 0))
	_last_play_day = str(d.get("last_play_day", ""))
	_backoff_level = int(d.get("backoff_level", 0))
	_daily_key = str(d.get("daily_key", ""))
	_daily_shop_rewarded_used = int(d.get("daily_shop_rewarded_used", 0))
	_rewarded_today = int(d.get("rewarded_today", 0))
