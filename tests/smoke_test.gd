extends SceneTree
## Teste rapido sem interface para validar as regras basicas.
const World = preload("res://scripts/world.gd")
const Main = preload("res://scripts/main.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _check(condition: bool, description: String) -> void:
	if condition:
		print("OK: ", description)
	else:
		failures += 1
		push_error("FALHOU: " + description)

func _run_tests() -> void:
	var world = World.new()
	world.generate_world()
	_check(world.tiles.size() == World.SIZE and world.tiles[0].size()==World.WIDTH, "Mapa largo gerado")
	_check(not world.sites.is_empty(), "Locais de producao gerados")
	_check(not world.wildlife.is_empty(), "Fauna pacifica gerada")
	_check(world.habitats_v59 and world.wildlife.size()>24,"Fauna dos novos biomas")
	_check(world.towns.size() == 3, "Tres aldeias iniciais")
	# Civilizacoes nao podem evoluir para Era 4 no primeiro ano.
	var rate_world = World.new()
	rate_world.generate_world()
	rate_world.towns[0]["knowledge"] = 1000.0
	rate_world.update_world(0.1)
	_check(int(rate_world.towns[0]["level"]) == 1, "Pesquisa nao permite saltar eras no primeiro ano")
	rate_world.day = 730.0
	rate_world.update_world(0.1)
	_check(int(rate_world.towns[0]["level"]) == 2, "Segunda era depende da passagem de geracoes")


	# Um jogador deve poder mandar construir, ver o trabalho e manter os recursos.
	var building_world = World.new()
	building_world.generate_world()
	var target_town: Dictionary = building_world.towns[0]
	var target_id: int = int(target_town["id"])
	var original_houses: int = int(target_town.get("houses", 2))
	var original_wood: float = float(target_town["wood"])
	_check(not building_world.start_construction(target_id, "bridge"), "Nao aceita construcoes desconhecidas")
	_check(not building_world.start_construction(target_id,"forge"),"Forja exige tecnologia e recursos")
	_check(not bool(target_town.get("oven",false)) and building_world.local_site("oven",target_id).is_empty(),"Forno nao nasce pronto")
	_check(not building_world.start_construction(target_id,"oven"),"Forno exige pedra e madeira")
	_check(not building_world.start_construction(target_id, "house"), "Recusa obra sem madeira")
	target_town["wood"] = 50.0
	_check(building_world.start_construction(target_id, "house"), "Jogador inicia uma casa com recursos")
	_check(float(target_town["wood"]) == 36.0, "Uma casa consome 14 madeiras")
	_check(not building_world.start_construction(target_id, "farm"), "Uma vila so pode executar uma obra por vez")
	_check(int(target_town["houses"]) == original_houses, "Casa nao surge magicamente antes da obra")
	for i in range(150):
		building_world.update_world(0.1)
	_check(int(target_town["houses"]) == original_houses + 1, "A casa fica pronta depois do trabalho")
	_check(target_town.get("construction", {}).is_empty(), "A obra pronta sai da fila")
	_check(target_town.get("historical_events", []).size() > 0, "Obra entra na historia da aldeia")
	var gardener: Dictionary = building_world.people[5]
	_check(str(gardener.get("task", "")) != "", "Morador tem atividade visivel")
	_check(float(gardener.get("work_timer", 0.0)) > 0.0, "Morador possui destino de trabalho")

	var terrain_kinds := {}
	for row in world.tiles:
		for kind in row:
			terrain_kinds[str(kind)] = true
	for biome in ["grass", "forest", "sand", "snow", "mountain", "water"]:
		_check(terrain_kinds.has(biome), "Mapa tem bioma " + biome)
	_check(str(world.towns[0].get("home_biome", "")) != "", "Aldeias guardam o bioma de origem")
	_check(terrain_kinds.size() >= 5, "Mapa possui regioes ecologicas variadas")
	_check(world.people.size() == 18, "Habitantes iniciais")
	_check(float(world.people[3]["age"]) < 16.0, "O mundo ja nasce com criancas")
	_check(int(world.people[3]["father"]) > 0 and int(world.people[3]["mother"]) > 0, "Crianca ja nasce em familia")
	var forest_tiles := 0
	var desert_tiles := 0
	var snow_tiles := 0
	for row in world.tiles:
		for tile in row:
			match str(tile):
				"forest": forest_tiles += 1
				"sand": desert_tiles += 1
				"snow": snow_tiles += 1
	_check(forest_tiles >= 10 and desert_tiles >= 10 and snow_tiles >= 10, "Biomas amplos presentes no mapa")
	# Forca um casal adulto conhecido para testar nascimentos e linhagens.
	var parent_a: Dictionary = world.people[0]
	var parent_b: Dictionary = world.people[1]
	parent_a["gender"] = 0
	parent_b["gender"] = 1
	parent_a["age"] = 26.0
	parent_b["age"] = 25.0
	parent_a["partner"] = parent_b["id"]
	parent_b["partner"] = parent_a["id"]
	var count_before: int = world.people.size()
	world._new_children()
	_check(world.people.size() > count_before, "Casais podem ter filhos")
	for i in range(count_before, world.people.size()):
		var child: Dictionary = world.people[i]
		_check(int(child["father"]) > 0 and int(child["mother"]) > 0, "Criancas tem pais identificaveis")
		_check(int(child["father"]) != int(child["mother"]), "Linhagem usa dois pais diferentes")

	_check(not world.wars and not world.rivals and not world.predators, "Hostilidade desligada por padrao")
	var first_id: int = world.people[0]["id"]
	_check(not world.get_person(first_id).is_empty(), "Identidade individual")
	var start_day: float = world.day
	for i in range(35):
		world.update_world(0.1)
	_check(world.day > start_day, "Simulacao avanca ao jogar")
	_check(world.people[0].has("mind"), "IA inicializa personalidade")
	_check(world.people[0].has("needs"), "IA inicializa necessidades")
	_check(world.people[0].has("profession"), "IA define profissoes")
	_check(world.towns[0].has("diplomacy"), "Diplomacia inicializada")
	var first_town: int = world.towns[0]["id"]
	var second_town: int = world.towns[1]["id"]
	_check(world.politics.get_status(world, first_town, second_town) == "neutral", "Diplomacia comeca neutra")
	_check(world.politics.set_treaty(world, first_town, second_town, "alliance"), "Aliança pode ser formada")
	_check(world.politics.get_status(world, second_town, first_town) == "alliance", "Acordo bilateral")
	_check(world.politics.set_treaty(world, first_town, second_town, "war"), "Guerra declarada manualmente")
	_check(world.politics.get_status(world, first_town, second_town) == "war", "Guerra registrada")
	_check(world.politics.set_treaty(world, first_town, second_town, "peace"), "Paz negociada")
	_check(world.politics.get_status(world, second_town, first_town) == "peace", "Tratado reconhecido pelos dois lados")
	_check(not world.politics.set_treaty(world, first_town, first_town, "war"), "Nao permite guerra contra si mesmo")

	var paused_day: float = world.day
	world.speed = 0.0
	world.update_world(1.0)
	_check(is_equal_approx(world.day, paused_day), "Pausa congela o tempo")
	world.speed = 1.0
	world.toggle_predators()
	_check(world.predators and world.beasts.size() == 8, "Animais ativaveis")
	world.toggle_predators()
	_check(not world.predators, "Animais desativaveis")
	world.toggle_rivals()
	_check(world.rivals and world.towns.size() == 4, "Tribo rival opcional")
	var hostile_found := false
	for t in world.towns:
		if bool(t["hostile"]):
			hostile_found = true
	_check(hostile_found, "Tribo rival realmente hostil")
	_check(world.save_world(), "Salvar mundo localmente")
	var loaded = World.new()
	_check(loaded.load_world(), "Carregar mundo salvo")
	_check(loaded.people.size() == world.people.size(), "Familias persistem entre sessoes")
	_check(is_equal_approx(loaded.day, world.day), "Tempo salvo corretamente")
	_check(loaded.rivals == world.rivals, "Preferencias salvas")
	_check(loaded.politics.get_status(loaded, first_town, second_town) == "peace", "Tratados persistem entre sessoes")
	_check(loaded.towns[0].has("historical_events"), "Eventos historicos persistem")

	var leader_id: int = loaded.towns[0]["leader"]
	var leader: Dictionary = loaded.get_person(leader_id)
	loaded.kill_person(leader)
	_check(not bool(leader["alive"]), "Morte de lider")
	_check(int(loaded.towns[0]["leader"]) != leader_id, "Sucessao de lideranca")
	# Exercita a janela de diplomacia em modo headless para verificar controles reais.
	var game: Node2D = Main.new()
	root.add_child(game)
	_check(not game.texture_missing, "Todos os desenhos de pixel art foram importados")
	_check(game.tile_textures.size() == 9, "Nove imagens de terrenos e estacoes carregadas")
	_check(game.actor_textures.size() == 8, "Oito sprites de pessoas, aldeias e animais carregados")
	_check(int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 1280, "Tela horizontal configurada")
	_check(game.MAP_AREA.size.x > 1200.0 and game.MAP_AREA.size.y > 600.0, "Mapa quase preenche a tela horizontal")
	_check(not is_instance_valid(game.viewport_3d), "Jogo exclusivamente 2D")
	_check(is_instance_valid(game.view_button), "Controle direto no mapa")
	game.call("_toggle_view")
	_check(game.controlled_id>0 and game.action_button.visible, "Controle e coleta no mapa")
	game.call("_toggle_view")
	_check(game.controlled_id==0 and not game.action_button.visible, "Mapa limpo ao soltar")
	game.call("_focus_biome", "snow")
	_check(not game.character_view, "Atalho para clima frio retorna ao mapa")
	_check(str(ProjectSettings.get_setting("autoload/PatchLoader", "")).contains("patch_loader.gd"), "Pacotes do jogo carregam antes da tela inicial")
	_check(game.tile_textures.size() >= 9, "Arte do mundo continua disponivel")
	var zoom_buttons_found := false
	for child in game.get_children():
		if child is Button and str(child.text).begins_with("Zoom"):
			zoom_buttons_found = true
	_check(not zoom_buttons_found, "Tela nao possui botao de zoom, gestos multitouch assumem a funcao")
	_check(game.has_method("_draw_clock"), "Relogio visual do tempo existe")
	game.call("_toggle_view")
	_check(game.controlled_id>0, "Controle de personagem no mapa")
	game.call("_toggle_view")
	_check(game.controlled_id==0, "Jogador pode soltar personagem")
	game.call("_show_construction")
	var construction_dialog_found := false
	for popup in game.get_children():
		if popup is ConfirmationDialog and popup.title == "Construir na aldeia":
			construction_dialog_found = true
	_check(construction_dialog_found, "Jogador consegue abrir escolha de casas e fazendas")
	_check(game._preferred_town_id() > 0, "Botao construir encontra uma aldeia proxima")
	game.call("_show_diplomacy")
	var found_window := false
	for child in game.get_children():
		if child is ConfirmationDialog and child.title == "Diplomacia entre aldeias":
			found_window = true
	_check(found_window, "Janela de diplomacia abre com controles reais")
	game.call("_show_options")
	var options_found := false
	for child in game.get_children():
		if child is PopupMenu:
			options_found = true
	_check(options_found, "Menu de opcoes acessivel ao jogador")
	_check(game.update_manager._manifest_url == "https://raw.githubusercontent.com/contateste123455667788994321-max/legados-das-eras/main/manifest.json", "Atualizador usa canal HTTPS oficial")
	_check(game.update_manager._is_https(game.update_manager._manifest_url), "Canal de atualizacao tem endereco seguro")
	_check(game.update_manager._base_version_code == 4, "APK base suporta futuros pacotes internos")
	var update_button_found := false
	for child in game.get_children():
		if child is Button and child.text == "Atualizar":
			update_button_found = true
	_check(update_button_found, "Botao Atualizar acessivel diretamente no jogo")

	# Valida o fluxo real do atualizador ZIP -> PCK, sem rede e sem trocar o APK.
	var updates_dir := ProjectSettings.globalize_path("user://updates")
	_check(DirAccess.make_dir_recursive_absolute(updates_dir) == OK, "Pasta para atualizacoes disponivel")
	var downloaded_zip := "user://updates/download.bin"
	var writer := ZIPPacker.new()
	var open_result: Error = writer.open(downloaded_zip)
	_check(open_result == OK, "Criar pacote ZIP de teste")
	if open_result == OK:
		var zip_entry := "Legado-das-Eras-conteudo.pck"
		_check(writer.start_file(zip_entry) == OK, "Criar entrada PCK no ZIP")
		var stub := "PACOTE-DE-TESTE-LEGADO".to_utf8_buffer()
		_check(writer.write_file(stub) == OK, "Gravar conteudo do ZIP")
		writer.close_file()
		writer.close()
		var size_file := FileAccess.open(downloaded_zip, FileAccess.READ)
		var compressed_size: int = size_file.get_length()
		size_file.close()
		game.update_manager._next_patch = {
			"pack_format": "zip",
			"pack_sha256": FileAccess.get_sha256(downloaded_zip),
			"pack_pck_sha256": "",
			"pack_bytes": compressed_size,
			"version_code": 5,
			"version_name": "0.5.0-teste",
			"min_apk_code": 4
		}
		game.update_manager._on_patch_received(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray())
		var local_pack := "user://updates/active.pck"
		_check(FileAccess.file_exists(local_pack), "ZIP extraido e ativado dentro do jogo")
		var installed_meta := FileAccess.get_file_as_string("user://updates/active.json")
		var parsed = JSON.parse_string(installed_meta)
		_check(typeof(parsed) == TYPE_DICTIONARY and int(parsed.get("version_code", 0)) == 5, "Atualizacao interna registra versao instalada")
		_check(typeof(parsed) == TYPE_DICTIONARY and str(parsed.get("sha256", "")) == FileAccess.get_sha256(local_pack), "Pacote interno recebe hash correto")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(local_pack))
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://updates/active.json"))

	game.queue_free()

	if failures == 0:
		print("SUCESSO: todos os testes basicos passaram.")
	else:
		push_error(str(failures) + " testes falharam.")
	quit(0 if failures == 0 else 1)
