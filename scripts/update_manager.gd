extends Node
## Atualizador do Legado das Eras. Alteracoes do jogo podem vir num .pck,
## preservando o APK instalado. Mudancas nativas ainda exigem APK e confirmacao do Android.
const VERSION_FILE := "res://config/version.json"
const UPDATES_DIR := "user://updates"
const ACTIVE_PACK := UPDATES_DIR + "/active.pck"
const PENDING_PACK := UPDATES_DIR + "/pending.pck"
const PENDING_DOWNLOAD := UPDATES_DIR + "/download.bin"
const BACKUP_PACK := UPDATES_DIR + "/previous.pck"
const ACTIVE_META := UPDATES_DIR + "/active.json"
const PENDING_META := UPDATES_DIR + "/pending.json"
const BACKUP_META := UPDATES_DIR + "/previous.json"
const PACK_LIMIT_BYTES := 157286400
var _base_version_code := 0
var _installed_version_code := 0
var _installed_version_name := ""
var _manifest_url := ""
var _request: HTTPRequest
var _pack_request: HTTPRequest
var _check_silent := false
var _busy := false
var _next_patch := {}
var _restart_requested := false

func _ready() -> void:
	var conf := _load_config()
	_base_version_code = int(conf.get("version_code", 0))
	_installed_version_code = _base_version_code
	_installed_version_name = str(conf.get("version_name", "desconhecida"))
	var loader: Node = get_node_or_null("/root/PatchLoader")
	if loader != null and int(loader.get("base_version_code")) > 0:
		_base_version_code = int(loader.get("base_version_code"))
	if loader != null and int(loader.get("active_version_code")) > _installed_version_code:
		_installed_version_code = int(loader.get("active_version_code"))
		_installed_version_name = str(loader.get("active_version_name"))
	_manifest_url = str(conf.get("update_manifest_url", ""))
	if OS.get_name() == "Android" and _is_https(_manifest_url):
		check_now(true)

func _is_https(url: String) -> bool:
	return url.begins_with("https://") and not url.contains("@") and url.length() < 2048

func check_now(silent: bool = false) -> void:
	if _restart_requested:
		if not silent: _notice("Atualizacao instalada","Reabra o jogo para carregar a versao nova.")
		return
	if _busy:
		if not silent:
			_notice("Atualizacoes", "Uma verificacao ja esta em andamento.")
		return
	if not _is_https(_manifest_url):
		if not silent:
			_notice("Atualizacoes em preparacao", "Versao instalada: %s.\nFalta publicar um servidor de atualizacoes oficial.\nO jogo pode continuar offline." % _installed_version_name)
		return
	if _request == null:
		_request = HTTPRequest.new()
		_request.timeout = 15.0
		_request.body_size_limit = 32768
		add_child(_request)
		_request.request_completed.connect(_on_manifest_received)
	_check_silent = silent
	_busy = true
	var separator := "&" if _manifest_url.contains("?") else "?"
	var fresh_url := _manifest_url + separator + "check=" + str(Time.get_unix_time_from_system())
	if _request.request(fresh_url, PackedStringArray(["Cache-Control: no-cache", "Pragma: no-cache"])) != OK:
		_busy = false
		if not silent:
			_notice("Sem conexao", "Nao foi possivel iniciar a verificacao. O jogo continua offline.")

func _load_config() -> Dictionary:
	if not FileAccess.file_exists(VERSION_FILE):
		return {}
	var file := FileAccess.open(VERSION_FILE, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}

func _on_manifest_received(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or body.size() > 32768:
		if not _check_silent:
			_notice("Sem atualizacoes", "Nao foi possivel consultar o servidor.\nO mundo continua disponivel offline.")
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		if not _check_silent:
			_notice("Resposta invalida", "O servidor enviou dados desconhecidos.")
		return
	var latest: Dictionary = parsed
	var version_code: int = int(latest.get("version_code", 0))
	if version_code <= _installed_version_code:
		if not _check_silent:
			_notice("Jogo atualizado", "Ja tens a versao mais recente: %s." % _installed_version_name)
		return
	var pack_url: String = str(latest.get("pack_url", ""))
	var sha256: String = str(latest.get("pack_sha256", "")).to_lower()
	var required_base: int = int(latest.get("min_apk_code", 0))
	var pack_bytes: int = int(latest.get("pack_bytes", 0))
	if _is_https(pack_url) and sha256.length() == 64 and sha256.is_valid_hex_number() and required_base > 0 and required_base <= _base_version_code and pack_bytes > 0 and pack_bytes <= PACK_LIMIT_BYTES:
		_next_patch = latest
		_offer_patch(str(latest.get("version_name", "nova")), pack_bytes)
		return
	var apk_url: String = str(latest.get("apk_url", ""))
	if _is_https(apk_url):
		_offer_apk(str(latest.get("version_name", "nova")), apk_url)
	elif not _check_silent:
		_notice("Atualizacao indisponivel", "Esta versao exige uma nova base do jogo, mas o download oficial ainda nao foi publicado.")

func _offer_patch(version_name: String, bytes: int) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Atualizacao dentro do jogo"
	dialog.dialog_text = "Versao %s disponivel (%d MB).\nBaixar o pacote do jogo sem reinstalar o APK?\nO mundo salvo permanecera no aparelho." % [version_name, int(ceil(float(bytes) / 1048576.0))]
	dialog.ok_button_text = "Atualizar"
	dialog.cancel_button_text = "Depois"
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
		_download_patch()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func _download_patch() -> void:
	if _busy or _next_patch.is_empty():
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(UPDATES_DIR)) != OK:
		_notice("Falha", "Nao foi possivel criar a pasta de atualizacoes.")
		return
	if FileAccess.file_exists(PENDING_PACK):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PENDING_PACK))
	if FileAccess.file_exists(PENDING_DOWNLOAD):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PENDING_DOWNLOAD))
	if _pack_request == null:
		_pack_request = HTTPRequest.new()
		_pack_request.timeout = 120.0
		_pack_request.body_size_limit = PACK_LIMIT_BYTES
		_pack_request.download_file = PENDING_DOWNLOAD
		add_child(_pack_request)
		_pack_request.request_completed.connect(_on_patch_received)
	_busy = true
	var pack_url: String = str(_next_patch["pack_url"])
	var separator := "&" if pack_url.contains("?") else "?"
	pack_url += separator + "sha=" + str(_next_patch["pack_sha256"])
	if _pack_request.request(pack_url, PackedStringArray(["Cache-Control: no-cache"])) != OK:
		_busy = false
		_notice("Falha na rede", "Nao foi possivel iniciar o download da atualizacao.")

func _on_patch_received(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not FileAccess.file_exists(PENDING_DOWNLOAD):
		_notice("Download interrompido", "Nao foi possivel baixar o pacote. Tenta novamente.")
		return
	var file := FileAccess.open(PENDING_DOWNLOAD, FileAccess.READ)
	if file == null:
		_notice("Falha", "Nao foi possivel ler o pacote baixado.")
		return
	var actual_bytes: int = file.get_length()
	file.close()
	var download_sha256: String = str(_next_patch["pack_sha256"]).to_lower()
	if actual_bytes != int(_next_patch["pack_bytes"]) or FileAccess.get_sha256(PENDING_DOWNLOAD).to_lower() != download_sha256:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PENDING_DOWNLOAD))
		_notice("Arquivo invalido", "A atualizacao nao passou na verificacao de integridade.")
		return
	var format: String = str(_next_patch.get("pack_format", "pck")).to_lower()
	var download_path: String = ProjectSettings.globalize_path(PENDING_DOWNLOAD)
	var pending_path: String = ProjectSettings.globalize_path(PENDING_PACK)
	if format == "zip":
		# O CI exporta um ZIP; extrair SOMENTE o PCK conhecido, sem caminhos arbitrarios.
		var zip := ZIPReader.new()
		if zip.open(PENDING_DOWNLOAD) != OK:
			_notice("Arquivo invalido", "O pacote compactado nao pode ser aberto.")
			return
		const ENTRY := "Legado-das-Eras-conteudo.pck"
		if not zip.get_files().has(ENTRY):
			zip.close()
			_notice("Arquivo invalido", "O pacote nao contem os arquivos do jogo.")
			return
		var unpacked: PackedByteArray = zip.read_file(ENTRY)
		zip.close()
		if unpacked.is_empty() or unpacked.size() > PACK_LIMIT_BYTES:
			_notice("Arquivo invalido", "O pacote compactado ultrapassa os limites permitidos.")
			return
		var output_pack := FileAccess.open(PENDING_PACK, FileAccess.WRITE)
		if output_pack == null:
			_notice("Falha", "Nao foi possivel salvar os arquivos do jogo.")
			return
		output_pack.store_buffer(unpacked)
		output_pack.close()
		DirAccess.remove_absolute(download_path)
	elif format == "pck":
		if DirAccess.rename_absolute(download_path, pending_path) != OK:
			_notice("Falha", "Nao foi possivel preparar o pacote de atualizacao.")
			return
	else:
		_notice("Arquivo invalido", "O formato desta atualizacao nao e suportado.")
		return
	var installed_sha256: String = FileAccess.get_sha256(PENDING_PACK).to_lower()
	var expected_pck_hash: String = str(_next_patch.get("pack_pck_sha256", "")).to_lower()
	if not expected_pck_hash.is_empty() and installed_sha256 != expected_pck_hash:
		DirAccess.remove_absolute(pending_path)
		_notice("Arquivo invalido", "O conteudo extraido falhou na verificacao de integridade.")
		return

	# Salvar antes de trocar o pacote ativo. Sem save valido, nao reiniciar.
	var scene:Node=get_tree().current_scene
	if scene==null: scene=get_parent()
	if scene!=null and scene.has_method("prepare_update_restart") and not bool(scene.call("prepare_update_restart")):
		_notice("Mundo nao salvo","Nao foi possivel salvar o progresso. A atualizacao nao foi ativada.")
		return
	var meta:Dictionary={"version_code":int(_next_patch["version_code"]),"version_name":str(_next_patch.get("version_name","nova")),"min_apk_code":int(_next_patch.get("min_apk_code",0)),"sha256":installed_sha256}
	if not _activate_verified_pack(meta):
		if scene!=null and scene.has_method("cancel_update_restart"): scene.call("cancel_update_restart")
		_notice("Falha","Nao foi possivel ativar a atualizacao. O pacote anterior foi preservado quando disponivel.")
		return
	_restart_requested=true
	# O teste headless verifica a instalacao sem encerrar o processo de testes.
	if DisplayServer.get_name()=="headless": return
	_restart_after_patch(str(meta["version_name"]))

func _activate_verified_pack(meta:Dictionary) -> bool:
	var output:FileAccess=FileAccess.open(PENDING_META,FileAccess.WRITE)
	if output==null: return false
	output.store_string(JSON.stringify(meta))
	output.flush()
	output.close()
	var active_path:String=ProjectSettings.globalize_path(ACTIVE_PACK)
	var pending_path:String=ProjectSettings.globalize_path(PENDING_PACK)
	var backup_path:String=ProjectSettings.globalize_path(BACKUP_PACK)
	var active_meta:String=ProjectSettings.globalize_path(ACTIVE_META)
	var pending_meta:String=ProjectSettings.globalize_path(PENDING_META)
	var backup_meta:String=ProjectSettings.globalize_path(BACKUP_META)
	if FileAccess.file_exists(BACKUP_PACK): DirAccess.remove_absolute(backup_path)
	if FileAccess.file_exists(BACKUP_META): DirAccess.remove_absolute(backup_meta)
	var had_previous:bool=FileAccess.file_exists(ACTIVE_PACK)
	var had_meta:bool=FileAccess.file_exists(ACTIVE_META)
	if had_previous and DirAccess.rename_absolute(active_path,backup_path)!=OK: return false
	if had_meta and DirAccess.rename_absolute(active_meta,backup_meta)!=OK:
		if had_previous: DirAccess.rename_absolute(backup_path,active_path)
		return false
	if DirAccess.rename_absolute(pending_path,active_path)!=OK:
		if had_previous: DirAccess.rename_absolute(backup_path,active_path)
		if had_meta: DirAccess.rename_absolute(backup_meta,active_meta)
		return false
	if DirAccess.rename_absolute(pending_meta,active_meta)!=OK:
		DirAccess.remove_absolute(active_path)
		if had_previous: DirAccess.rename_absolute(backup_path,active_path)
		if had_meta: DirAccess.rename_absolute(backup_meta,active_meta)
		return false
	return true

func _restart_after_patch(version_name:String) -> void:
	_busy=true
	var dialog:=AcceptDialog.new()
	dialog.title="Atualizacao instalada"
	dialog.dialog_text="Mundo salvo. Reiniciando na versao "+version_name+"..."
	dialog.ok_button_text="Reabrir jogo"
	add_child(dialog)
	dialog.popup_centered()
	await get_tree().create_timer(0.35,true).timeout
	if OS.get_name()=="Android":
		# Godot 4.4 permite recriar a instancia Android; nao usar set_restart_on_exit no mobile.
		var result:int=OS.create_instance(PackedStringArray())
		if result>=0:
			dialog.dialog_text="Versao "+version_name+" instalada. Se o Android nao reabrir, toque em Reabrir jogo."
			dialog.confirmed.connect(func(): OS.create_instance(PackedStringArray()))
			return
		dialog.dialog_text="Versao "+version_name+" instalada. O Android nao conseguiu reabrir automaticamente. Abra o jogo novamente."
		dialog.ok_button_text="Fechar jogo"
		dialog.confirmed.connect(func(): get_tree().quit())
	elif OS.get_name() in ["Windows","Linux","macOS"] and not OS.has_feature("editor"):
		OS.set_restart_on_exit(true,OS.get_cmdline_args())
		get_tree().quit()
	else:
		dialog.dialog_text="Versao "+version_name+" instalada. Reabra o jogo para carregar o pacote."
		dialog.confirmed.connect(dialog.queue_free)
	_busy=false

func _offer_apk(version_name: String, download_url: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Nova versao do aplicativo"
	dialog.dialog_text = "A versao %s altera o proprio Android e exige instalacao.\nO Android pedira confirmacao. Nao desinstale a versao atual." % version_name
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
