extends Node
## Reklam yöneticisi (yer tutucu). Gerçek reklam SDK'sı (AdMob, AppLovin vb.)
## eklendiğinde sadece bu dosyanın içi değişir; oyunun geri kalanı aynı kalır.
##
## Şu an test modu: ödüllü reklam 1.5 saniyelik sahte bir ekran gösterir ve
## her zaman "izlendi" sayılır.

signal rewarded_ad_finished(placement: String, completed: bool)

const TEST_AD_SECONDS: float = 1.5

var _showing: bool = false


func is_rewarded_ready(_placement: String) -> bool:
	return not _showing


## Ödüllü reklam gösterir. Bittiğinde on_done.call(completed) çağrılır.
## completed == false ise oyuncu reklamı yarıda kapatmıştır; ödül verilmez.
func show_rewarded(placement: String, on_done: Callable) -> void:
	if _showing:
		return
	_showing = true

	var layer := CanvasLayer.new()
	layer.layer = 90
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var lbl := Label.new()
	lbl.text = "REKLAM (TEST)"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_size_override("font_size", 40)
	bg.add_child(lbl)
	layer.add_child(bg)
	get_tree().root.add_child(layer)

	await get_tree().create_timer(TEST_AD_SECONDS).timeout
	layer.queue_free()
	_showing = false
	rewarded_ad_finished.emit(placement, true)
	if on_done.is_valid():
		on_done.call(true)
