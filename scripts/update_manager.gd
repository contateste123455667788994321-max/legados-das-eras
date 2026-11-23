extends Node
## Verifica novos APKs publicados sem prejudicar o modo offline.
## O manifest_url precisa ser publico e HTTPS; repositorios privados nao servem para distribuicao.
const VERSION_FILE := "res://config/version.json"
var _local_version_code := 0
var _local_version_name := ""
var _request: HTTPRequest

func _ready() -> void:
	var conf := _load_config()
	if conf.is_empty():
		return
	_local_version_code = int(conf.get("version_code", 0))
	_local_version_name = str(conf.get("version_name", ""))
	var manifest_url := str(conf.get("update_manifest_url", ""))
	if OS.get_name() != "Android" or not manifest_url.begins_with("https://"):
		return
	_request = HTTPRequest.new()
	add_child(_request)
	_request.request_completed.connect(_on_manifest_received)
	var err := _request.request(manifest_url)
	if err != OK:
		push_warning("Nao foi possivel verificar versoes; o jogo permanece offline.")

func _load_config() -> Dictionary:
	if not FileAccess.file_exists(VERSION_FILE):
		return {}
	var file := FileAccess.open(VERSION_FILE, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func _on_manifest_received(result: int, http_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or http_code != 200:
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var latest: Dictionary = parsed
	var next_code := int(latest.get("version_code", 0))
	var download_url := str(latest.get("apk_url", ""))
	if next_code <= _local_version_code or not download_url.begins_with("https://"):
		return
	var required := bool(latest.get("required", false))
	var next_name := str(latest.get("version_name", "nova"))
	_offer_update(next_name, download_url, required)

func _offer_update(next_name: String, download_url: String, required: bool) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Nova versao do Legado das Eras"
	dialog.dialog_text = "Versao %s disponivel. Instale para receber melhorias sem perder o seu mundo salvo." % next_name
	if required:
		dialog.dialog_text += "\nEsta versao foi marcada pelo criador como uma atualizacao importante."
		dialog.cancel_button_text = "Agora nao"
	else:
		dialog.cancel_button_text = "Depois"
	dialog.ok_button_text = "Baixar atualizacao"
	dialog.confirmed.connect(func() -> void:
		OS.shell_open(download_url)
	)
	add_child(dialog)
	dialog.popup_centered()
	dialog.close_requested.connect(dialog.queue_free)
