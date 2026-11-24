extends SceneTree
## Jogadores simulados em jobs isolados no CI. Nao sao conexoes multiplayer.
## Invariantes + acoes de quatro perfis: observador, construtor, explorador e caos.
const World = preload("res://scripts/world.gd")
const Main = preload("res://scripts/main.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _assert(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("JOGADOR SIMULADO: " + description)

func _new_world(seed_value: int):
	var sim = World.new()
	sim.generate_world()
	sim.rng.seed = seed_value
	return sim

func _check_world(sim, profile: String) -> void:
	_assert(sim.towns.size() >= 3, profile + ": aldeias ainda existem")
	_assert(sim.tiles.size() == World.SIZE, profile + ": mapa nao desapareceu")
	var ids := {}
	for p in sim.people:
		var id: int = int(p["id"])
		_assert(not ids.has(id), profile + ": habitante possui ID unico")
		ids[id] = true
		_assert(float(p["age"]) >= 0.0 and float(p["age"]) < 200.0, profile + ": idade valida")
		var tx: float = float(p["x"])
		var ty: float = float(p["y"])
		_assert(tx >= 0.0 and tx < World.WIDTH and ty >= 0.0 and ty < World.SIZE, profile + ": habitante dentro do mapa")
		if int(p["father"]) > 0:
			_assert(not sim.get_person(int(p["father"])).is_empty(), profile + ": pai referenciado existe")
		if int(p["mother"]) > 0:
			_assert(not sim.get_person(int(p["mother"])).is_empty(), profile + ": mae referenciada existe")
	for town in sim.towns:
		_assert(float(town["food"]) >= -0.001, profile + ": estoque de comida nao fica negativo")
		_assert(float(town["wood"]) >= -0.001, profile + ": madeira nao fica negativa")
		_assert(not sim.get_town(int(town["id"])).is_empty(), profile + ": vila pode ser consultada")
		if int(town["leader"]) > 0:
			var leader: Dictionary = sim.get_person(int(town["leader"]))
			_assert(not leader.is_empty() and bool(leader["alive"]), profile + ": governante vivo")
	for a in sim.towns:
		for b in sim.towns:
			if int(a["id"]) != int(b["id"]):
				_assert(sim.politics.get_status(sim, int(a["id"]), int(b["id"])) == sim.politics.get_status(sim, int(b["id"]), int(a["id"])), profile + ": tratados sao bilaterais")

func _observer() -> void:
	var w = _new_world(10)
	var start: float = w.day
	for i in range(120):
		w.update_world(0.1)
	_assert(w.day > start, "Observador: tempo avanca quando rodando")
	_assert(w.day < start + 10.0, "Observador: anos nao saltam em segundos")
	_assert(w.day <= 120.0 * 0.1 * World.DAYS_PER_REAL_SECOND + 0.05, "Observador: calendario segue relogio")
	var paused: float = w.day
	var age: float = float(w.people[0]["age"])
	w.speed = 0.0
	for i in range(100):
		w.update_world(0.1)
	_assert(is_equal_approx(w.day, paused), "Observador: pausa congela calendario")
	_assert(is_equal_approx(float(w.people[0]["age"]), age), "Observador: pausa congela envelhecimento")
	w.speed = 5.0
	for i in range(60):
		w.update_world(0.1)
	_assert(w.day > paused, "Observador: 5x avanca com velocidade escolhida")
	_check_world(w, "Observador")

func _builder() -> void:
	var w = _new_world(20)
	var first: int = int(w.towns[0]["id"])
	var second: int = int(w.towns[1]["id"])
	var initial_food: float = float(w.towns[0]["food"])
	w._grow_economies()
	_assert(float(w.towns[0]["food"]) >= initial_food, "Construtor: colheita fornece alimento")
	_assert(w.politics.set_treaty(w, first, second, "alliance"), "Construtor: consegue assinar alianca")
	_assert(w.politics.get_status(w, second, first) == "alliance", "Construtor: alianca reciproca")
	_assert(w.politics.set_treaty(w, first, second, "war"), "Construtor: consegue declarar guerra")
	_assert(w.politics.set_treaty(w, first, second, "peace"), "Construtor: consegue terminar guerra")
	for i in range(2):
		w._new_children()
	_assert(w.people.size() >= 18, "Construtor: geracoes sem apagar moradores")
	for i in range(200):
		w.update_world(0.1)
	_assert(w.save_world(), "Construtor: progresso foi salvo")
	var loaded = World.new()
	_assert(loaded.load_world(), "Construtor: mundo reabre")
	_assert(loaded.people.size() == w.people.size(), "Construtor: familias sobrevivem ao carregamento")
	_assert(is_equal_approx(loaded.day, w.day), "Construtor: mesmo dia ao reabrir")
	_assert(loaded.politics.get_status(loaded, first, second) == "peace", "Construtor: tratado persistiu")
	_check_world(loaded, "Construtor")

func _finger(game: Node2D, id: int, pos: Vector2, pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = id
	touch.position = pos
	touch.pressed = pressed
	game._unhandled_input(touch)

func _drag(game: Node2D, id: int, pos: Vector2, movement: Vector2) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = id
	drag.position = pos
	drag.relative = movement
	game._unhandled_input(drag)

func _explorer() -> void:
	var game = Main.new()
	root.add_child(game)
	game.set_process(false)
	game.world.generate_world()
	game.zoom = 1.0
	game._clamp_map()
	var orig: float = game.zoom
	_finger(game, 0, Vector2(375, 245), true)
	_finger(game, 1, Vector2(475, 245), true)
	_drag(game, 0, Vector2(330, 245), Vector2(-45, 0))
	_drag(game, 1, Vector2(520, 245), Vector2(45, 0))
	_assert(game.zoom > orig, "Explorador: zoom de pinça funciona")
	_assert(game.zoom <= 3.5, "Explorador: zoom nao extrapola limite")
	_finger(game, 0, Vector2(330, 245), false)
	_finger(game, 1, Vector2(520, 245), false)
	_assert(game.active_touches.is_empty(), "Explorador: dedos sao liberados corretamente")
	_assert(not game.dragging, "Explorador: sem arrasto preso depois de pincar")
	var larger: float = game.zoom
	_finger(game, 0, Vector2(360, 230), true)
	_finger(game, 1, Vector2(540, 230), true)
	_drag(game, 0, Vector2(412, 230), Vector2(52, 0))
	_drag(game, 1, Vector2(488, 230), Vector2(-52, 0))
	_assert(game.zoom < larger, "Explorador: pinça inversa reduz zoom")
	_finger(game, 0, Vector2(412, 230), false)
	_finger(game, 1, Vector2(488, 230), false)
	game._zoom_around(game.MAP_AREA.get_center(), 20.0)
	_assert(is_equal_approx(game.zoom, 3.5), "Explorador: zoom maximo respeitado")
	game._zoom_around(game.MAP_AREA.get_center(), 0.01)
	_assert(is_equal_approx(game.zoom, maxf(game.MAP_AREA.size.x / (float(World.WIDTH) * game.TILE_SIZE), game.MAP_AREA.size.y / (float(World.SIZE) * game.TILE_SIZE))), "Explorador: zoom minimo respeitado")
	game._toggle_pause()
	_assert(game.world.speed == 0.0, "Explorador: pausa ativada")
	game._change_speed()
	_assert(game.world.speed == 0.0, "Explorador: velocidade nao despausa sem pedir")
	game._toggle_pause()
	_assert(game.world.speed == 2.0, "Explorador: retorna com velocidade selecionada")
	game._change_speed()
	_assert(game.world.speed == 4.0, "Explorador: avanco 4x disponivel")
	game._change_speed()
	_assert(game.world.speed == 0.5, "Explorador: camera lenta 0.5x disponivel")
	game._change_speed()
	_assert(game.world.speed == 1.0, "Explorador: retorna ao ritmo normal")
	game._toggle_view()
	_assert(game.character_view, "Explorador: entra na visao do personagem")
	_assert(game.viewport_3d.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Explorador: renderizacao 3D ligada")
	_assert(game.character_world.actors_3d.size() >= 18, "Explorador: habitantes aparecem e se movimentam no mundo 3D")

	var controlled: Dictionary = game.world.get_actor(game.controlled_id)
	controlled["x"] = 10.0
	controlled["y"] = 10.0
	game.world.tiles[10][10] = "grass"
	game.world.tiles[9][10] = "grass"
	game.world.tiles[9][9] = "grass"
	game.joystick_direction = Vector2(0, -1)
	game.look_yaw = 0.0
	game._move_controlled(0.2)
	_assert(float(controlled["y"]) < 10.0, "Explorador: analogico move personagem no mundo 3D")
	game.look_yaw = PI * 0.5
	var old_x: float = float(controlled["x"])
	game._move_controlled(0.2)
	_assert(float(controlled["x"]) < old_x, "Explorador: personagem muda direcao junto com a camera")
	game.joystick_direction = Vector2.ZERO
	game.look_pitch = -0.21
	game.character_world.follow(controlled, game.look_yaw, game.look_pitch)
	_assert(is_equal_approx(game.character_world.camera.rotation.x, -0.21), "Explorador: camera olha para cima e baixo")
	_assert(game.character_world.camera.position.x > 0.0, "Explorador: camera 3D acompanha corpo do personagem")
	_assert(game.action_button.visible and game.inventory_button.visible, "Explorador: acoes e inventario aparecem apenas no 3D")
	controlled["x"] = 9.5
	controlled["y"] = 9.5
	game.world.tiles[9][9] = "forest"
	game.world.trees.clear()
	game.world._plant_tree(9,9,true)
	game.world.trees["9:9"]["ox"] = 0.5
	game.world.trees["9:9"]["oy"] = 0.5
	var previous_wood: int = int(controlled.get("wood", 0))
	game._character_action()
	_assert(int(controlled.get("wood", 0)) == previous_wood + 3, "Explorador: coletar madeira realmente altera inventario")
	_assert(str(game.world.trees["9:9"]["state"]) == "falling", "Explorador: arvore entra em animacao ao cortar")
	game.world._update_trees(1.2)
	_assert(str(game.world.trees["9:9"]["state"]) == "stump", "Explorador: arvore cortada vira toco")
	game.world.tiles[9][9] = "mountain"
	var previous_stone: int = int(controlled.get("stone", 0))
	game._character_action()
	_assert(int(controlled.get("stone", 0)) == previous_stone + 2, "Explorador: coleta de pedra entra na mochila")
	game.world.tiles[9][9] = "water"
	var previous_water: int = int(controlled.get("water", 0))
	game._character_action()
	_assert(int(controlled.get("water", 0)) == previous_water + 2, "Explorador: coleta de agua entra na mochila")
	game._show_inventory()
	var inventory_open := false
	for overlay in game.get_children():
		if overlay is AcceptDialog and overlay.title == "Inventario":
			inventory_open = true
	_assert(inventory_open, "Explorador: inventario abre durante a caminhada")


	game._toggle_view()
	_assert(not game.character_view, "Explorador: volta ao mapa")
	_assert(game.viewport_3d.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Explorador: voltar economiza bateria")
	_assert(not game.action_button.visible and not game.inventory_button.visible, "Explorador: mapa fica limpo sem botoes de inventario")
	game.queue_free()

func _chaos() -> void:
	for session in range(12):
		var w = _new_world(3000 + session)
		if session % 2 == 0:
			w.toggle_predators()
		if session % 3 == 0:
			w.toggle_rivals()
			w.wars = true
		var first: int = int(w.towns[0]["id"])
		var second: int = int(w.towns[1]["id"])
		w.politics.set_treaty(w, first, second, "war" if session % 2 == 0 else "alliance")
		for tick in range(240):
			if tick == 90:
				w.speed = 5.0
			if tick == 130:
				w.speed = 0.0
			if tick == 135:
				w.speed = 1.0
			w.update_world(0.1)
			if tick % 80 == 0:
				_check_world(w, "Caos %d" % session)
		_check_world(w, "Caos final %d" % session)
		_assert(w.day < 150.0, "Caos: nenhum mundo envelhece anos em segundos")

func _historian() -> void:
	var w = _new_world(50)
	var child: Dictionary = w.people[3]
	_assert(float(child["age"]) < 16.0, "Historiador: aldeias nascem com criancas")
	_assert(int(child["father"]) > 0 and int(child["mother"]) > 0, "Historiador: crianca tem dois progenitores registrados")
	_assert(not w.get_person(int(child["father"])).is_empty(), "Historiador: pai existe")
	_assert(not w.get_person(int(child["mother"])).is_empty(), "Historiador: mae existe")
	var town: Dictionary = w.towns[0]
	var leader_id: int = int(town["leader"])
	var leader: Dictionary = w.get_person(leader_id)
	w.kill_person(leader)
	_assert(not bool(leader["alive"]), "Historiador: morte de governante registrada")
	_assert(int(town["leader"]) != leader_id, "Historiador: sucessao muda lider")
	_assert(int(town["leader"]) > 0, "Historiador: aldeia nao fica sem governante quando ha adultos")
	var successor: Dictionary = w.get_person(int(town["leader"]))
	_assert(str(successor["role"]) == "Rei" or str(successor["role"]) == "Rainha", "Historiador: herdeiro recebe titulo")
	_check_world(w, "Historiador")

func _diplomat() -> void:
	var w = _new_world(60)
	var a: int = int(w.towns[0]["id"])
	var b: int = int(w.towns[1]["id"])
	for kind in ["alliance", "war", "peace"]:
		_assert(w.politics.set_treaty(w, a, b, kind), "Diplomata: consegue estabelecer " + kind)
		_assert(w.politics.get_status(w, a, b) == kind, "Diplomata: acordo ativo de um lado")
		_assert(w.politics.get_status(w, b, a) == kind, "Diplomata: acordo ativo do outro lado")
	_assert(not w.politics.set_treaty(w, a, a, "war"), "Diplomata: impede guerra contra si mesmo")
	_assert(not w.politics.set_treaty(w, a, 999999, "war"), "Diplomata: ignora reino inexistente")
	_assert(w.towns[0].get("historical_events", []).size() >= 3, "Diplomata: registra historico politico")
	_check_world(w, "Diplomata")

func _ecologist() -> void:
	var w = _new_world(70)
	var counts := {"forest": 0, "sand": 0, "snow": 0, "water": 0}
	for row in w.tiles:
		for tile in row:
			if counts.has(str(tile)):
				counts[str(tile)] = int(counts[str(tile)]) + 1
	for key in counts.keys():
		_assert(int(counts[key]) >= 10, "Ecologista: bioma " + str(key) + " forma regiao visivel")
	var town: Dictionary = w.towns[0]
	var old_food: float = float(town["food"])
	w._grow_economies()
	_assert(float(town["food"]) >= old_food, "Ecologista: alimentos aumentam na colheita")
	for i in range(160):
		w.update_world(0.1)
	_check_world(w, "Ecologista")

func _survivor() -> void:
	var w = _new_world(80)
	_assert(not w.predators, "Sobrevivente: animais perigosos comecam desligados")
	w.toggle_predators()
	_assert(w.predators and w.beasts.size() == 8, "Sobrevivente: predadores so aparecem quando ativados")
	var beast: Dictionary = w.beasts[0]
	var id: int = int(beast["id"])
	_assert(not w.get_beast(id).is_empty(), "Sobrevivente: animais mantem identidade")
	w.toggle_predators()
	_assert(not w.predators, "Sobrevivente: ataques desativados ao desligar opcao")
	w.toggle_rivals()
	_assert(w.rivals and w.towns.size() == 4, "Sobrevivente: povo rival pode surgir")
	w.wars = true
	for i in range(180):
		w.update_world(0.1)
	_check_world(w, "Sobrevivente")

func _artist() -> void:
	var game = Main.new()
	root.add_child(game)
	game.set_process(false)
	_assert(game.tile_textures.size() >= 9, "Artista: terrenos e estacoes possuem imagens reais")
	_assert(game.actor_textures.size() >= 8, "Artista: personagens, construcoes e bichos possuem sprites")
	_assert(not game.texture_missing, "Artista: recursos visuais nao faltam")
	_assert(game.MAP_AREA.size.x > 650.0 and game.MAP_AREA.size.y > 350.0, "Artista: mapa tem espaco suficiente")
	_assert(float(World.WIDTH) * game.TILE_SIZE * game.zoom >= game.MAP_AREA.size.x, "Artista: mapa preenche a tela com zoom inicial")
	_assert(game.MAP_AREA.size.y >= 600.0, "Artista: faixa inferior nao rouba area de jogo")
	_assert(game.character_world != null and game.character_world.camera != null, "Artista: cena de personagem usa camera tridimensional real")
	_assert(game.has_method("_draw_clock"), "Artista: relogio ilustrado permanece funcional")
	for filename in ["person_m", "person_f", "child"]:
		var file: FileAccess = FileAccess.open("res://assets/sprites/" + filename + ".svg", FileAccess.READ)
		_assert(file != null, "Artista: sprite " + filename + " esta presente")
		if file != null:
			_assert(file.get_length() >= 900, "Artista: sprite " + filename + " tem desenho detalhado e camadas")
			file.close()
	game.queue_free()

func _impatient() -> void:
	var game = Main.new()
	root.add_child(game)
	game.set_process(false)
	game.world.generate_world()
	var start: float = game.world.day
	for i in range(25):
		game._zoom_around(game.MAP_AREA.get_center(), 0.1 if i % 2 == 0 else 30.0)
		_assert(game.zoom >= maxf(game.MAP_AREA.size.x / (float(World.WIDTH) * game.TILE_SIZE), game.MAP_AREA.size.y / (float(World.SIZE) * game.TILE_SIZE)) - 0.001 and game.zoom <= 3.5, "Impaciente: zoom repetido sem travar")
	game._toggle_pause()
	var paused: float = game.world.day
	for i in range(80):
		game.world.update_world(0.1)
	_assert(is_equal_approx(game.world.day, paused), "Impaciente: tempo parado mesmo apos varias entradas")
	game._change_speed()
	game._toggle_pause()
	for i in range(100):
		game.world.update_world(0.1)
	_assert(game.world.day > start, "Impaciente: simulacao retoma")
	_assert(game.world.day < start + 30.0, "Impaciente: fast-forward nao pula anos")
	_assert(game.world.save_world(), "Impaciente: jogo continua salvando")
	_check_world(game.world, "Impaciente")
	game.queue_free()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var profile := str(args[0]) if args.size() > 0 else "all"
	print("Iniciando testes de jogador simulado: ", profile)
	match profile:
		"observer": _observer()
		"builder": _builder()
		"explorer": _explorer()
		"chaos": _chaos()
		"historian": _historian()
		"diplomat": _diplomat()
		"ecologist": _ecologist()
		"survivor": _survivor()
		"artist": _artist()
		"impatient": _impatient()
		"all":
			_observer()
			_builder()
			_explorer()
			_chaos()
			_historian()
			_diplomat()
			_ecologist()
			_survivor()
			_artist()
			_impatient()
		_:
			_assert(false, "Perfil desconhecido: " + profile)
	if failures == 0:
		print("SUCESSO: jogador ", profile, " passou em ", checks, " verificacoes.")
	else:
		push_error("%d problemas em %d verificacoes do perfil %s" % [failures, checks, profile])
	quit(0 if failures == 0 else 1)
