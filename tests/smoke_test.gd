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
	_check(world.people.size() == 18, "Habitantes iniciais")
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
	if failures == 0:
		print("SUCESSO: todos os testes basicos passaram.")
	else:
		push_error(str(failures) + " testes falharam.")
	quit(0 if failures == 0 else 1)
