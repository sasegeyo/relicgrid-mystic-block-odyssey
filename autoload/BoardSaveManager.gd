extends Node
## Otomatik oyun içi durum kaydı ve kaldığın yerden devam yöneticisi (user://saved_run.json).

const SAVED_RUN_PATH: String = "user://saved_run.json"


func has_saved_run() -> bool:
	return FileAccess.file_exists(SAVED_RUN_PATH)


func save_run(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	var file := FileAccess.open(SAVED_RUN_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))
		file.close()


func load_run() -> Dictionary:
	if not FileAccess.file_exists(SAVED_RUN_PATH):
		return {}
	var file := FileAccess.open(SAVED_RUN_PATH, FileAccess.READ)
	if file == null:
		return {}
	var raw_text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func clear_saved_run() -> void:
	if FileAccess.file_exists(SAVED_RUN_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVED_RUN_PATH))
