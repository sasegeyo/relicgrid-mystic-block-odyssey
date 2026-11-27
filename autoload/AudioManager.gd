extends Node
## Birleşik Ses ve Haptic Titreşim Yöneticisi (AudioManager).
## 8 kanallı AudioStreamPlayer havuzu, user://settings.cfg kalıcı tercihleri,
## opsiyonel Inspector AudioStream yuvaları, prosedürel 16-bit mono PCM sentezleyici
## ve mobil Input.vibrate_handheld desteği sağlar.

const SETTINGS_PATH: String = "user://settings.cfg"
const MIX_RATE: int = 22050
const POOL_CHANNELS: int = 8

enum HapticStrength {
	LIGHT = 0,
	MEDIUM = 1,
	HEAVY = 2
}

@export var ui_click: AudioStream
@export var purchase: AudioStream
@export var pickup: AudioStream
@export var place: AudioStream
@export var invalid: AudioStream
@export var clear: AudioStream
@export var all_clear: AudioStream
@export var ice_crack: AudioStream
@export var bomb_tick: AudioStream
@export var bomb_explode: AudioStream
@export var booster: AudioStream
@export var rescue: AudioStream
@export var new_best: AudioStream
@export var game_over: AudioStream

var sound_muted: bool = false
var haptics_muted: bool = false

var _players: Array[AudioStreamPlayer] = []
var _next_channel: int = 0


func _ready() -> void:
	_load_settings()
	for i in range(POOL_CHANNELS):
		var p := AudioStreamPlayer.new()
		p.volume_db = -3.0
		add_child(p)
		_players.append(p)
	_ensure_procedural_fallbacks()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		sound_muted = bool(cfg.get_value("audio", "sound_muted", false))
		haptics_muted = bool(cfg.get_value("audio", "haptics_muted", false))
	else:
		sound_muted = not GameState.sound_enabled
		haptics_muted = false
	GameState.sound_enabled = not sound_muted


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sound_muted", sound_muted)
	cfg.set_value("audio", "haptics_muted", haptics_muted)
	cfg.save(SETTINGS_PATH)
	GameState.sound_enabled = not sound_muted
	GameState.save_game()


func toggle_sound() -> bool:
	sound_muted = not sound_muted
	_save_settings()
	if not sound_muted:
		play_ui_click()
	return not sound_muted


func toggle_haptics() -> bool:
	haptics_muted = not haptics_muted
	_save_settings()
	if not haptics_muted:
		trigger_haptic(HapticStrength.LIGHT)
	return not haptics_muted


func trigger_haptic(strength: int) -> void:
	if haptics_muted:
		return
	if not OS.has_feature("mobile"):
		return
	match strength:
		HapticStrength.LIGHT:
			Input.vibrate_handheld(14, 0.40)
		HapticStrength.MEDIUM:
			Input.vibrate_handheld(28, 0.72)
		HapticStrength.HEAVY:
			Input.vibrate_handheld(55, 1.0)


func play_ui_click() -> void:
	_play_stream(ui_click, 1.0, -1.0)
	trigger_haptic(HapticStrength.LIGHT)


func play_purchase() -> void:
	_play_stream(purchase, 1.0, 1.0)
	trigger_haptic(HapticStrength.MEDIUM)


func play_pickup() -> void:
	_play_stream(pickup, 1.0, 0.0)
	trigger_haptic(HapticStrength.LIGHT)


func play_place() -> void:
	_play_stream(place, 1.0, 0.0)
	trigger_haptic(HapticStrength.LIGHT)


func play_invalid() -> void:
	_play_stream(invalid, 1.0, 0.0)
	trigger_haptic(HapticStrength.LIGHT)


func play_line_clear(combo: int = 1) -> void:
	var t: float = clampf(float(maxi(1, combo) - 1) / 6.0, 0.0, 1.0)
	var pitch: float = lerpf(1.00, 1.50, t)
	_play_stream(clear, pitch, 1.5)
	trigger_haptic(HapticStrength.MEDIUM if combo < 3 else HapticStrength.HEAVY)


func play_all_clear() -> void:
	_play_stream(all_clear, 1.0, 2.0)
	trigger_haptic(HapticStrength.HEAVY)


func play_ice_crack() -> void:
	_play_stream(ice_crack, 1.0, 0.5)
	trigger_haptic(HapticStrength.MEDIUM)


func play_bomb_tick(remaining: int = 3) -> void:
	var pitch: float = 1.0 + float(clampi(3 - remaining, 0, 2)) * 0.16
	_play_stream(bomb_tick, pitch, 0.0)
	trigger_haptic(HapticStrength.LIGHT)


func play_bomb_explode() -> void:
	_play_stream(bomb_explode, 1.0, 2.0)
	trigger_haptic(HapticStrength.HEAVY)


func play_booster() -> void:
	_play_stream(booster, 1.0, 1.0)
	trigger_haptic(HapticStrength.MEDIUM)


func play_rescue() -> void:
	_play_stream(rescue, 1.0, 1.0)
	trigger_haptic(HapticStrength.MEDIUM)


func play_new_best() -> void:
	_play_stream(new_best, 1.0, 1.8)
	trigger_haptic(HapticStrength.HEAVY)


func play_game_over() -> void:
	_play_stream(game_over, 1.0, 0.5)
	trigger_haptic(HapticStrength.HEAVY)


## İsimle ses çalma uyumluluk yardımcısı (eski play_sfx çağrıları için).
func play_sfx(sfx_name: String) -> void:
	match sfx_name:
		"ui_click": play_ui_click()
		"purchase", "coin_gain": play_purchase()
		"pickup": play_pickup()
		"place": play_place()
		"cancel", "invalid": play_invalid()
		"line_clear": play_line_clear(1)
		"victory", "all_clear": play_all_clear()
		"obstacle_hit", "ice_crack": play_ice_crack()
		"obstacle_break", "booster", "booster_hammer", "booster_refresh": play_booster()
		"booster_bomb", "curse_spread": play_bomb_explode()
		"game_over": play_game_over()
		_: play_ui_click()


func _play_stream(stream: AudioStream, pitch_scale: float, vol_offset_db: float) -> void:
	if sound_muted or stream == null:
		return
	if DisplayServer.get_name() == "headless":
		return
	if _players.is_empty():
		return
	var p: AudioStreamPlayer = _players[_next_channel]
	_next_channel = (_next_channel + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = clampf(pitch_scale, 0.5, 2.2)
	p.volume_db = -3.0 + vol_offset_db
	p.play()


func _ensure_procedural_fallbacks() -> void:
	if ui_click == null:
		ui_click = _synth_notes([
			{"f0": 540.0, "f1": 720.0, "dur": 0.055, "wave": "triangle", "vol": 0.35}
		])
	if purchase == null:
		purchase = _synth_notes([
			{"f0": 659.25, "f1": 783.99, "dur": 0.07, "wave": "chime", "vol": 0.48},
			{"f0": 987.77, "f1": 1318.51, "dur": 0.16, "wave": "chime", "vol": 0.52}
		])
	if pickup == null:
		pickup = _synth_notes([
			{"f0": 380.0, "f1": 620.0, "dur": 0.065, "wave": "sine", "vol": 0.42}
		])
	if place == null:
		place = _synth_notes([
			{"f0": 175.0, "f1": 118.0, "dur": 0.065, "wave": "stone", "vol": 0.54},
			{"f0": 440.0, "f1": 523.25, "dur": 0.060, "wave": "sine", "vol": 0.24}
		])
	if invalid == null:
		invalid = _synth_notes([
			{"f0": 260.0, "f1": 165.0, "dur": 0.11, "wave": "triangle", "vol": 0.38}
		])
	if clear == null:
		clear = _synth_notes([
			{"f0": 523.25, "f1": 587.33, "dur": 0.075, "wave": "chime", "vol": 0.46},
			{"f0": 659.25, "f1": 783.99, "dur": 0.095, "wave": "chime", "vol": 0.50},
			{"f0": 1046.50, "f1": 1046.50, "dur": 0.17, "wave": "chime", "vol": 0.44}
		])
	if all_clear == null:
		all_clear = _synth_notes([
			{"f0": 523.25, "f1": 523.25, "dur": 0.09, "wave": "chime", "vol": 0.48},
			{"f0": 659.25, "f1": 659.25, "dur": 0.09, "wave": "chime", "vol": 0.50},
			{"f0": 783.99, "f1": 783.99, "dur": 0.10, "wave": "chime", "vol": 0.52},
			{"f0": 1046.50, "f1": 1318.51, "dur": 0.28, "wave": "chime", "vol": 0.56}
		])
	if ice_crack == null:
		ice_crack = _synth_notes([
			{"f0": 1480.0, "f1": 920.0, "dur": 0.065, "wave": "crunch", "vol": 0.46},
			{"f0": 2100.0, "f1": 1760.0, "dur": 0.085, "wave": "chime", "vol": 0.36}
		])
	if bomb_tick == null:
		bomb_tick = _synth_notes([
			{"f0": 880.0, "f1": 660.0, "dur": 0.055, "wave": "triangle", "vol": 0.42}
		])
	if bomb_explode == null:
		bomb_explode = _synth_notes([
			{"f0": 165.0, "f1": 48.0, "dur": 0.24, "wave": "crunch", "vol": 0.65}
		])
	if booster == null:
		booster = _synth_notes([
			{"f0": 440.0, "f1": 659.25, "dur": 0.075, "wave": "chime", "vol": 0.46},
			{"f0": 880.0, "f1": 1174.66, "dur": 0.13, "wave": "chime", "vol": 0.48}
		])
	if rescue == null:
		rescue = _synth_notes([
			{"f0": 392.0, "f1": 523.25, "dur": 0.085, "wave": "sine", "vol": 0.44},
			{"f0": 587.33, "f1": 783.99, "dur": 0.13, "wave": "chime", "vol": 0.46}
		])
	if new_best == null:
		new_best = _synth_notes([
			{"f0": 587.33, "f1": 587.33, "dur": 0.09, "wave": "chime", "vol": 0.48},
			{"f0": 739.99, "f1": 739.99, "dur": 0.09, "wave": "chime", "vol": 0.50},
			{"f0": 880.00, "f1": 880.00, "dur": 0.10, "wave": "chime", "vol": 0.52},
			{"f0": 1174.66, "f1": 1174.66, "dur": 0.26, "wave": "chime", "vol": 0.55}
		])
	if game_over == null:
		game_over = _synth_notes([
			{"f0": 392.0, "f1": 369.99, "dur": 0.14, "wave": "triangle", "vol": 0.44},
			{"f0": 329.63, "f1": 293.66, "dur": 0.16, "wave": "triangle", "vol": 0.42},
			{"f0": 261.63, "f1": 196.00, "dur": 0.30, "wave": "triangle", "vol": 0.45}
		])


func _synth_notes(notes: Array) -> AudioStreamWAV:
	var total_samples: int = 0
	for n in notes:
		total_samples += maxi(1, int(float(n["dur"]) * float(MIX_RATE)))

	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)

	var write_idx: int = 0
	var phase: float = 0.0
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = 42069

	for n in notes:
		var f0: float = float(n["f0"])
		var f1: float = float(n["f1"])
		var dur: float = float(n["dur"])
		var wave: String = str(n["wave"])
		var vol: float = float(n["vol"])
		var count: int = maxi(1, int(dur * float(MIX_RATE)))

		for i in range(count):
			var t_norm: float = float(i) / float(count)
			var freq: float = lerpf(f0, f1, t_norm)
			phase += TAU * freq / float(MIX_RATE)
			if phase > TAU * 64.0:
				phase = fmod(phase, TAU)

			var attack: float = clampf(float(i) / (0.005 * float(MIX_RATE)), 0.0, 1.0)
			var decay: float = pow(1.0 - t_norm, 1.45)
			var env: float = attack * decay

			var sample: float = 0.0
			match wave:
				"sine":
					sample = sin(phase)
				"triangle":
					sample = (2.0 / PI) * asin(sin(phase))
				"chime":
					sample = 0.64 * sin(phase) + 0.25 * sin(phase * 2.0) + 0.11 * sin(phase * 3.01)
				"stone":
					sample = 0.68 * sin(phase) + 0.32 * noise_rng.randf_range(-1.0, 1.0) * (1.0 - t_norm)
				"crunch":
					sample = 0.42 * signf(sin(phase)) + 0.58 * noise_rng.randf_range(-1.0, 1.0)
				_:
					sample = sin(phase)

			var pcm_val: int = clampi(int(sample * env * vol * 32767.0), -32767, 32767)
			bytes.encode_s16(write_idx, pcm_val)
			write_idx += 2

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
