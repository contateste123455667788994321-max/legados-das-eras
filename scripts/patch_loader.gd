extends Node
## Monta o pacote de conteudo antes que as cenas ou scripts do jogo sejam carregados.
## O APK instalado permanece intacto; o progresso continua em user://world.json.
const MIN_APK_VERSION_CODE := 4
const PATCH_DIR := "user://updates"
const PATCH_PATH := PATCH_DIR + "/active.pck"
const PATCH_META := PATCH_DIR + "/active.json"
var active_version_code := MIN_APK_VERSION_CODE
var active_version_name := "0.4.0"
var last_error := ""

func _init() -> void:
	var metadata := _read_metadata()
	if metadata.is_empty():
		return
	var code := int(metadata.get("version_code", 0))
	var min_apk := int(metadata.get("min_apk_code", 0))
	var sha := str(metadata.get("sha256", "")).to_lower()
	if code <= MIN_APK_VERSION_CODE or min_apk > MIN_APK_VERSION_CODE or min_apk < 1:
		return
	if sha.length() != 64 or not sha.is_valid_hex_number():
		last_error = "Hash de integridade ausente."
		return
	if not FileAccess.file_exists(PATCH_PATH):
		last_error = "Pacote de atualizacao nao encontrado."
		return
	if FileAccess.get_sha256(PATCH_PATH).to_lower() != sha:
		last_error = "Falha na verificacao da integridade da atualizacao."
		return
	if not ProjectSettings.load_resource_pack(ProjectSettings.globalize_path(PATCH_PATH), true):
		last_error = "Nao foi possivel montar a atualizacao."
		return
	active_version_code = code
	active_version_name = str(metadata.get("version_name", "Atualizacao"))
	print("Legado das Eras: pacote de conteudo ", active_version_name, " carregado.")

func _read_metadata() -> Dictionary:
	if not FileAccess.file_exists(PATCH_META):
		return {}
	var file := FileAccess.open(PATCH_META, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}
