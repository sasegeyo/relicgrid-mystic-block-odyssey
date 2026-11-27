extends Node
## Harici ses dosyası gerektirmeyen, çalışma anında 16-bit PCM AudioStreamWAV
## sentezleyen prosedürel mistik ses yöneticisi.

const MIX_RATE: int = 22050
const POOL_SIZE: int = 8

var _players: Array[AudioStreamPlayer] = []
var _next_player_idx: int = 0
var _cached_streams: Dictionary = {}


func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.volume_db = -4.0
		add_child(p)
		_players.append(p)
	_prebuild_sfx()


func _prebuild_sfx() -> void:
	_cached_streams["ui_click"] = _synth_notes([
		{"f0": 540.0, "f1": 720.0, "dur": 0.055, "wave": "triangle", "vol": 0.35}
	])
	_cached_streams["pickup"] = _synth_notes([
		{"f0": 330.0, "f1": 520.0, "dur": 0.08, "wave": "sine", "vol": 0.42}
	])
	_cached_streams["cancel"] = _synth_notes([
		{"f0": 310.0, "f1": 195.0, "dur": 0.11, "wave": "triangle", "vol": 0.35}
	])
	_cached_streams["place"] = _synth_notes([
		{"f0": 185.0, "f1": 135.0, "dur": 0.065, "wave": "stone", "vol": 0.50},
		{"f0": 440.0, "f1": 554.37, "dur": 0.075, "wave": "sine", "vol": 0.28}
	])
	_cached_streams["line_clear"] = _synth_notes([
		{"f0": 523.25, "f1": 587.33, "dur": 0.075, "wave": "chime", "vol": 0.45},
		{"f0": 659.25, "f1": 783.99, "dur": 0.10, "wave": "chime", "vol": 0.48},
		{"f0": 1046.50, "f1": 1046.50, "dur": 0.18, "wave": "chime", "vol": 0.42}
	])
	_cached_streams["obstacle_hit"] = _synth_notes([
		{"f0": 240.0, "f1": 120.0, "dur": 0.11, "wave": "crunch", "vol": 0.50}
	])
	_cached_streams["obstacle_break"] = _synth_notes([
		{"f0": 290.0, "f1": 110.0, "dur": 0.09, "wave": "crunch", "vol": 0.55},
		{"f0": 740.0, "f1": 987.77, "dur": 0.14, "wave": "chime", "vol": 0.38}
	])
	_cached_streams["curse_spread"] = _synth_notes([
		{"f0": 220.0, "f1": 164.81, "dur": 0.12, "wave": "saw_soft", "vol": 0.38},
		{"f0": 155.56, "f1": 110.0, "dur": 0.18, "wave": "saw_soft", "vol": 0.42}
	])
	_cached_streams["purchase"] = _synth_notes([
		{"f0": 659.25, "f1": 783.99, "dur": 0.07, "wave": "chime", "vol": 0.48},
		{"f0": 987.77, "f1": 1318.51, "dur": 0.16, "wave": "chime", "vol": 0.52}
	])
	_cached_streams["coin_gain"] = _synth_notes([
		{"f0": 880.0, "f1": 1174.66, "dur": 0.09, "wave": "chime", "vol": 0.38}
	])
	_cached_streams["booster_hammer"] = _synth_notes([
		{"f0": 320.0, "f1": 95.0, "dur": 0.10, "wave": "crunch", "vol": 0.58},
		{"f0": 880.0, "f1": 1174.66, "dur": 0.13, "wave": "chime", "vol": 0.44}
	])
	_cached_streams["booster_refresh"] = _synth_notes([
		{"f0": 392.0, "f1": 587.33, "dur": 0.06, "wave": "sine", "vol": 0.42},
		{"f0": 587.33, "f1": 880.0, "dur": 0.09, "wave": "chime", "vol": 0.45}
	])
	_cached_streams["booster_bomb"] = _synth_notes([
		{"f0": 180.0, "f1": 55.0, "dur": 0.22, "wave": "crunch", "vol": 0.62},
		{"f0": 523.25, "f1": 1046.50, "dur": 0.15, "wave": "chime", "vol": 0.40}
	])
	_cached_streams["victory"] = _synth_notes([
		{"f0": 523.25, "f1": 523.25, "dur": 0.11, "wave": "chime", "vol": 0.46},
		{"f0": 659.25, "f1": 659.25, "dur": 0.11, "wave": "chime", "vol": 0.48},
		{"f0": 783.99, "f1": 783.99, "dur": 0.12, "wave": "chime", "vol": 0.50},
		{"f0": 1046.50, "f1": 1046.50, "dur": 0.34, "wave": "chime", "vol": 0.55}
	])
	_cached_streams["game_over"] = _synth_notes([
		{"f0": 392.00, "f1": 369.99, "dur": 0.15, "wave": "triangle", "vol": 0.44},
		{"f0": 329.63, "f1": 293.66, "dur": 0.17, "wave": "triangle", "vol": 0.42},
		{"f0": 261.63, "f1": 196.00, "dur": 0.34, "wave": "triangle", "vol": 0.45}
	])


func play_sfx(sfx_name: String, pitch_scale: float = 1.0, volume_offset_db: float = 0.0) -> void:
	if not GameState.sound_enabled:
		return
	if not _cached_streams.has(sfx_name):
		return
	if DisplayServer.get_name() == "headless":
		return
	var p: AudioStreamPlayer = _players[_next_player_idx]
	_next_player_idx = (_next_player_idx + 1) % _players.size()
	p.stream = _cached_streams[sfx_name]
	p.pitch_scale = clampf(pitch_scale, 0.55, 2.2)
	p.volume_db = -4.0 + volume_offset_db
	p.play()


func play_combo(combo_level: int) -> void:
	var semitones: float = float(clampi(combo_level - 1, 0, 8)) * 1.5
	var pitch: float = pow(2.0, semitones / 12.0)
	play_sfx("line_clear", pitch, 1.5)


func _synth_notes(notes: Array) -> AudioStreamWAV:
	var total_samples: int = 0
	for n in notes:
		total_samples += maxi(1, int(float(n["dur"]) * float(MIX_RATE)))

	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)

	var write_idx: int = 0
	var phase: float = 0.0
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = 13379

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

			var attack: float = clampf(float(i) / (0.006 * float(MIX_RATE)), 0.0, 1.0)
			var decay: float = pow(1.0 - t_norm, 1.45)
			var env: float = attack * decay

			var sample: float = 0.0
			match wave:
				"sine":
					sample = sin(phase)
				"triangle":
					sample = (2.0 / PI) * asin(sin(phase))
				"chime":
					sample = 0.65 * sin(phase) + 0.25 * sin(phase * 2.0) + 0.10 * sin(phase * 3.01)
				"stone":
					sample = 0.68 * sin(phase) + 0.32 * noise_rng.randf_range(-1.0, 1.0) * (1.0 - t_norm)
				"crunch":
					var grit: float = noise_rng.randf_range(-1.0, 1.0)
					sample = 0.45 * signf(sin(phase)) + 0.55 * grit
				"saw_soft":
					sample = 0.55 * sin(phase) + 0.30 * sin(phase * 1.5) + 0.15 * (2.0 * fmod(phase / TAU, 1.0) - 1.0)
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
