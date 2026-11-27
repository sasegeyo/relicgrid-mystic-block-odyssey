extends Node
## Görsel Efekt & Juice yöneticisi: Camera2D sarsıntısı, prosedürel yumuşak kare
## CPUParticles2D patlamaları, satır/sütun ışık dalgaları ve All-Clear konfetisi.

var _fx_layer: CanvasLayer
var _soft_square_tex: ImageTexture
var _rng := RandomNumberGenerator.new()

var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_elapsed: float = 0.0
var _active_camera: Camera2D = null


func _ready() -> void:
	_rng.randomize()
	_fx_layer = CanvasLayer.new()
	_fx_layer.layer = 35
	add_child(_fx_layer)
	_soft_square_tex = _build_soft_square_texture(16)


func _process(delta: float) -> void:
	if _shake_duration <= 0.0:
		return

	_shake_elapsed += delta
	var cam: Camera2D = _resolve_camera()
	if _shake_elapsed >= _shake_duration:
		_shake_duration = 0.0
		_shake_intensity = 0.0
		_shake_elapsed = 0.0
		if cam != null and is_instance_valid(cam):
			cam.offset = Vector2.ZERO
		return

	var remain_t: float = 1.0 - clampf(_shake_elapsed / _shake_duration, 0.0, 1.0)
	var cur_strength: float = _shake_intensity * remain_t * remain_t
	if cam != null and is_instance_valid(cam):
		cam.offset = Vector2(
			_rng.randf_range(-cur_strength, cur_strength),
			_rng.randf_range(-cur_strength, cur_strength)
		)


func _resolve_camera() -> Camera2D:
	if _active_camera != null and is_instance_valid(_active_camera):
		return _active_camera
	var vp: Viewport = get_viewport()
	if vp != null:
		_active_camera = vp.get_camera_2d()
	return _active_camera


func shake(intensity: float, duration: float = 0.22) -> void:
	_active_camera = _resolve_camera()
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_duration = maxf(_shake_duration - _shake_elapsed, duration)
	_shake_elapsed = 0.0


func burst_at(world_pos: Vector2, color: Color, amount: int = 8) -> void:
	if _fx_layer == null:
		return
	var p := CPUParticles2D.new()
	p.position = world_pos
	p.texture = _soft_square_tex
	p.emitting = true
	p.one_shot = true
	p.amount = maxi(3, amount)
	p.lifetime = 0.48
	p.explosiveness = 0.94
	p.spread = 180.0
	p.gravity = Vector2(0.0, 320.0)
	p.initial_velocity_min = 75.0
	p.initial_velocity_max = 220.0
	p.scale_amount_min = 0.45
	p.scale_amount_max = 1.05
	p.color = color
	p.finished.connect(p.queue_free)
	_fx_layer.add_child(p)


func flash_line(center: Vector2, size: Vector2, color: Color) -> void:
	if _fx_layer == null or _soft_square_tex == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = _soft_square_tex
	sprite.position = center
	var tex_sz: float = maxf(1.0, float(_soft_square_tex.get_width()))
	var start_scale := Vector2(maxf(1.0, size.x) / tex_sz, maxf(1.0, size.y) / tex_sz)
	sprite.scale = start_scale
	sprite.modulate = Color(color.r, color.g, color.b, 0.90)
	_fx_layer.add_child(sprite)

	var is_horizontal: bool = size.x >= size.y
	var end_scale := Vector2(start_scale.x * 1.06, 0.05) if is_horizontal else Vector2(0.05, start_scale.y * 1.06)

	var tw := sprite.create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "scale", end_scale, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(sprite.queue_free)


func play_all_clear_celebration(board_center: Vector2) -> void:
	shake(11.0, 0.38)
	var colors: Array[Color] = [
		Color("#FDE68A"),
		Color("#4AE3A7"),
		Color("#F59E0B"),
		Color("#C084FC"),
		Color("#60A5FA"),
		Color("#F87171")
	]
	for i in range(colors.size()):
		var angle: float = TAU * float(i) / float(colors.size())
		var offset := Vector2(cos(angle), sin(angle)) * 72.0
		burst_at(board_center + offset, colors[i], 14)
	burst_at(board_center, Color("#FEF08A"), 22)


func _build_soft_square_texture(px_size: int) -> ImageTexture:
	var img := Image.create(px_size, px_size, false, Image.FORMAT_RGBA8)
	var half: float = float(px_size - 1) * 0.5
	for y in range(px_size):
		for x in range(px_size):
			var dx: float = absf(float(x) - half) / maxf(1.0, half)
			var dy: float = absf(float(y) - half) / maxf(1.0, half)
			var edge: float = maxf(dx, dy)
			var corner_dist: float = Vector2(maxf(0.0, dx - 0.65), maxf(0.0, dy - 0.65)).length()
			var alpha: float = clampf(1.0 - corner_dist * 2.4, 0.0, 1.0)
			if edge > 0.92:
				alpha *= 0.65
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(img)
