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
	_check(world.tiles.size() == World.SIZE, "Mapa gerado")
	_check(world.towns.size() == 3, "Tres aldeias iniciais")
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
	_check(is_instance_valid(game.preview_visual) and game.preview_visual.preview_mode, "Visao do personagem aparece no painel lateral")
	_check(game.RIGHT_VIEW.position.x > game.MAP_AREA.end.x, "Mapa e perspectiva aparecem lado a lado")
	_check(is_instance_valid(game.view_button), "Botao de explorar o mundo existe")
	game.call("_toggle_view")
	_check(game.character_view and game.character_clip.visible, "O jogador entra na visao do personagem")
	game.call("_toggle_view")
	_check(not game.character_view and not game.character_clip.visible, "O jogador retorna ao mapa")
	game.call("_focus_biome", "snow")
	_check(not game.character_view, "Atalho para clima frio retorna ao mapa")
	_check(str(ProjectSettings.get_setting("autoload/PatchLoader", "")).contains("patch_loader.gd"), "Pacotes do jogo carregam antes da tela inicial")
	_check(game.preview_visual != null, "Visao do personagem aparece junto do mapa")
	game.call("_toggle_view")
	_check(game.character_view, "Visao de personagem pode ser ativada")
	game.call("_toggle_view")
	_check(not game.character_view, "Jogador pode retornar ao mapa")
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
	_check(game.update_manager._manifest_url == "https://legado-das-eras.hatchable.site/manifest.json", "Atualizador usa canal HTTPS oficial")
	_check(game.update_manager._is_https(game.update_manager._manifest_url), "Canal de atualizacao tem endereco seguro")
	_check(game.update_manager._base_version_code == 4, "APK base suporta futuros pacotes internos")
	var update_button_found := false
	for child in game.get_children():
		if child is Button and child.text == "Atualizar":
			update_button_found = true
	_check(update_button_found, "Botao Atualizar acessivel diretamente no jogo")
	game.queue_free()

	if failures == 0:
		print("SUCESSO: todos os testes basicos passaram.")
	else:
		push_error(str(failures) + " testes falharam.")
	quit(0 if failures == 0 else 1)
