extends Node
## Atualizacoes opcionais. O mundo continua jogavel sem rede.
## O APK nao instala automaticamente: o Android pede permissao.
const VERSION_FILE := "res://config/version.json"
var _local_version_code := 0
var _local_version_name := ""
var _manifest_url := ""
var _request: HTTPRequest
var _check_silent := false
var _busy := false

func _ready() -> void:
	var conf := _load_config()
	_local_version_code = int(conf.get("version_code", 0))
	_local_version_name = str(conf.get("version_name", "desconhecida"))
	_manifest_url = str(conf.get("update_manifest_url", ""))
	if OS.get_name() == "Android" and _manifest_url.begins_with("https://"):
		check_now(true)

func check_now(silent: bool = false) -> void:
	if _busy:
		if not silent:
			_notice("Atualizacoes", "Uma verificacao ja esta em andamento.")
		return
	if not _manifest_url.begins_with("https://"):
		if not silent:
			_notice("Atualizacoes em preparacao", "Versao instalada: %s.\nAinda nao existe um endereco publico de atualizacoes configurado.\nO jogo pode continuar offline." % _local_version_name)
		return
	if _request == null:
		_request = HTTPRequest.new()
		_request.timeout = 15.0
		add_child(_request)
		_request.request_completed.connect(_on_manifest_received)
	_check_silent = silent
	_busy = true
	var error: Error = _request.request(_manifest_url)
	if error != OK:
		_busy = false
		if not silent:
			_notice("Sem conexao", "Nao foi possivel iniciar a verificacao.\nSeu mundo salvo continua seguro.")

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
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or http_code != 200:
		if not _check_silent:
			_notice("Nao foi possivel verificar", "Confira a conexao e tente novamente.\nO jogo continua disponivel offline.")
		return
	if body.size() > 32768:
		if not _check_silent:
			_notice("Resposta invalida", "O servidor de atualizacoes enviou dados inesperados.")
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		if not _check_silent:
			_notice("Resposta invalida", "Nao foi possivel ler a versao do servidor.")
		return
	var latest: Dictionary = parsed
	var next_code := int(latest.get("version_code", 0))
	var download_url := str(latest.get("apk_url", ""))
	if next_code <= _local_version_code:
		if not _check_silent:
			_notice("Jogo atualizado", "Voce ja tem a versao mais recente: %s." % _local_version_name)
		return
	if not download_url.begins_with("https://"):
		if not _check_silent:
			_notice("Atualizacao indisponivel", "Uma nova versao foi anunciada, mas o APK ainda nao possui um link HTTPS valido.")
		return
	var required := bool(latest.get("required", false))
	var next_name := str(latest.get("version_name", "nova"))
	_offer_update(next_name, download_url, required)

func _offer_update(next_name: String, download_url: String, required: bool) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Atualizacao do Legado das Eras"
	dialog.dialog_text = "Versao %s disponivel.\nDeseja abrir o download do APK?\nO Android pedira sua confirmacao para instalar." % next_name
	if required:
		dialog.dialog_text += "\nAtualizacao importante recomendada."
	dialog.ok_button_text = "Baixar APK"
	dialog.cancel_button_text = "Depois"
	dialog.confirmed.connect(func() -> void:
		OS.shell_open(download_url)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func _notice(title_text: String, body_text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title_text
	dialog.dialog_text = body_text
	dialog.ok_button_text = "Entendi"
	dialog.confirmed.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()
