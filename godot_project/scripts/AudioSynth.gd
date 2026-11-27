extends Node
## Procedural Web-Style Audio Synthesizer for Godot 4 using AudioStreamGenerator

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _sample_rate: float = 44100.0

const MAJOR_SCALE_RATIOS: Array[float] = [1.0, 1.25, 1.5, 2.0] # Do - Mi - Sol - Do

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = _sample_rate
	gen.buffer_length = 0.25
	_player.stream = gen
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()

func play_place_thud() -> void:
	_push_tone(92.0, 0.09, 0.25)

func play_line_clear(lines_count: int, combo_streak: int) -> void:
	var semitone_shift: int = mini(12, max(0, combo_streak - 1) * 2)
	var base_freq: float = 261.63 * pow(2.0, semitone_shift / 12.0)
	for ratio in MAJOR_SCALE_RATIOS:
		_push_tone(base_freq * ratio, 0.07, 0.20)

func _push_tone(freq: float, duration: float, volume: float) -> void:
	if _playback == null:
		return
	var total_frames: int = mini(_playback.get_frames_available(), int(_sample_rate * duration))
	var phase: float = 0.0
	var increment: float = freq / _sample_rate
	for i in range(total_frames):
		var env: float = 1.0 - (float(i) / float(total_frames))
		var sample: float = sin(phase * TAU) * volume * env
		_playback.push_frame(Vector2(sample, sample))
		phase = fmod(phase + increment, 1.0)
