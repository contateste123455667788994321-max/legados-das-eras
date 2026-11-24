extends RefCounted
class_name WorldSim

const AgentAI = preload("res://scripts/ai.gd")
const Politics = preload("res://scripts/politics.gd")
const SIZE := 20
const WIDTH := 48
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
var wildlife: Array = []
var sites: Array = []
var rivers_v58:bool=false
var habitats_v59:bool=false
var ecology_v60:bool=false
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
	wildlife.clear()
	sites.clear()
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
		for x in range(WIDTH):
			var r: float = rng.randf()
			var biome := "grass"
			var river_distance: int = absi(x - river_x)
			if river_distance <= (1 if y%5==0 else 0):
				biome = "water"
			elif x >= 20:
				biome = _east_biome(x,y)
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
			if (x <= 1 or y <= 1 or x >= WIDTH - 2 or y >= SIZE - 2) and r < 0.34:
				biome = "water"
			row.append(biome)
		tiles.append(row)
	make_town("Vale Verde", 5, 5, false)
	make_town("Pedra Alta", 15, 5, false)
	make_town("Campo do Sol", 16, 15, false)
	_connect_rivers()
	_seed_initial_trees()
	_prepare_sites()
	_seed_wildlife()
	_seed_habitat_animals()
	_seed_extra_animals()
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
		"houses": 2, "farms": 1, "campfire":false, "oven":false, "forge":false, "crossing":false, "stone":0.0, "construction": {}, "historical_events": []
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
				"x": rng.randf_range(2.0, WIDTH - 3.0),
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
	_update_wildlife(dt)
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
		"campfire": return 10.0
		"house": return 14.0
		"farm": return 18.0
		"oven": return 8.0
		"forge": return 20.0
		"crossing": return 16.0
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
	if kind in ["campfire","oven","forge","crossing"]:
		if bool(town.get(kind,false)): return false
		if kind=="forge" and (int(town["level"])<3 or not bool(town.get("oven",false))):
			news="A forja exige a terceira era e um forno."
			return false
		if float(town.get("stone",0))<workshop_stone_cost(kind):
			news="Pedra insuficiente para a obra."
			return false
	if float(town["wood"]) < cost:
		news = "Madeira insuficiente: precisa de %d, tem %d." % [int(cost), int(float(town["wood"]))]
		return false
	town["wood"] = float(town["wood"]) - cost
	var label:String={"campfire":"fogueira","house":"casa","farm":"fazenda","oven":"forno","forge":"forja","crossing":"ponte"}[kind]
	town["construction"]={"kind":kind,"progress":0.0,"duration":float({"campfire":8,"house":12,"farm":15,"oven":20,"forge":32,"crossing":26}[kind])}
	var stone_cost:float=workshop_stone_cost(kind)
	town["stone"]=float(town.get("stone",0))-stone_cost
	_prepare_project(town)

	news = str(town["name"]) + " iniciou uma " + label + "."
	return true

func progress_construction(town: Dictionary, dt: float) -> void:
	var site: Dictionary = town.get("construction", {})
	if site.is_empty() or dt <= 0.0:
		return
	_prepare_project(town)
	var helpers:=0
	for person in people:
		if not bool(person["alive"]) or int(person["town"])!=int(town["id"]): continue
		if str(person.get("task",""))=="Construindo" and Vector2(float(person["x"]),float(person["y"])).distance_to(Vector2(float(site["x"]),float(site["y"])))<1.1:
			helpers+=1
	if helpers==0: return
	var required:Dictionary=site["required"]
	var delivered:Dictionary=site["delivered"]
	var fraction:float=(float(delivered["wood"])+float(delivered["stone"]))/maxf(1.0,float(required["wood"])+float(required["stone"]))
	site["progress"]=minf(float(site["duration"])*fraction,float(site["progress"])+dt*(1.0+minf(float(helpers)*0.35,0.9)))

	if float(site["progress"]) < float(site.get("duration", 12.0)):
		return
	var kind: String = str(site["kind"])
	if kind == "house":
		town["houses"] = int(town.get("houses", 2)) + 1
	elif kind=="farm":
		town["farms"]=int(town.get("farms",1))+1
	else:
		town[kind]=true
		sites.append({"kind":kind,"x":site["x"],"y":site["y"],"town":town["id"]})
	town["construction"]={}
	var label:String={"campfire":"Fogueira acesa","house":"Casa pronta","farm":"Fazenda pronta","oven":"Forno construido","forge":"Forja construida","crossing":"Ponte construida"}[kind]
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
			actor["target_x"] = clampf(float(actor["x"]) + rng.randf_range(-2.0, 2.0), 2.0, float(WIDTH - 3))
			actor["target_y"] = clampf(float(actor["y"]) + rng.randf_range(-2.0, 2.0), 2.0, float(SIZE - 3))
			actor["wander"] = rng.randf_range(1.5, 4.0)
	var toward := Vector2(float(actor["target_x"]) - float(actor["x"]), float(actor["target_y"]) - float(actor["y"]))
	if toward.length() > 0.06:
		var burden:float=1.0-0.25*clampf(carried_weight(actor)/maxf(1.0,load_capacity(actor)),0.0,1.0)
		var step := toward.limit_length(pace*dt*burden)
		move_actor(actor,step,dt)

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
		"wildlife": wildlife, "sites": sites, "rivers_v58":rivers_v58, "habitats_v59":habitats_v59, "ecology_v60":ecology_v60,
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
		var old_width:int=tiles[0].size() if tiles[0] is Array else 0
		for y in range(SIZE):
			if not tiles[y] is Array or tiles[y].size()<20: return false
			while tiles[y].size()<WIDTH:
				tiles[y].append(_east_biome(tiles[y].size(),y))
		trees = value.get("trees", {})
		next_seed_day = float(value.get("next_seed_day", day + 15.0))
		if not value.has("trees"):
			_seed_initial_trees()
		for y in range(SIZE):
			for x in range(20,WIDTH):
				if not value.has("sites") and _tree_allowed(x,y) and not trees.has(tree_key(x,y)) and rng.randf()<0.55:
					_plant_tree(x,y,true)
		for y in range(SIZE):
			for x in range(maxi(32,old_width),WIDTH):
				if _tree_allowed(x,y) and not trees.has(tree_key(x,y)) and rng.randf()<0.55: _plant_tree(x,y,true)
		wildlife = value.get("wildlife",[])
		sites = value.get("sites",[])
		rivers_v58=bool(value.get("rivers_v58",false))
		if not rivers_v58:
			_connect_rivers()
			_prepare_sites()
		elif sites.is_empty(): _prepare_sites()
		for i in range(sites.size()-1,-1,-1):
			var site:Dictionary=sites[i]
			if str(site["kind"]) in ["campfire","oven","forge","crossing"]:
				var owner:Dictionary=get_town(int(site["town"]))
				if not bool(owner.get(str(site["kind"]),false)): sites.remove_at(i)
		if not value.has("wildlife"): _seed_wildlife()
		habitats_v59=bool(value.get("habitats_v59",false))
		if not habitats_v59: _seed_habitat_animals()
		ecology_v60=bool(value.get("ecology_v60",false))
		if not ecology_v60: _seed_extra_animals()
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
	if kind not in ["forest","grass","snow","swamp"]: return false
	for town in towns:
		if Vector2(x,y).distance_to(Vector2(float(town["x"]),float(town["y"]))) < 2.8: return false
	return true

func _plant_tree(x: int,y: int,mature: bool) -> void:
	var kind: String = str(tiles[y][x])
	trees[tree_key(x,y)] = {"x":x,"y":y,"ox":rng.randf_range(-0.23,0.23),"oy":rng.randf_range(-0.23,0.23),"pine":kind=="snow" or rng.randf()<0.28,"state":"live","born":day-100.0 if mature else day,"fall":0.0,"regrow":0.0}
	tree_revision += 1

func _seed_initial_trees() -> void:
	for y in range(SIZE):
		for x in range(WIDTH):
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
	if free_load(actor)<3.0*resource_weight("wood"):
		news="Carga cheia. Leve os materiais para a aldeia."
		return false
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
			var x: int=rng.randi_range(1,WIDTH-2)
			var y: int=rng.randi_range(1,SIZE-2)
			if _tree_allowed(x,y) and not trees.has(tree_key(x,y)):
				_plant_tree(x,y,false)
				break

func _east_biome(x:int,y:int) -> String:
	if x>=32:
		var n:float=sin(float(x)*0.38+float(y)*0.27)+cos(float(y)*0.43-float(x)*0.19)
		if x>=42 and y>=10: return "sand" if n<1.1 else "grass"
		if y<5 and x>=41: return "snow" if n<0.4 else "mountain"
		if x<43 and y>=6 and y<=15: return "water" if n>1.15 else "swamp"
		return "forest" if n>0.0 else "grass"
	var river: int = 25+roundi(sin(float(y)*0.43)*2.5)
	if absi(x-river)==0: return "water"
	if x>27 and y<8: return "mountain" if y>3 else "snow"
	if x>27 and y>14: return "sand"
	return "forest" if posmod(x*31+y*71+x*y*17,13)<7 else "grass"

func nearest_site(kind:String,origin:Vector2) -> Dictionary:
	var found: Dictionary={}
	var best: float=100000.0
	for site in sites:
		if str(site["kind"])!=kind: continue
		var d: float=origin.distance_squared_to(Vector2(float(site["x"]),float(site["y"])))
		if d<best:
			best=d
			found=site
	return found

func _prepare_sites() -> void:
	sites.clear()
	for town in towns:
		var origin:=Vector2(float(town["x"]),float(town["y"]))
		for kind in ["campfire","oven","forge","crossing"]:
			if bool(town.get(kind,false)):
				var pos:Vector2=workshop_position(town,kind)
				sites.append({"kind":kind,"x":pos.x,"y":pos.y,"town":town["id"]})
		for kind in ["fish","mine"]:
			var best: float=10000.0
			var chosen:=Vector2(-1,-1)
			for y in range(1,SIZE-1):
				for x in range(1,WIDTH-1):
					if str(tiles[y][x]) in ["water","mountain"]: continue
					var wanted: String="water" if kind=="fish" else "mountain"
					var adjacent: bool=false
					for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
						if str(tiles[y+offset.y][x+offset.x])==wanted: adjacent=true
					if not adjacent: continue
					var d: float=origin.distance_squared_to(Vector2(x,y))
					if d<best:
						best=d
						chosen=Vector2(x,y)
			if chosen.x>=0: sites.append({"kind":kind,"x":chosen.x,"y":chosen.y,"town":town["id"],"developed":false,"work":0.0})
	for x in range(1,WIDTH-1):
		if str(tiles[2][x])=="water" and str(tiles[3][x])=="water":
			sites.append({"kind":"waterfall","x":x,"y":2})
			if x>20: break

func _seed_wildlife() -> void:
	for i in range(24):
		var species: String=["chicken","deer","rabbit"][i%3]
		var town: Dictionary=towns[i%towns.size()]
		for attempt in range(30):
			var x: int=clampi(int(town["x"])+rng.randi_range(-4,4),1,WIDTH-2) if species=="chicken" else rng.randi_range(1,WIDTH-2)
			var y: int=clampi(int(town["y"])+rng.randi_range(-4,4),1,SIZE-2) if species=="chicken" else rng.randi_range(1,SIZE-2)
			if str(tiles[y][x]) not in ["grass","forest"]: continue
			wildlife.append({"id":i,"species":species,"x":float(x),"y":float(y),"tx":float(x),"ty":float(y),"timer":rng.randf_range(0.0,4.0)})
			break

func _update_wildlife(dt:float) -> void:
	var births:Array=[]
	for animal in wildlife:
		var species:String=str(animal["species"])
		var p:=Vector2(float(animal["x"]),float(animal["y"]))
		var kind:String=str(tiles[clampi(int(p.y),0,SIZE-1)][clampi(int(p.x),0,WIDTH-1)])
		animal["hunger"]=clampf(float(animal.get("hunger",rng.randf_range(0,35)))+dt*0.48,0,100)
		animal["timer"]=float(animal["timer"])-dt
		animal["breed_timer"]=maxf(0,float(animal.get("breed_timer",rng.randf_range(90,200)))-dt)
		if float(animal["timer"])<=0:
			_choose_animal_action(animal,p,kind)
		var state:String=str(animal.get("state","Andando"))
		var goal:=Vector2(float(animal["tx"]),float(animal["ty"]))
		var pace:float=float({"chicken":0.35,"deer":0.65,"rabbit":0.72,"frog":0.48,"capybara":0.37,"heron":0.60,"camel":0.48,"lizard":0.45,"snow_hare":0.72,"crocodile":0.52,"turtle":0.19,"duck":0.54,"boar":0.58,"fox":0.68}.get(species,0.42))
		if state in ["Fugindo","Cacando"]: pace*=1.75
		if species=="crocodile" and kind=="water": pace*=1.4
		if state in ["Saltando","Pulando"] and fposmod(float(animal["timer"])*3.0,1.0)>0.55: pace=0.0
		if state in ["Descansando","Aquecendo","Emboscando","Pescando","Pastando","Bicando","Fuçando","Comendo"]: pace=0.0
		var n:=p.move_toward(goal,dt*pace)
		if animal_habitat(species,str(tiles[clampi(int(n.y),0,SIZE-1)][clampi(int(n.x),0,WIDTH-1)])):
			animal["x"]=n.x
			animal["y"]=n.y
		else:
			animal["timer"]=0.0
		if state in ["Pescando","Pastando","Bicando","Fuçando","Comendo"]:
			animal["hunger"]=maxf(0,float(animal["hunger"])-dt*3.0)
		if state=="Cacando":
			for prey in wildlife:
				if int(prey["id"])!=int(animal.get("prey",-1)): continue
				if p.distance_to(Vector2(float(prey["x"]),float(prey["y"])))<0.35:
					animal["hunger"]=maxf(0,float(animal["hunger"])-35.0)
					animal["state"]="Comendo"
					animal["timer"]=3.0
					prey["state"]="Fugindo"
					prey["timer"]=0.0
					prey["hunger"]=minf(100,float(prey.get("hunger",0))+12.0)
				break
		if float(animal["breed_timer"])<=0:
			animal["breed_timer"]=rng.randf_range(160,260)
			var count:int=0
			for other in wildlife:
				if str(other["species"])==species: count+=1
			if count<8 and wildlife.size()+births.size()<110 and float(animal["hunger"])<30 and rng.randf()<0.35:
				var child:Dictionary=animal.duplicate(true)
				child["id"]=new_id()+10000
				child["breed_timer"]=180.0
				child["hunger"]=15.0
				births.append(child)
	wildlife.append_array(births)

func _choose_animal_action(animal:Dictionary,p:Vector2,kind:String) -> void:
	var species:String=str(animal["species"])
	var threat:Dictionary={}
	var prey:Dictionary={}
	var companion:Dictionary={}
	var threat_distance:float=2.4
	var prey_distance:float=3.0
	var companion_distance:float=4.5
	for other in wildlife:
		if int(other["id"])==int(animal["id"]): continue
		var other_species:String=str(other["species"])
		var d:float=p.distance_to(Vector2(float(other["x"]),float(other["y"])))
		if _animal_prey(other_species,species) and d<threat_distance:
			threat_distance=d
			threat=other
		if _animal_prey(species,other_species) and d<prey_distance:
			prey_distance=d
			prey=other
		if other_species==species and d<companion_distance and d>1.5:
			companion_distance=d
			companion=other
	animal["timer"]=rng.randf_range(2.0,5.0)
	var q:=p
	var hungry:bool=float(animal["hunger"])>40.0
	if not threat.is_empty():
		var away:Vector2=(p-Vector2(float(threat["x"]),float(threat["y"]))).normalized()
		q=p+away*2.3
		animal["state"]="Fugindo"
		animal["timer"]=1.5
	elif species in ["crocodile","fox"] and hungry and not prey.is_empty():
		q=Vector2(float(prey["x"]),float(prey["y"]))
		animal["state"]="Cacando"
		animal["prey"]=prey["id"]
		animal["timer"]=0.8
	elif hungry and species not in ["crocodile","fox"]:
		animal["state"]=str({"chicken":"Bicando","deer":"Pastando","rabbit":"Pastando","frog":"Comendo","capybara":"Pastando","heron":"Pescando","camel":"Pastando","lizard":"Comendo","snow_hare":"Pastando","turtle":"Comendo","duck":"Pescando","boar":"Fuçando"}.get(species,"Comendo"))
		if species in ["heron","duck"] and kind not in ["water","swamp"]:
			q=_animal_destination(p,species,["water","swamp"])
			animal["state"]="Caminhando"
	elif rng.randf()<0.30:
		animal["state"]="Emboscando" if species=="crocodile" else ("Aquecendo" if species in ["lizard","turtle"] else "Descansando")
	else:
		var range_size:float=2.4 if species in ["deer","camel","heron","fox"] else 1.4
		q=p+Vector2(rng.randf_range(-range_size,range_size),rng.randf_range(-range_size,range_size))
		if not companion.is_empty() and species in ["deer","capybara","camel","chicken","duck","boar"]:
			q=p.lerp(Vector2(float(companion["x"]),float(companion["y"])),0.55)
		if species=="crocodile" and rng.randf()<0.65:
			q=_animal_destination(p,species,["water","swamp"])
		animal["state"]="Nadando" if kind=="water" else ("Saltando" if species=="frog" else ("Pulando" if species in ["rabbit","snow_hare"] else "Caminhando"))
	q.x=clampf(q.x,1,WIDTH-2)
	q.y=clampf(q.y,1,SIZE-2)
	if not animal_habitat(species,str(tiles[int(q.y)][int(q.x)])):
		q=p
	animal["tx"]=q.x
	animal["ty"]=q.y

func _animal_prey(hunter:String,prey:String) -> bool:
	return (hunter=="crocodile" and prey in ["duck","frog","capybara","heron"]) or (hunter=="fox" and prey in ["rabbit","chicken","snow_hare"])

func _animal_destination(p:Vector2,species:String,kinds:Array) -> Vector2:
	var best:=p
	var distance:float=100.0
	for y in range(maxi(1,int(p.y)-3),mini(SIZE-1,int(p.y)+4)):
		for x in range(maxi(1,int(p.x)-3),mini(WIDTH-1,int(p.x)+4)):
			var kind:String=str(tiles[y][x])
			if kind not in kinds or not animal_habitat(species,kind): continue
			var q:=Vector2(x+0.4,y+0.4)
			var d:float=q.distance_to(p)
			if d<distance:
				distance=d
				best=q
	return best

func river_x(y:int,index:int) -> int:
	return (10 if index==0 else 25)+roundi(sin(float(y)*0.36+float(index)*0.9)*2.0)

func _connect_rivers() -> void:
	for index in range(2):
		for y in range(SIZE):
			var x:int=river_x(y,index)
			var previous:int=river_x(maxi(y-1,0),index)
			for xx in range(mini(x,previous),maxi(x,previous)+1):
				tiles[y][xx]="water"
				trees.erase(tree_key(xx,y))
	rivers_v58=true
	tree_revision+=1

func is_bridge(x:int,y:int) -> bool:
	for site in sites:
		if str(site["kind"])=="crossing" and int(site["x"])==x and int(site["y"])==y: return true
	return false

func water_flow(p:Vector2) -> Vector2:
	var y:int=clampi(int(p.y),0,SIZE-1)
	var i:int=0 if p.x<18 else 1
	var next:int=river_x(mini(y+1,SIZE-1),i)
	return Vector2(float(next-river_x(y,i)),1.0).normalized()

func move_actor(actor:Dictionary,step:Vector2,dt:float) -> void:
	var p:=Vector2(float(actor["x"]),float(actor["y"]))
	var x:int=clampi(int(p.x),0,WIDTH-1)
	var y:int=clampi(int(p.y),0,SIZE-1)
	if str(tiles[y][x])=="water" and not is_bridge(x,y):
		step=step*0.42+water_flow(p)*dt*0.20
	if str(tiles[y][x])=="swamp": step*=0.65
	var q:=p+step
	q.x=clampf(q.x,1.0,WIDTH-2.0)
	q.y=clampf(q.y,1.0,SIZE-2.0)
	actor["x"]=q.x
	actor["y"]=q.y

func workshop_stone_cost(kind:String) -> float:
	return float({"oven":12,"forge":24,"crossing":4}.get(kind,0))

func workshop_position(town:Dictionary,kind:String) -> Vector2:
	var origin:=Vector2(float(town["x"]),float(town["y"]))
	if kind=="campfire": return origin+Vector2(0.7,1.0)
	if kind=="house":
		var spots:Array[Vector2]=[Vector2(0,-0.35),Vector2(1.60,0.35),Vector2(-1.25,-0.75),Vector2(2.15,-0.85),Vector2(-2.4,0.15),Vector2(0.95,-1.65),Vector2(-1.35,1.45),Vector2(2.9,1.15)]
		return origin+spots[clampi(int(town.get("houses",2)),0,7)]
	if kind=="farm":
		var spots:Array[Vector2]=[Vector2(-1.4,1.15),Vector2(-2.2,2.20),Vector2(1.3,1.85),Vector2(2.9,2.0),Vector2(-2.8,-1.1),Vector2(3.1,-1.4)]
		return origin+spots[clampi(int(town.get("farms",1)),0,5)]
	if kind=="crossing":
		var best:=Vector2(river_x(6,0),6)
		for y in [6,14]:
			for index in range(2):
				var p:=Vector2(river_x(y,index),y)
				if p.distance_squared_to(origin)<best.distance_squared_to(origin): best=p
		return best
	var offsets:Array[Vector2]=[Vector2(1.8,2.3),Vector2(-1.9,2.9),Vector2(2.8,-2.1),Vector2(-2.8,-2.3)]
	if kind=="forge": offsets.reverse()
	for offset in offsets:
		var p:Vector2=origin+offset
		var x:int=clampi(roundi(p.x),0,WIDTH-1)
		var y:int=clampi(roundi(p.y),0,SIZE-1)
		if str(tiles[y][x]) in ["grass","forest","snow","sand"]: return p
	return origin+Vector2(0.0,2.3)

func local_site(kind:String,town_id:int) -> Dictionary:
	for site in sites:
		if str(site["kind"])==kind and int(site.get("town",-1))==town_id: return site
	return {}

func animal_habitat(species:String,kind:String) -> bool:
	match species:
		"frog","capybara","heron","crocodile","turtle","duck": return kind in ["swamp","water","grass"]
		"boar","fox": return kind in ["forest","grass"]
		"camel","lizard": return kind in ["sand","grass"]
		"snow_hare": return kind in ["snow","forest"]
	return kind in ["grass","forest"]

func _seed_habitat_animals() -> void:
	for species in ["frog","capybara","heron","camel","lizard","snow_hare"]:
		var suitable:Array[Vector2]=[]
		var habitat:String="swamp" if species in ["frog","capybara","heron"] else ("snow" if species=="snow_hare" else "sand")
		for y in range(1,SIZE-1):
			for x in range(32,WIDTH-1):
				if str(tiles[y][x])==habitat: suitable.append(Vector2(x,y))
		if suitable.is_empty(): continue
		for i in range(5):
			var pos:Vector2=suitable[rng.randi_range(0,suitable.size()-1)]
			wildlife.append({"id":100+wildlife.size(),"species":species,"x":pos.x,"y":pos.y,"tx":pos.x,"ty":pos.y,"timer":rng.randf_range(0.0,4.0)})
	habitats_v59=true

func _seed_extra_animals() -> void:
	for species in ["crocodile","turtle","duck","boar","fox"]:
		var candidates:Array[Vector2]=[]
		for y in range(1,SIZE-1):
			for x in range(1,WIDTH-1):
				var kind:String=str(tiles[y][x])
				if species in ["crocodile","turtle","duck"]:
					if x<32 or kind not in ["swamp","water"]: continue
				elif kind!="forest": continue
				candidates.append(Vector2(x+0.3,y+0.3))
		if candidates.is_empty(): continue
		for n in range(4):
			var p:Vector2=candidates[rng.randi_range(0,candidates.size()-1)]
			wildlife.append({"id":1000+wildlife.size(),"species":species,"x":p.x,"y":p.y,"tx":p.x,"ty":p.y,"timer":rng.randf_range(0,3),"hunger":rng.randf_range(0,50),"breed_timer":rng.randf_range(90,180),"state":"Descansando"})
	ecology_v60=true

func resource_weight(kind:String) -> float:
	return float({"wood":2.0,"stone":3.0,"ore":3.0,"metal":3.0,"food":1.0,"water":1.0,"fish":1.0,"meat":1.0}.get(kind,1.0))

func load_capacity(p:Dictionary) -> float:
	var base:float=22.0
	if p.has("age"):
		base=[0.0,7.0,22.0,20.0][life_stage(p)]
	return base+float({"basket":12,"cart":48}.get(str(p.get("transport","hands")),0))

func carried_weight(p:Dictionary) -> float:
	var total:float=0.0
	for key in ["wood","stone","ore","metal","food","water","fish","meat"]:
		total+=float(p.get(key,0))*resource_weight(key)
	var cargo:Dictionary=p.get("cargo",{})
	if not cargo.is_empty(): total+=float(cargo.get("amount",0))*resource_weight(str(cargo.get("kind","wood")))
	return total

func free_load(p:Dictionary) -> float:
	return maxf(0.0,load_capacity(p)-carried_weight(p))

func _prepare_project(town:Dictionary) -> void:
	var project:Dictionary=town.get("construction",{})
	if project.is_empty() or project.has("required"): return
	var kind:String=str(project["kind"])
	var pos:Vector2=workshop_position(town,kind)
	project["x"]=pos.x
	project["y"]=pos.y
	project["required"]={"wood":construction_cost(kind),"stone":workshop_stone_cost(kind)}
	project["delivered"]={"wood":0.0,"stone":0.0}
	project["project_id"]=new_id()
	project["progress"]=0.0

func transport_job(p:Dictionary,town:Dictionary) -> bool:
	var project:Dictionary=town.get("construction",{})
	var cargo:Dictionary=p.get("cargo",{})
	var pos:=Vector2(float(p["x"]),float(p["y"]))
	var store:=Vector2(float(town["x"]),float(town["y"]))
	if not cargo.is_empty():
		var for_project:bool=bool(cargo.get("project",false))
		var goal:Vector2=store
		if for_project and not project.is_empty() and int(cargo.get("project_id",-1))==int(project.get("project_id",-2)):
			goal=Vector2(float(project["x"]),float(project["y"]))
			_set_delivery_goal(p,goal,"Entregando materiais")
			if pos.distance_to(goal)<0.65:
				var key:String=str(cargo["kind"])
				project["delivered"][key]=float(project["delivered"].get(key,0))+float(cargo["amount"])
				p["cargo"]={}
				p["task"]="Construindo"
			return true
		_set_delivery_goal(p,store,"Levando recursos")
		if pos.distance_to(store)<0.65:
			var key:String=str(cargo["kind"])
			town[key]=float(town.get(key,0))+float(cargo["amount"])
			p["cargo"]={}
		return true
	if project.is_empty() or float(p["age"])<16.0: return false
	_prepare_project(town)
	# Dois adultos por aldeia trabalham na obra, os demais mantem producao.
	var rank:int=0
	for other in people:
		if not bool(other["alive"]) or int(other["town"])!=int(town["id"]) or float(other["age"])<16.0: continue
		if int(other["id"])==int(p["id"]): break
		rank+=1
	if rank>=2: return false
	var needed:Dictionary=project["required"]
	var delivered:Dictionary=project["delivered"]
	for key in ["wood","stone"]:
		var in_transit:float=0
		for other in people:
			var load:Dictionary=other.get("cargo",{})
			if bool(other["alive"]) and int(load.get("project_id",-1))==int(project["project_id"]) and str(load.get("kind",""))==key:
				in_transit+=float(load.get("amount",0))
		var remaining:float=float(needed[key])-float(delivered[key])-in_transit
		if remaining<=0.001: continue
		_set_delivery_goal(p,store,"Buscando materiais")
		if pos.distance_to(store)<0.65:
			var amount:float=minf(remaining,floorf(free_load(p)/resource_weight(key)))
			if amount>0:
				p["cargo"]={"kind":key,"amount":amount,"project":true,"project_id":project["project_id"]}
				_set_delivery_goal(p,Vector2(float(project["x"]),float(project["y"])),"Entregando materiais")
		return true
	_set_delivery_goal(p,Vector2(float(project["x"]),float(project["y"])),"Construindo")
	return true

func _set_delivery_goal(p:Dictionary,goal:Vector2,task:String) -> void:
	p["target_x"]=goal.x
	p["target_y"]=goal.y
	p["task"]=task
	p["work_timer"]=3.0
	p["work_goal"]=true

func collect_cargo(p:Dictionary,kind:String,amount:float) -> bool:
	if not p.get("cargo",{}).is_empty(): return false
	var limit:float=minf(amount,floorf(free_load(p)/resource_weight(kind)))
	if limit<=0: return false
	p["cargo"]={"kind":kind,"amount":limit}
	return true

func add_resource(p:Dictionary,kind:String,amount:int) -> bool:
	if free_load(p)<resource_weight(kind)*amount:
		news="Carga cheia. Deposite os recursos na aldeia."
		return false
	p[kind]=int(p.get(kind,0))+amount
	return true

func deposit_inventory(p:Dictionary) -> bool:
	var town:Dictionary=get_town(int(p.get("town",0)))
	if town.is_empty(): return false
	if Vector2(float(p["x"]),float(p["y"])).distance_to(Vector2(float(town["x"]),float(town["y"])))>1.2:
		news="Aproxime-se do centro da aldeia para descarregar."
		return false
	for key in ["wood","stone","ore","metal","food","water","fish","meat"]:
		town[key]=float(town.get(key,0))+float(p.get(key,0))
		p[key]=0
	news="Recursos entregues ao estoque da aldeia."
	return true
