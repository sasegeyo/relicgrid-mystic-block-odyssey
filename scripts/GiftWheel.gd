extends Control
## Hediye Çarkı: geçiş reklamından sonra çıkar. Oyuncu ÇEVİR'e basar, çark döner,
## okun gösterdiği ödül verilir. Sonuç dönmeden önce ağırlıklı rastgele seçilir ve
## çark tam o dilimde durur: ekranda görülen = verilen.

signal closed

const SEGMENTS: Array = [
	{"type": "coins", "amount": 25, "label": "🪙 25", "weight": 22, "color": Color("#1F5C46")},
	{"type": "booster", "id": "hammer", "amount": 1, "label": "🔨", "weight": 14, "color": Color("#6B4A1A")},
	{"type": "coins", "amount": 50, "label": "🪙 50", "weight": 18, "color": Color("#245E6B")},
	{"type": "booster", "id": "rotate", "amount": 1, "label": "⟳", "weight": 12, "color": Color("#4B2A6B")},
	{"type": "coins", "amount": 100, "label": "🪙 100", "weight": 10, "color": Color("#1F5C46")},
	{"type": "booster", "id": "refresh", "amount": 1, "label": "🔄", "weight": 14, "color": Color("#6B4A1A")},
	{"type": "booster", "id": "bomb", "amount": 1, "label": "💣", "weight": 6, "color": Color("#6B1F2A")},
	{"type": "coins", "amount": 250, "label": "🪙 250", "weight": 4, "color": Color("#8A6A12")}
]

var _wheel: Control
var _spin_btn: Button
var _title_lbl: Label
var _result_lbl: Label
var _rng := RandomNumberGenerator.new()
var _spun: bool = false
var _won_index: int = -1


func _ready() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.04, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 22)
	center.add_child(vb)

	_title_lbl = ThemeManager.make_label("🎁 HEDİYE ÇARKI", 34, "gold_light", true)
	vb.add_child(_title_lbl)

	var wheel_holder := Control.new()
	wheel_holder.custom_minimum_size = Vector2(440, 470)
	vb.add_child(wheel_holder)

	_wheel = Control.new()
	_wheel.size = Vector2(440, 440)
	_wheel.position = Vector2(0, 30)
	_wheel.pivot_offset = _wheel.size * 0.5
	_wheel.draw.connect(_draw_wheel)
	wheel_holder.add_child(_wheel)

	var pointer := Control.new()
	pointer.size = Vector2(440, 40)
	pointer.draw.connect(func() -> void:
		var cx: float = pointer.size.x * 0.5
		pointer.draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 20, 0), Vector2(cx + 20, 0), Vector2(cx, 44)
		]), Color("#FDE68A"))
		pointer.draw_polyline(PackedVector2Array([
			Vector2(cx - 20, 0), Vector2(cx + 20, 0), Vector2(cx, 44), Vector2(cx - 20, 0)
		]), Color("#06100C"), 3.0, true)
	)
	wheel_holder.add_child(pointer)

	_result_lbl = ThemeManager.make_label("Reklam için teşekkürler! Çarkı çevir.", 20, "text_main", true)
	vb.add_child(_result_lbl)

	_spin_btn = ThemeManager.make_button("ÇEVİR!", 26, "amber_solid")
	_spin_btn.custom_minimum_size = Vector2(320, 68)
	_spin_btn.pressed.connect(_on_button)
	vb.add_child(_spin_btn)


func _on_button() -> void:
	if not _spun:
		_spin()
	else:
		AudioManager.play_ui_click()
		closed.emit()


func _pick_weighted_index() -> int:
	var total: int = 0
	for s in SEGMENTS:
		total += int(s["weight"])
	var roll: int = _rng.randi_range(1, total)
	var acc: int = 0
	for i in range(SEGMENTS.size()):
		acc += int(SEGMENTS[i]["weight"])
		if roll <= acc:
			return i
	return 0


func _spin() -> void:
	_spun = true
	_spin_btn.disabled = true
	_won_index = _pick_weighted_index()
	AudioManager.play_pickup()

	# Dilim i, açısı [i*step, (i+1)*step] aralığında, 0 açı = yukarı (ok) yönü.
	# Çarkı döndürünce dilimin ortası oka gelmeli: rotation = -(i + 0.5) * step
	var step: float = TAU / float(SEGMENTS.size())
	var jitter: float = _rng.randf_range(-0.32, 0.32) * step
	var target: float = TAU * 5.0 - (float(_won_index) + 0.5) * step + jitter

	var tw := create_tween()
	tw.tween_property(_wheel, "rotation", target, 3.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_finish_spin)


func _finish_spin() -> void:
	var seg: Dictionary = SEGMENTS[_won_index]
	_grant(seg)
	AudioManager.play_new_best()
	JuicyEffectsManager.burst_at(get_global_transform() * (size * 0.5), Color("#FDE68A"), 24)
	_title_lbl.text = "KAZANDIN!"
	_result_lbl.text = _describe(seg)
	_spin_btn.text = "AL"
	_spin_btn.disabled = false


func _grant(seg: Dictionary) -> void:
	match str(seg["type"]):
		"coins":
			GameState.add_coins(int(seg["amount"]), true)
		"booster":
			var bid: String = str(seg["id"])
			GameState.boosters[bid] = GameState.get_booster_count(bid) + int(seg["amount"])
			GameState.save_game()
			GameState.state_updated.emit()


func _describe(seg: Dictionary) -> String:
	if str(seg["type"]) == "coins":
		return "+%d Altın" % int(seg["amount"])
	var names: Dictionary = {"hammer": "Çekiç", "rotate": "Döndür", "refresh": "Yenile", "bomb": "Bomba"}
	return "+%d %s" % [int(seg["amount"]), str(names.get(str(seg["id"]), "Güçlendirici"))]


func _draw_wheel() -> void:
	var c: Vector2 = _wheel.size * 0.5
	var radius: float = _wheel.size.x * 0.5 - 6.0
	var step: float = TAU / float(SEGMENTS.size())
	var font: Font = ThemeDB.fallback_font

	_wheel.draw_circle(c, radius + 6.0, Color("#F59E0B"))
	for i in range(SEGMENTS.size()):
		# 0 açı yukarı bakacak şekilde (-PI/2 kaydırma)
		var a0: float = float(i) * step - PI * 0.5
		var a1: float = a0 + step
		var pts := PackedVector2Array([c])
		for k in range(17):
			var a: float = lerpf(a0, a1, float(k) / 16.0)
			pts.append(c + Vector2(cos(a), sin(a)) * radius)
		_wheel.draw_colored_polygon(pts, SEGMENTS[i]["color"])
		_wheel.draw_line(c, c + Vector2(cos(a0), sin(a0)) * radius, Color("#FDE68A", 0.6), 2.0, true)

		if font != null:
			var mid: float = a0 + step * 0.5
			var lp: Vector2 = c + Vector2(cos(mid), sin(mid)) * radius * 0.64
			_wheel.draw_set_transform(lp, mid + PI * 0.5, Vector2.ONE)
			_wheel.draw_string(font, Vector2(-60, 9), str(SEGMENTS[i]["label"]), HORIZONTAL_ALIGNMENT_CENTER, 120, 24, Color("#F3EFE6"))
			_wheel.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_wheel.draw_circle(c, 34.0, Color("#06100C"))
	_wheel.draw_circle(c, 28.0, Color("#F59E0B"))
