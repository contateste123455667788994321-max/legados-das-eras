extends RefCounted
class_name WorldSim

const AgentAI = preload("res://scripts/ai.gd")
const Politics = preload("res://scripts/politics.gd")
const SIZE := 20
# Um dia dura dez segundos a 1x; um ano dura cerca de 61 minutos.
const DAYS_PER_REAL_SECOND := 0.10
const NAMES := ["Ari", "Nara", "Taro", "Lia", "Breno", "Iara", "Dara", "Enzo", "Kira", "Suri", "Davi", "Maya", "Ravi", "Luna", "Rael", "Yara", "Cael", "Tina", "Eron", "Ayla"]
var rng := RandomNumberGenerator.new()
var agent_ai = AgentAI.new()
var politics = Politics.new()
var tiles: Array = []
var towns: Array = []
var people: Array = []
var beasts: Array = []
var trees: Dictionary = {}
var tree_revision := 0
var next_seed_day := 15.0
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
	trees.clear()
	tree_revision += 1
	next_seed_day = 15.0
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
	# Continentes coerentes, floresta a oeste, deserto no sul e neve nas montanhas.
	# Um rio sinuoso atravessa as regioes; pequenas variacoes preservam diversidade.
	for y in range(SIZE):
		var row: Array = []
		var river_x: int = 9 + roundi(sin(float(y) * 0.49) * 2.8)
		for x in range(SIZE):
			var r: float = rng.randf()
			var biome := "grass"
			var river_distance: int = absi(x - river_x)
			if river_distance == 0 and y >= 2 and y <= SIZE - 3:
				biome = "water"
			elif y < 3 and x > 13:
				biome = "snow"
			elif x > 12 and y < 8:
				biome = "snow" if r < 0.74 else "mountain"
			elif x < 7 and y > 11:
				biome = "sand" if r < 0.82 else "grass"
			elif x > 12 and y >= 8 and y <= 13:
				biome = "mountain" if r < 0.63 else "forest"
			elif x < 9 and y < 12:
				biome = "forest" if r < 0.67 else "grass"
			elif river_distance == 1:
				biome = "sand" if r < 0.35 else "grass"
			elif r < 0.11:
				biome = "forest"
			if (x <= 1 or y <= 1 or x >= SIZE - 2 or y >= SIZE - 2) and r < 0.34:
				biome = "water"
			row.append(biome)
		tiles.append(row)
	make_town("Vale Verde", 5, 5, false)
	make_town("Pedra Alta", 15, 5, false)
	make_town("Campo do Sol", 16, 15, false)
	_seed_initial_trees()
	politics.prepare(self)
	news = "Tres aldeias vivem em paz. Voce decide o futuro."

func make_town(town_name: String, x: int, y: int, hostile: bool) -> void:
	var town_id := new_id()
	var founding_biome: String = str(tiles[y][x])
	var town := {
		"id": town_id, "name": town_name, "x": x, "y": y,
		"hostile": hostile, "leader": 0, "food": 25.0,
		"wood": 12.0, "knowledge": 0.0, "level": 1,
		"law": "primogenitura", "water": 18.0,
		"home_biome": founding_biome,
		"clothing": 0.0, "drought_preparation": false,
		"houses": 2, "farms": 1, "construction": {}, "historical_events": []
	}
	towns.append(town)
	tiles[y][x] = "grass"
	var original_count: int = people.size()
	for i in range(6):
		var age: int = rng.randi_range(23, 44)
		match i:
			0: age = rng.randi_range(42, 66)
			3: age = rng.randi_range(1, 7)
			4: age = rng.randi_range(8, 15)
		var person_id := make_person(town_id, float(x) + rng.randf_range(-1.0, 1.0), float(y) + rng.randf_range(-1.0, 1.0), age)
		if i == 0:
			town["leader"] = person_id
	var ruler: Dictionary = people[original_count]
	ruler["role"] = "Rei" if int(ruler["gender"]) == 0 else "Rainha"
	var father: Dictionary = people[original_count + 1]
	var mother: Dictionary = people[original_count + 2]
	father["gender"] = 0
	mother["gender"] = 1
	father["partner"] = mother["id"]
	mother["partner"] = father["id"]
	for i in [3, 4]:
		var child: Dictionary = people[original_count + i]
		child["father"] = father["id"]
		child["mother"] = mother["id"]

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
		"appearance": rng.randi_range(0, 9), "skin": rng.randi_range(0, 4), "hair": rng.randi_range(0, 5),
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
	var elapsed_days := dt * DAYS_PER_REAL_SECOND
	day += elapsed_days
	_update_trees(dt)
	for t in towns:
		# Avanco vinculado aos dias do mundo e a geracoes, nao aos quadros por segundo.
		t["knowledge"] = float(t["knowledge"]) + elapsed_days * (0.012 + float(active_population(int(t["id"]))) * 0.00035)
		var researched_level := 1 + int(float(t["knowledge"]) / 18.0)
		var era_cap := 1 + int(day / 730.0)
		var new_level := mini(researched_level, era_cap)
		if new_level > int(t["level"]):
			t["level"] = mini(new_level, 5)
			news = str(t["name"]) + " avancou para a era " + str(t["level"]) + "!"
	for p in people:
		if not bool(p["alive"]):
			continue
		p["age"] = float(p["age"]) + elapsed_days / 365.0
		if float(p["age"]) > 79 and rng.randf() < elapsed_days * 0.0008:
			kill_person(p)
			continue
		if int(p["id"]) != controlled_id:
			_wander(p, dt, 0.65 * life_speed(p))
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
	for town in towns:
		progress_construction(town, dt)

func construction_cost(kind: String) -> float:
	match kind:
		"house": return 14.0
		"farm": return 18.0
	return -1.0

func start_construction(town_id: int, kind: String) -> bool:
	var town: Dictionary = get_town(town_id)
	if town.is_empty():
		news = "Selecione uma aldeia primeiro."
		return false
	var cost: float = construction_cost(kind)
	if cost < 0.0:
		news = "Construcao desconhecida."
		return false
	if not town.get("construction", {}).is_empty():
		news = str(town["name"]) + " ja esta construindo."
		return false
	if kind == "house" and int(town.get("houses", 2)) >= 8:
		news = "Esta aldeia atingiu o limite de casas."
		return false
	if kind == "farm" and int(town.get("farms", 1)) >= 6:
		news = "Esta aldeia atingiu o limite de fazendas."
		return false
	if float(town["wood"]) < cost:
		news = "Madeira insuficiente: precisa de %d, tem %d." % [int(cost), int(float(town["wood"]))]
		return false
	town["wood"] = float(town["wood"]) - cost
	var label: String = "casa" if kind == "house" else "fazenda"
	town["construction"] = {"kind": kind, "progress": 0.0, "duration": 12.0 if kind == "house" else 15.0}
	news = str(town["name"]) + " iniciou uma " + label + "."
	return true

func progress_construction(town: Dictionary, dt: float) -> void:
	var site: Dictionary = town.get("construction", {})
	if site.is_empty() or dt <= 0.0:
		return
	var helpers := 0
	for person in people:
		if not bool(person["alive"]) or int(person["town"]) != int(town["id"]):
			continue
		if str(person.get("profession", "")) == "Construtor" and str(person.get("task", "")) == "Construindo":
			helpers += 1
	site["progress"] = float(site.get("progress", 0.0)) + dt * (1.0 + minf(float(helpers) * 0.3, 0.9))
	if float(site["progress"]) < float(site.get("duration", 12.0)):
		return
	var kind: String = str(site["kind"])
	if kind == "house":
		town["houses"] = int(town.get("houses", 2)) + 1
	else:
		town["farms"] = int(town.get("farms", 1)) + 1
	town["construction"] = {}
	var label: String = "Casa pronta" if kind == "house" else "Fazenda pronta"
	var history: Array = town.get("historical_events", [])
	history.append({"day": int(day), "event": label + "."})
	if history.size() > 12:
		history.pop_front()
	news = str(town["name"]) + ": " + label + "!"

func _wander(actor: Dictionary, dt: float, pace: float) -> void:
	actor["wander"] = float(actor["wander"]) - dt
	if float(actor["wander"]) <= 0.0:
		# Trabalho e descanso mantem o destino ate o proximo objetivo da IA.
		if bool(actor.get("work_goal", false)):
			actor["wander"] = rng.randf_range(1.5, 4.0)
		else:
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
		"trees": trees, "next_seed_day": next_seed_day,
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
		trees = value.get("trees", {})
		next_seed_day = float(value.get("next_seed_day", day + 15.0))
		if not value.has("trees"):
			_seed_initial_trees()
		tree_revision += 1
		for p in people:
			if not p.has("appearance"): p["appearance"] = posmod(int(p["id"]), 10)
			if not p.has("skin"): p["skin"] = posmod(int(p["id"])*3,5)
			if not p.has("hair"): p["hair"] = posmod(int(p["id"])*7,6)
		politics.prepare(self)
		return true
	return false

func life_stage(person: Dictionary) -> int:
	var age: float = float(person.get("age", 25.0))
	if age < 3: return 0
	if age < 16: return 1
	if age >= 60: return 3
	return 2

func life_speed(person: Dictionary) -> float:
	return [0.28, 0.68, 1.0, 0.64][life_stage(person)]

func tree_key(x: int, y: int) -> String:
	return "%d:%d" % [x,y]

func _tree_allowed(x: int, y: int) -> bool:
	var kind: String = str(tiles[y][x])
	if kind not in ["forest","grass","snow"]: return false
	for town in towns:
		if Vector2(x,y).distance_to(Vector2(float(town["x"]),float(town["y"]))) < 2.8: return false
	return true

func _plant_tree(x: int,y: int,mature: bool) -> void:
	var kind: String = str(tiles[y][x])
	trees[tree_key(x,y)] = {"x":x,"y":y,"ox":rng.randf_range(-0.23,0.23),"oy":rng.randf_range(-0.23,0.23),"pine":kind=="snow" or rng.randf()<0.28,"state":"live","born":day-100.0 if mature else day,"fall":0.0,"regrow":0.0}
	tree_revision += 1

func _seed_initial_trees() -> void:
	for y in range(SIZE):
		for x in range(SIZE):
			if not _tree_allowed(x,y): continue
			var kind: String = str(tiles[y][x])
			if rng.randf() < (0.93 if kind=="forest" else (0.78 if kind=="snow" else 0.14)):
				_plant_tree(x,y,true)

func tree_scale(tree: Dictionary) -> float:
	return 0.25 + 0.75*clampf((day-float(tree.get("born",day)))/100.0,0.0,1.0)

func cut_tree(actor: Dictionary, x: int,y: int) -> bool:
	var key: String = tree_key(x,y)
	if not trees.has(key): return false
	var tree: Dictionary = trees[key]
	if str(tree["state"])!="live" or tree_scale(tree)<0.65: return false
	tree["state"]="falling"
	tree["fall"]=0.0
	tree["regrow"]=day+rng.randf_range(50.0,100.0)
	actor["wood"]=int(actor.get("wood",0))+3
	tree_revision+=1
	news=str(actor["name"])+" derrubou uma arvore e recolheu 3 madeiras."
	return true

func _update_trees(dt: float) -> void:
	for key in trees.keys():
		var tree: Dictionary = trees[key]
		match str(tree["state"]):
			"falling":
				tree["fall"]=minf(1.0,float(tree["fall"])+dt/1.1)
				if float(tree["fall"])>=1.0:
					tree["state"]="stump"
					tree_revision+=1
			"stump":
				if day>=float(tree["regrow"]):
					if _tree_allowed(int(tree["x"]),int(tree["y"])):
						tree["state"]="live"
						tree["born"]=day
						tree["fall"]=0.0
						tree_revision+=1
					else:
						trees.erase(key)
						tree_revision+=1
	if day>=next_seed_day:
		next_seed_day=day+15.0
		for attempt in range(18):
			var x: int=rng.randi_range(1,SIZE-2)
			var y: int=rng.randi_range(1,SIZE-2)
			if _tree_allowed(x,y) and not trees.has(tree_key(x,y)):
				_plant_tree(x,y,false)
				break
