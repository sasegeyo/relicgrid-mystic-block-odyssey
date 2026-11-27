extends Node
## Otomatik oyun içi durum kaydı ve kaldığın yerden devam yöneticisi.
## Her oyun modunun kendi kayıt yuvası vardır (user://saved_run_<mod>.json):
## bir moda başlamak diğer modun yarım kalan oyununu silmez.

const SAVED_RUN_TEMPLATE: String = "user://saved_run_%d.json"
const LEGACY_SAVED_RUN_PATH: String = "user://saved_run.json"


func _ready() -> void:
	_migrate_legacy_save()


func _path_for_mode(mode: int) -> String:
	return SAVED_RUN_TEMPLATE % mode


## Eski tek yuvalı kaydı, ait olduğu modun yuvasına taşır.
func _migrate_legacy_save() -> void:
	if not FileAccess.file_exists(LEGACY_SAVED_RUN_PATH):
		return
	var data: Dictionary = _read_json(LEGACY_SAVED_RUN_PATH)
	if not data.is_empty() and data.has("mode"):
		var target: String = _path_for_mode(int(data["mode"]))
		if not FileAccess.file_exists(target):
			_write_json(target, data)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_SAVED_RUN_PATH))


func has_saved_run(mode: int) -> bool:
	return FileAccess.file_exists(_path_for_mode(mode))


func save_run(payload: Dictionary) -> void:
	if payload.is_empty() or not payload.has("mode"):
		return
	var data: Dictionary = payload.duplicate()
	data["saved_at"] = int(Time.get_unix_time_from_system())
	_write_json(_path_for_mode(int(payload["mode"])), data)


func load_run(mode: int) -> Dictionary:
	return _read_json(_path_for_mode(mode))


## Ana menüdeki "DEVAM ET" butonu için en son kaydedilen yarım oyunu döndürür.
func get_latest_run() -> Dictionary:
	var latest: Dictionary = {}
	for mode in GameState.PlayMode.values():
		var data: Dictionary = load_run(int(mode))
		if data.is_empty():
			continue
		if latest.is_empty() or int(data.get("saved_at", 0)) > int(latest.get("saved_at", 0)):
			latest = data
	return latest


func clear_saved_run(mode: int) -> void:
	var path: String = _path_for_mode(mode)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var raw_text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
