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
		_assert(tx >= 0.0 and tx < World.SIZE and ty >= 0.0 and ty < World.SIZE, profile + ": habitante dentro do mapa")
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
	_assert(is_equal_approx(game.zoom, 0.55), "Explorador: zoom minimo respeitado")
	game._toggle_pause()
	_assert(game.world.speed == 0.0, "Explorador: pausa ativada")
	game._change_speed()
	_assert(game.world.speed == 0.0, "Explorador: velocidade nao despausa sem pedir")
	game._toggle_pause()
	_assert(game.world.speed == 2.0, "Explorador: retorna com velocidade selecionada")
	game._toggle_view()
	_assert(game.character_view, "Explorador: entra na visao do personagem")
	game._toggle_view()
	_assert(not game.character_view, "Explorador: volta ao mapa")
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

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var profile := str(args[0]) if args.size() > 0 else "all"
	print("Iniciando testes de jogador simulado: ", profile)
	match profile:
		"observer": _observer()
		"builder": _builder()
		"explorer": _explorer()
		"chaos": _chaos()
		"all":
			_observer()
			_builder()
			_explorer()
			_chaos()
		_:
			_assert(false, "Perfil desconhecido: " + profile)
	if failures == 0:
		print("SUCESSO: jogador ", profile, " passou em ", checks, " verificacoes.")
	else:
		push_error("%d problemas em %d verificacoes do perfil %s" % [failures, checks, profile])
	quit(0 if failures == 0 else 1)
