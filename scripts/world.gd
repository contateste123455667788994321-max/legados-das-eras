extends RefCounted
class_name WorldSim

const AgentAI = preload("res://scripts/ai.gd")
const Politics = preload("res://scripts/politics.gd")
const SIZE := 20
const NAMES := ["Ari", "Nara", "Taro", "Lia", "Breno", "Iara", "Dara", "Enzo", "Kira", "Suri", "Davi", "Maya", "Ravi", "Luna", "Rael", "Yara", "Cael", "Tina", "Eron", "Ayla"]
var rng := RandomNumberGenerator.new()
var agent_ai = AgentAI.new()
var politics = Politics.new()
var tiles: Array = []
var towns: Array = []
var people: Array = []
var beasts: Array = []
var next_id := 1
var day := 0.0
var next_birth := 120.0
var next_growth := 80.0
var wars := false
var rivals := false
var predators := false
var speed := 1.0
var news := "Um novo mundo nasceu."

func new_id() -> int:
	var value := next_id
	next_id += 1
	return value

func generate_world() -> void:
	agent_ai.elapsed = 0.0
	politics.elapsed = 0.0
	rng.randomize()
	tiles.clear()
	towns.clear()
	people.clear()
	beasts.clear()
	next_id = 1
	day = 0.0
	next_birth = 120.0
	next_growth = 80.0
	wars = false
	rivals = false
	predators = false
	# Biomas agrupados em regioes naturais, com um rio sinuoso.
	# Antes eram quadrados aleatorios; agora o territorio influencia a historia.
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi_range(1000, 900000)
	noise.frequency = 0.115
	for y in range(SIZE):
		var row: Array = []
		for x in range(SIZE):
			var variation: float = noise.get_noise_2d(float(x), float(y))
			var river_center: float = 3.0 + 0.55 * float(y) + sin(float(y) * 0.55) * 1.15
			var from_river: float = absf(float(x) - river_center)
			var biome := "grass"
			if from_river < 0.72:
				biome = "water"
			elif from_river < 1.45:
				biome = "sand"
			elif x >= 13 and y <= 9:
				biome = "snow" if y <= 4 or variation > -0.02 else "mountain"
			elif x >= 13 and y >= 11:
				biome = "sand" if variation < 0.34 else "mountain"
			elif x <= 10 and y <= 12:
				biome = "forest" if variation > -0.43 else "grass"
			elif x <= 6 and y >= 13:
				biome = "forest" if variation > -0.17 else "grass"
			elif variation > 0.55:
				biome = "forest"
			row.append(biome)
		tiles.append(row)
	make_town("Vale Verde", 5, 5, false)
	make_town("Pedra Alta", 15, 5, false)
	make_town("Campo do Sol", 16, 15, false)
	politics.prepare(self)
	news = "Tres aldeias vivem em paz. Voce decide o futuro."

func make_town(town_name: String, x: int, y: int, hostile: bool) -> void:
	var town_id := new_id()
	var home_biome: String = str(tiles[y][x])
	var wood_start: float = 18.0 if home_biome == "forest" else (7.0 if home_biome == "sand" else 12.0)
	var food_start: float = 17.0 if home_biome == "sand" or home_biome == "snow" else 25.0
	var town := {
		"id": town_id, "name": town_name, "x": x, "y": y,
		"hostile": hostile, "leader": 0, "food": food_start,
		"wood": wood_start, "knowledge": 0.0, "level": 1,
		"home_biome": home_biome, "law": "primogenitura"
	}
	towns.append(town)
	tiles[y][x] = "grass"
	for i in range(6):
		var person_id := make_person(town_id, float(x) + rng.randf_range(-1.0, 1.0), float(y) + rng.randf_range(-1.0, 1.0), rng.randi_range(17, 48))
		if i == 0:
			town["leader"] = person_id
			var ruler: Dictionary = get_person(person_id)
			ruler["role"] = "Rei" if int(ruler["gender"]) == 0 else "Rainha"
	# Cada aldeia nasce com um casal adulto e linhagens consistentes.
	var men: Array = []
	var women: Array = []
	for i in range(people.size() - 6, people.size()):
		var settler: Dictionary = people[i]
		if int(settler["gender"]) == 0:
			men.append(settler)
		else:
			women.append(settler)
	if men.is_empty():
		var first_man: Dictionary = people[people.size() - 6]
		first_man["gender"] = 0
		women.erase(first_man)
		men.append(first_man)
	if women.is_empty():
		var first_woman: Dictionary = people[people.size() - 5]
		first_woman["gender"] = 1
		men.erase(first_woman)
		women.append(first_woman)
	var father: Dictionary = men[0]
	var mother: Dictionary = women[0]
	father["partner"] = mother["id"]
	mother["partner"] = father["id"]
	var ruler: Dictionary = get_person(int(town["leader"]))
	ruler["role"] = "Rei" if int(ruler["gender"]) == 0 else "Rainha"

func make_person(town_id: int, x: float, y: float, age: int = 20, father: int = 0, mother: int = 0) -> int:
	var person_id := new_id()
	var gender := rng.randi_range(0, 1)
	var person := {
		"id": person_id, "name": NAMES[rng.randi_range(0, NAMES.size() - 1)] + " " + str(person_id),
		"town": town_id, "x": x, "y": y, "age": float(age),
		"gender": gender, "father": father, "mother": mother,
		"partner": 0, "role": "Aldeao", "alive": true,
		"health": 100.0, "wood": 0, "food": 2,
		"temper": rng.randi_range(0, 100), "color": rng.randi_range(0, 5),
		"wander": rng.randf_range(0.2, 2.0), "target_x": x, "target_y": y
	}
	people.append(person)
	return person_id

func get_person(person_id: int) -> Dictionary:
	for p in people:
		if int(p["id"]) == person_id:
			return p
	return {}

func get_beast(beast_id: int) -> Dictionary:
	for b in beasts:
		if int(b["id"]) == beast_id:
			return b
	return {}

func get_actor(actor_id: int) -> Dictionary:
	var person := get_person(actor_id)
	if not person.is_empty():
		return person
	return get_beast(actor_id)

func get_town(town_id: int) -> Dictionary:
	for t in towns:
		if int(t["id"]) == town_id:
			return t
	return {}

func toggle_rivals() -> void:
	rivals = not rivals
	if rivals:
		var any_hostile := false
		for town in towns:
			if bool(town["hostile"]):
				any_hostile = true
		if not any_hostile:
			make_town("Clã das Cinzas", 15, 14, true)
		politics.prepare(self)
		news = "A tribo rival esta ativa e tambem evolui."
	else:
		news = "Tribos rivais desativadas: nao atacarao."
	
func toggle_predators() -> void:
	predators = not predators
	if predators and beasts.is_empty():
		for i in range(8):
			var breed := "Lobo" if i < 6 else "Urso"
			beasts.append({
				"id": new_id(), "name": breed + " " + str(i + 1), "species": breed,
				"x": rng.randf_range(2.0, SIZE - 3.0),
				"y": rng.randf_range(2.0, SIZE - 3.0),
				"health": 90.0 if breed == "Urso" else 55.0,
				"food": 4, "wander": rng.randf_range(0.0, 3.0),
				"target_x": 8.0, "target_y": 8.0, "alive": true,
				"temper": rng.randi_range(0, 100), "color": rng.randi_range(0, 4)
			})
	news = "Predadores ativos." if predators else "Ataques de animais desativados."

func update_world(delta: float, controlled_id: int = 0) -> void:
	if speed <= 0:
		return
	var dt := minf(delta, 0.1) * speed
	day += dt * 18.0
	for t in towns:
		t["knowledge"] = float(t["knowledge"]) + dt * (0.024 + active_population(int(t["id"])) * 0.003)
		var new_level := 1 + int(float(t["knowledge"]) / 15.0)
		if new_level > int(t["level"]):
			t["level"] = mini(new_level, 5)
			news = str(t["name"]) + " avancou para a era " + str(t["level"]) + "!"
	for p in people:
		if not bool(p["alive"]):
			continue
		p["age"] = float(p["age"]) + dt * 18.0 / 365.0
		if float(p["age"]) > 79 and rng.randf() < dt * 0.015:
			kill_person(p)
			continue
		if int(p["id"]) != controlled_id:
			_wander(p, dt, 0.65)
	for b in beasts:
		if bool(b["alive"]) and int(b["id"]) != controlled_id:
			_wander(b, dt, 1.0)
	if day >= next_growth:
		next_growth += 80.0
		_grow_economies()
	if day >= next_birth:
		next_birth += 120.0
		_new_children()
	politics.advance(self, dt)
	if predators:
		_predator_attacks(dt)
	# IA local atualiza necessidades, trabalhos, relacionamentos e aldeias.
	# Usa tempo da simulacao: pausa impede progresso e fechar o app nao avanca o mundo.
	agent_ai.advance(self, dt, controlled_id)

func _wander(actor: Dictionary, dt: float, pace: float) -> void:
	actor["wander"] = float(actor["wander"]) - dt
	if float(actor["wander"]) <= 0.0:
		actor["target_x"] = clampf(float(actor["x"]) + rng.randf_range(-2.0, 2.0), 2.0, float(SIZE - 3))
		actor["target_y"] = clampf(float(actor["y"]) + rng.randf_range(-2.0, 2.0), 2.0, float(SIZE - 3))
		actor["wander"] = rng.randf_range(1.5, 4.0)
	var toward := Vector2(float(actor["target_x"]) - float(actor["x"]), float(actor["target_y"]) - float(actor["y"]))
	if toward.length() > 0.06:
		var step := toward.normalized() * pace * dt
		actor["x"] = clampf(float(actor["x"]) + step.x, 1.0, float(SIZE - 2))
		actor["y"] = clampf(float(actor["y"]) + step.y, 1.0, float(SIZE - 2))

func _grow_economies() -> void:
	for town in towns:
		var population: int = active_population(int(town["id"]))
		var biome: String = str(town.get("home_biome", "grass"))
		var food_factor: float = 1.0
		var wood_factor: float = 1.0
		match biome:
			"forest":
				food_factor = 0.95
				wood_factor = 2.0
			"sand":
				food_factor = 0.43
				wood_factor = 0.30
			"snow":
				food_factor = 0.34
				wood_factor = 0.65
			"mountain":
				food_factor = 0.65
				wood_factor = 0.55
		town["food"] = float(town["food"]) + (float(population) * 0.8 + 2.0) * food_factor
		town["wood"] = float(town["wood"]) + 4.0 * wood_factor
		if float(town["food"]) < float(population) * 0.6:
			news = str(town["name"]) + " enfrenta dificuldades com alimentos."

func _new_children() -> void:
	for town in towns:
		var town_id: int = int(town["id"])
		if active_population(town_id) >= 24 or float(town["food"]) < 8.0:
			continue
		var mothers: Array = []
		for candidate in people:
			if not bool(candidate["alive"]) or int(candidate["town"]) != town_id:
				continue
			if int(candidate["gender"]) != 1 or float(candidate["age"]) < 18.0 or float(candidate["age"]) > 44.0:
				continue
			var partner: Dictionary = get_person(int(candidate["partner"]))
			if partner.is_empty() or not bool(partner["alive"]):
				continue
			if int(partner["town"]) != town_id or int(partner["gender"]) != 0:
				continue
			if float(partner["age"]) < 18.0 or float(partner["age"]) > 65.0:
				continue
			if int(partner["partner"]) != int(candidate["id"]):
				continue
			# Evita que pais e filhos ou irmaos de sangue formem um casal reprodutivo.
			if int(partner["father"]) == int(candidate["id"]) or int(partner["mother"]) == int(candidate["id"]):
				continue
			if int(candidate["father"]) == int(partner["id"]) or int(candidate["mother"]) == int(partner["id"]):
				continue
			if int(candidate["father"]) > 0 and int(candidate["father"]) == int(partner["father"]):
				continue
			if int(candidate["mother"]) > 0 and int(candidate["mother"]) == int(partner["mother"]):
				continue
			mothers.append(candidate)
		if mothers.is_empty():
			continue
		var mother: Dictionary = mothers[rng.randi_range(0, mothers.size() - 1)]
		var father: Dictionary = get_person(int(mother["partner"]))
		var baby_id: int = make_person(town_id, float(town["x"]) + rng.randf_range(-0.8, 0.8), float(town["y"]) + rng.randf_range(-0.8, 0.8), 0, int(father["id"]), int(mother["id"]))
		town["food"] = float(town["food"]) - 5.0
		news = "Nasceu " + str(get_person(baby_id)["name"]) + " em " + str(town["name"]) + "!"

func active_population(town_id: int) -> int:
	var total := 0
	for p in people:
		if bool(p["alive"]) and int(p["town"]) == town_id:
			total += 1
	return total

func kill_person(person: Dictionary) -> void:
	if not bool(person["alive"]):
		return
	person["alive"] = false
	agent_ai.on_death(self, person)
	var town: Dictionary = get_town(int(person["town"]))
	if not town.is_empty() and int(town["leader"]) == int(person["id"]):
		choose_successor(town, int(person["id"]))

func choose_successor(town: Dictionary, former_id: int) -> void:
	var heirs: Array = []
	var candidates: Array = []
	for p in people:
		if not bool(p["alive"]) or int(p["town"]) != int(town["id"]):
			continue
		if float(p["age"]) < 15.0:
			continue
		candidates.append(p)
		if int(p["father"]) == former_id or int(p["mother"]) == former_id:
			heirs.append(p)
	var pool: Array = heirs if not heirs.is_empty() else candidates
	if pool.is_empty():
		town["leader"] = 0
		return
	pool.sort_custom(func(a, b): return float(a["age"]) > float(b["age"]))
	var successor: Dictionary = pool[0]
	town["leader"] = successor["id"]
	successor["role"] = "Rei" if int(successor["gender"]) == 0 else "Rainha"
	news = str(successor["name"]) + " herdou o trono de " + str(town["name"]) + "."

func _battle(dt: float) -> void:
	for town in towns:
		if not bool(town["hostile"]) or not rivals:
			continue
		for p in people:
			if not bool(p["alive"]) or int(p["town"]) == int(town["id"]):
				continue
			if Vector2(float(p["x"]), float(p["y"])).distance_to(Vector2(float(town["x"]), float(town["y"]))) < 2.4 and rng.randf() < dt * 0.015:
				p["health"] = float(p["health"]) - 5.0
				if float(p["health"]) <= 0.0:
					kill_person(p)

func _predator_attacks(dt: float) -> void:
	for b in beasts:
		if not bool(b["alive"]):
			continue
		for p in people:
			if bool(p["alive"]) and Vector2(float(b["x"]), float(b["y"])).distance_to(Vector2(float(p["x"]), float(p["y"]))) < 0.75 and rng.randf() < dt * 0.1:
				p["health"] = float(p["health"]) - (14.0 if b["species"] == "Urso" else 8.0)
				if float(p["health"]) <= 0.0:
					kill_person(p)

func save_world() -> bool:
	var file := FileAccess.open("user://world.json", FileAccess.WRITE)
	if file == null:
		return false
	var data := {
		"tiles": tiles, "towns": towns, "people": people, "beasts": beasts,
		"next_id": next_id, "day": day, "next_birth": next_birth,
		"next_growth": next_growth, "wars": wars, "rivals": rivals, "predators": predators
	}
	file.store_string(JSON.stringify(data))
	file.close()
	return true

func load_world() -> bool:
	agent_ai.elapsed = 0.0
	politics.elapsed = 0.0
	if not FileAccess.file_exists("user://world.json"):
		return false
	var file := FileAccess.open("user://world.json", FileAccess.READ)
	if file == null:
		return false
	var value = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(value) != TYPE_DICTIONARY:
		return false
	tiles = value.get("tiles", [])
	towns = value.get("towns", [])
	people = value.get("people", [])
	beasts = value.get("beasts", [])
	next_id = int(value.get("next_id", 1))
	day = float(value.get("day", 0.0))
	next_birth = float(value.get("next_birth", day + 120.0))
	next_growth = float(value.get("next_growth", day + 80.0))
	wars = bool(value.get("wars", false))
	rivals = bool(value.get("rivals", false))
	predators = bool(value.get("predators", false))
	news = "Mundo salvo carregado."
	if tiles.size() == SIZE:
		politics.prepare(self)
		return true
	return false
