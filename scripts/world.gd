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
var swamp_witch:Dictionary={}
var swamp_spiders:Array=[]
var resource_drops:Array=[]
var sound_events:Array=[]
var magic_bolts:Array=[]
var swamp_clock:float=0.0
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
	swamp_witch.clear()
	swamp_spiders.clear()
	resource_drops.clear()
	sound_events.clear()
	magic_bolts.clear()
	swamp_clock=0.0
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
	for animal in wildlife: init_animal_health(animal)
	_seed_swamp_witch()
	politics.prepare(self)
	news = "Tres aldeias vivem em paz. Voce decide o futuro."

func make_town(town_name: String, x: int, y: int, hostile: bool) -> void:
	var town_id := new_id()
	var founding_biome: String = str(tiles[y][x])
	var town := {
		"id": town_id, "name": town_name, "x": x, "y": y,
		"hostile": hostile, "leader": 0, "food": 25.0,
		"wood": 12.0, "knowledge": 0.0, "level": 1,
		"law": "merito", "water": 18.0,
		"home_biome": founding_biome,
		"clothing": 0.0, "drought_preparation": false,
		"houses": 2, "house_levels":[1,1], "castle":false, "farms": 1, "campfire":false, "oven":false, "forge":false, "crossing":false, "stone":0.0, "construction": {}, "historical_events": []
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
	ruler["role"] = "Lider tribal"
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
	choose_successor(town,0)
	town["merit_election"]=true

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
	init_traits(person)
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
	for beast in beasts: init_animal_health(beast)
	news = "Predadores ativos." if predators else "Ataques de animais desativados."

func update_world(delta: float, controlled_id: int = 0) -> void:
	if speed <= 0:
		return
	var dt := minf(delta, 0.1) * speed
	var elapsed_days := dt * DAYS_PER_REAL_SECOND
	day += elapsed_days
	_update_trees(dt)
	_update_wildlife(dt)
	_update_drops(dt)
	_update_swamp(dt,controlled_id)
	for t in towns:
		# Avanco vinculado aos dias do mundo e a geracoes, nao aos quadros por segundo.
		t["knowledge"] = float(t["knowledge"]) + elapsed_days * (0.012 + float(active_population(int(t["id"]))) * 0.00035)
		var researched_level := 1 + int(float(t["knowledge"]) / 18.0)
		var era_cap := 1 + int(day / 730.0)
		var new_level := mini(researched_level, era_cap)
		if new_level > int(t["level"]):
			t["level"] = mini(new_level, 5)
			sound_at("era",t)
			news = str(t["name"]) + " avancou para a era " + str(t["level"]) + "!"
	for p in people:
		if not bool(p["alive"]):
			continue
		init_traits(p)
		p["hunt_cd"]=maxf(0.0,float(p.get("hunt_cd",0))-dt)
		p["military_cd"]=maxf(0.0,float(p.get("military_cd",0))-dt)
		p["age"] = float(p["age"]) + elapsed_days / 365.0
		if float(p["age"]) > 79 and rng.randf() < elapsed_days * 0.0008:
			kill_person(p)
			continue
		if int(p["id"]) != controlled_id:
			_wander(p, dt, 0.65 * life_speed(p))
	for b in beasts:
		if bool(b["alive"]) and int(b["id"]) != controlled_id:
			if not predators or not _hostile_animal_step(b,dt):
				if float(b["wander"])<=0 and rng.randf()<0.65:
					var preferred:Vector2=_preferred_animal_destination(Vector2(float(b["x"]),float(b["y"])),str(b["species"]))
					b["target_x"]=preferred.x
					b["target_y"]=preferred.y
					b["wander"]=rng.randf_range(3,6)
				_wander(b,dt,0.75)
	if day >= next_growth:
		next_growth += 80.0
		_grow_economies()
	if day >= next_birth:
		next_birth += 120.0
		_new_children()
	politics.advance(self, dt)
	# IA local atualiza necessidades, trabalhos, relacionamentos e aldeias.
	# Usa tempo da simulacao: pausa impede progresso e fechar o app nao avanca o mundo.
	agent_ai.advance(self, dt, controlled_id)
	_update_campaigns()
	for town in towns:
		progress_construction(town, dt)

func construction_cost(kind: String) -> float:
	match kind:
		"campfire": return 10.0
		"house": return 14.0
		"upgrade": return 18.0
		"castle": return 80.0
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
	if kind=="upgrade" and upgrade_index(town)<0: return false
	if kind=="castle" and (int(town["level"])<4 or bool(town.get("castle",false)) or not bool(town.get("forge",false))):
		news="Castelo exige era 4 e forja."
		return false
	if float(town.get("stone",0))<workshop_stone_cost(kind):
		news="Pedra insuficiente para a obra."
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
	var label:String={"castle":"castelo","upgrade":"melhoria de casa","campfire":"fogueira","house":"casa","farm":"fazenda","oven":"forno","forge":"forja","crossing":"ponte"}[kind]
	town["construction"]={"kind":kind,"progress":0.0,"duration":float({"castle":85,"upgrade":24,"campfire":8,"house":12,"farm":15,"oven":20,"forge":32,"crossing":26}[kind])}
	var stone_cost:float=workshop_stone_cost(kind)
	town["stone"]=float(town.get("stone",0))-stone_cost
	_prepare_project(town)

	sound_at("build",town)
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
	var old_progress:float=float(site["progress"])
	site["progress"]=minf(float(site["duration"])*fraction,old_progress+dt*(1.0+minf(float(helpers)*0.35,0.9)))
	if floori(old_progress/2.0)<floori(float(site["progress"])/2.0): sound_at("build",site)

	if float(site["progress"]) < float(site.get("duration", 12.0)):
		return
	var kind: String = str(site["kind"])
	sound_at("complete",site)
	for worker in people:
		if bool(worker["alive"]) and int(worker["town"])==int(town["id"]) and str(worker.get("task",""))=="Construindo" and Vector2(float(worker["x"]),float(worker["y"])).distance_to(Vector2(float(site["x"]),float(site["y"])))<1.1:
			gain_xp(worker,15.0,"trabalho")
	if kind == "house":
		var levels:Array=house_levels(town)
		levels.append(1)
		town["houses"] = int(town.get("houses", 2)) + 1
	elif kind=="upgrade":
		var levels:Array=house_levels(town)
		var index:int=int(site.get("house_index",0))
		if index>=0 and index<levels.size(): levels[index]=mini(4,int(levels[index])+1)
	elif kind=="farm":
		town["farms"]=int(town.get("farms",1))+1
	else:
		town[kind]=true
		sites.append({"kind":kind,"x":site["x"],"y":site["y"],"town":town["id"]})
	town["construction"]={}
	var label:String={"castle":"Castelo construido","upgrade":"Casa ampliada","campfire":"Fogueira acesa","house":"Casa pronta","farm":"Fazenda pronta","oven":"Forno construido","forge":"Forja construida","crossing":"Ponte construida"}[kind]
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
		if active_population(town_id) >= housing_capacity(town) or float(town["food"]) < 8.0:
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
		sound_at("birth",get_person(baby_id))
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
	sound_at("death",person)
	agent_ai.on_death(self, person)
	var town: Dictionary = get_town(int(person["town"]))
	if not town.is_empty() and int(town["leader"]) == int(person["id"]):
		choose_successor(town, int(person["id"]))

func choose_successor(town: Dictionary, former_id: int) -> void:
	var candidates:Array=[]
	for person in people:
		if not bool(person["alive"]) or int(person["town"])!=int(town["id"]) or int(person["id"])==former_id: continue
		if float(person["age"])<16: continue
		init_traits(person)
		candidates.append(person)
	if candidates.is_empty():
		town["leader"]=0
		return
	candidates.sort_custom(func(a,b): return leadership_score(a)>leadership_score(b))
	var successor:Dictionary=candidates[0]
	var former:Dictionary=get_person(int(town["leader"]))
	if not former.is_empty() and bool(former["alive"]): former["role"]="Aldeao"
	town["leader"]=successor["id"]
	successor["role"]=ruler_title(town,successor)
	news=str(successor["name"])+" foi escolhido para liderar "+str(town["name"])+"."
	var history:Array=town.get("historical_events",[])
	history.append({"day":int(day),"event":news})
	town["historical_events"]=history

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

func _predator_attacks(dt:float) -> void:
	if not predators: return
	for beast in beasts:
		if bool(beast.get("alive",false)): _hostile_animal_step(beast,dt)


func save_world() -> bool:
	var file := FileAccess.open("user://world.json", FileAccess.WRITE)
	if file == null:
		return false
	var data := {
		"tiles": tiles, "towns": towns, "people": people, "beasts": beasts,
		"trees": trees, "next_seed_day": next_seed_day,
		"wildlife": wildlife, "sites": sites, "rivers_v58":rivers_v58, "habitats_v59":habitats_v59, "ecology_v60":ecology_v60,
		"swamp_witch":swamp_witch,"swamp_spiders":swamp_spiders,"swamp_clock":swamp_clock,"resource_drops":resource_drops,
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
		swamp_witch=value.get("swamp_witch",{})
		swamp_spiders=value.get("swamp_spiders",[])
		for spider in swamp_spiders:
			if not spider.has("max_health"):
				spider["health"]=clampf(float(spider.get("health",35))/35.0*50.0,0,50)
				spider["max_health"]=50.0
		resource_drops=value.get("resource_drops",[])
		swamp_clock=float(value.get("swamp_clock",0))
		magic_bolts.clear()
		sound_events.clear()
		wildlife = value.get("wildlife",[])
		sites = value.get("sites",[])
		rivers_v58=bool(value.get("rivers_v58",false))
		if not rivers_v58:
			_connect_rivers()
			_prepare_sites()
		elif sites.is_empty(): _prepare_sites()
		for i in range(sites.size()-1,-1,-1):
			var site:Dictionary=sites[i]
			if str(site["kind"]) in ["campfire","oven","forge","crossing","castle"]:
				var owner:Dictionary=get_town(int(site["town"]))
				if not bool(owner.get(str(site["kind"]),false)): sites.remove_at(i)
		if not value.has("wildlife"): _seed_wildlife()
		habitats_v59=bool(value.get("habitats_v59",false))
		if not habitats_v59: _seed_habitat_animals()
		ecology_v60=bool(value.get("ecology_v60",false))
		if not ecology_v60: _seed_extra_animals()
		for animal in wildlife: init_animal_health(animal)
		for beast in beasts: init_animal_health(beast)
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
			if rng.randf() < (0.93 if kind=="forest" else (0.78 if kind=="snow" else (0.56 if kind=="swamp" else 0.14))):
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
	_mark_action(actor,"chopping",1.2)
	tree["state"]="falling"
	tree["fall"]=0.0
	tree["regrow"]=day+rng.randf_range(50.0,100.0)
	actor["wood"]=int(actor.get("wood",0))+3
	if resource_drops.size()<180:
		resource_drops.append({"id":new_id(),"source":-1,"x":float(x),"y":float(y),"items":{"fiber":2},"remaining":180.0})
	if actor.has("town"): gain_xp(actor,3.0,"trabalho")
	tree_revision+=1
	sound_at("wood",actor)
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
		for kind in ["campfire","oven","forge","crossing","castle"]:
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
		init_animal_health(animal)
		if float(animal["health"])<=0.0: continue
		animal["attack_cd"]=maxf(0.0,float(animal.get("attack_cd",0))-dt)
		var species:String=str(animal["species"])
		var p:=Vector2(float(animal["x"]),float(animal["y"]))
		var kind:String=str(tiles[clampi(int(p.y),0,SIZE-1)][clampi(int(p.x),0,WIDTH-1)])
		animal["hunger"]=clampf(float(animal.get("hunger",rng.randf_range(0,35)))+dt*0.48,0,100)
		if float(animal["hunger"])>=100.0:
			animal["health"]=maxf(0.0,float(animal["health"])-dt*0.18)
			if float(animal["health"])<=0.0:
				_drop_animal_resources(animal)
				continue
		elif float(animal["hunger"])<30.0:
			animal["health"]=minf(float(animal["max_health"]),float(animal["health"])+dt*0.16)
		if _bird_flight(animal,dt): continue
		if predators and _hostile_animal_step(animal,dt): continue
		animal["timer"]=float(animal["timer"])-dt
		animal["breed_timer"]=maxf(0,float(animal.get("breed_timer",rng.randf_range(90,200)))-dt)
		if float(animal["timer"])<=0:
			_choose_animal_action(animal,p,kind)
			if int(swamp_clock*10+float(animal["id"]))%7==0:
				var effect:String=str({"chicken":"chicken","duck":"duck","frog":"frog","heron":"bird","deer":"animal","boar":"animal","crocodile":"growl","fox":"animal","camel":"animal"}.get(species,""))
				if not effect.is_empty(): sound_at(effect,animal)
		var state:String=str(animal.get("state","Andando"))
		var goal:=Vector2(float(animal["tx"]),float(animal["ty"]))
		var pace:float=float({"chicken":0.35,"deer":0.65,"rabbit":0.72,"frog":0.48,"capybara":0.37,"heron":0.60,"camel":0.48,"lizard":0.45,"snow_hare":0.72,"crocodile":0.52,"turtle":0.19,"duck":0.54,"boar":0.58,"fox":0.68}.get(species,0.42))
		if state in ["Fugindo","Cacando"]: pace*=1.75
		if species=="crocodile" and kind=="water": pace*=1.4
		if state in ["Saltando","Pulando"] and fposmod(float(animal["timer"])*3.0,1.0)>0.55: pace=0.0
		if state in ["Descansando","Aquecendo","Emboscando","Pescando","Pastando","Bicando","Fuçando","Comendo"]: pace=0.0
		var n:=p.move_toward(goal,dt*pace)
		n=_animal_avoid_buildings(n,p)
		animal["x"]=n.x
		animal["y"]=n.y
		if state in ["Pescando","Pastando","Bicando","Fuçando","Comendo"]:
			animal["hunger"]=maxf(0,float(animal["hunger"])-dt*3.0)
		if state=="Cacando" and float(animal["attack_cd"])<=0:
			for prey in wildlife:
				if int(prey["id"])!=int(animal.get("prey",-1)) or float(prey.get("health",1))<=0 or float(prey.get("flight_height",0))>0.25: continue
				if p.distance_to(Vector2(float(prey["x"]),float(prey["y"])))<0.45:
					animal["attack_cd"]=2.0
					if damage_animal(prey,animal_damage(animal)):
						animal["hunger"]=maxf(0,float(animal["hunger"])-45.0)
						_consume_prey_meat(prey)
						animal["state"]="Comendo"
						animal["timer"]=3.0
					else:
						prey["state"]="Fugindo"
						prey["timer"]=0.0
						animal["timer"]=0.0
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
				child["health"]=child["max_health"]
				child["attack_cd"]=0.0
				child["state"]="Descansando"
				child["flight_height"]=0.0
				child["flight_time"]=0.0
				births.append(child)
	for index in range(wildlife.size()-1,-1,-1):
		if float(wildlife[index].get("health",1))<=0: wildlife.remove_at(index)
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
		if int(other["id"])==int(animal["id"]) or float(other.get("health",1))<=0: continue
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
	elif not animal_habitat(species,kind) and rng.randf()<0.65:
		q=_preferred_animal_destination(p,species)
		animal["state"]="Migrando"
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
	return float({"oven":12,"forge":24,"crossing":4,"upgrade":12,"castle":120}.get(kind,0))

func workshop_position(town:Dictionary,kind:String) -> Vector2:
	var origin:=Vector2(float(town["x"]),float(town["y"]))
	if kind=="campfire": return origin+Vector2(0.7,1.0)
	if kind=="castle": return origin+Vector2(0,-3.0)
	if kind in ["house","upgrade"]:
		var spots:Array[Vector2]=[Vector2(0,-0.35),Vector2(1.60,0.35),Vector2(-1.25,-0.75),Vector2(2.15,-0.85),Vector2(-2.4,0.15),Vector2(0.95,-1.65),Vector2(-1.35,1.45),Vector2(2.9,1.15)]
		return origin+spots[clampi(upgrade_index(town) if kind=="upgrade" else int(town.get("houses",2)),0,7)]
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
		"Lobo","Urso": return kind in ["forest","grass","snow"]
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
	return float({"wood":2.0,"stone":3.0,"ore":3.0,"metal":3.0,"food":1.0,"water":1.0,"fish":1.0,"meat":1.0,"hide":1.0,"croc_hide":1.5,"feather":0.15,"bone":0.7,"shell":1.5,"fiber":0.2,"cord":0.4,"club":2.0,"spear":2.0,"bow":1.0,"sword":3.0,"pickaxe":3.0,"iron_pickaxe":4.0,"arrows":0.1,"hoe":3.0,"axe":2.0,"rod":1.0,"wood_shield":3.0,"iron_shield":5.0}.get(kind,1.0))

func load_capacity(p:Dictionary) -> float:
	var base:float=22.0
	if p.has("age"):
		base=[0.0,7.0,22.0,20.0][life_stage(p)]
	return base+float({"basket":12,"cart":48}.get(str(p.get("transport","hands")),0))

func carried_weight(p:Dictionary) -> float:
	var total:float=0.0
	for key in RESOURCE_NAMES.keys():
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
	if kind=="upgrade": project["house_index"]=upgrade_index(town)
	project["required"]={"wood":construction_cost(kind),"stone":workshop_stone_cost(kind)}
	project["delivered"]={"wood":0.0,"stone":0.0}
	project["project_id"]=new_id()
	project["progress"]=0.0

func transport_job(p:Dictionary,town:Dictionary) -> bool:
	if is_military(p): return false
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
				sound_at("deposit",p)
				gain_xp(p,2.0+float(cargo["amount"])*0.4,"trabalho")
				p["cargo"]={}
				p["task"]="Construindo"
			return true
		var storage_key:String=preferred_storage(town,str(cargo["kind"]),p)
		var storage_pos:Vector2=storage_position(town,storage_key)
		_set_delivery_goal(p,storage_pos,"Levando recursos")
		if pos.distance_to(storage_pos)<0.65:
			var key:String=str(cargo["kind"])
			store_resource(town,storage_key,key,float(cargo["amount"]))
			sound_at("deposit",p)
			gain_xp(p,2.0+float(cargo["amount"])*0.4,"trabalho")
			p["cargo"]={}
		return true
	if project.is_empty() or float(p["age"])<16.0: return false
	_prepare_project(town)
	# Dois adultos por aldeia trabalham na obra, os demais mantem producao.
	var rank:int=0
	for other in people:
		if not bool(other["alive"]) or int(other["town"])!=int(town["id"]) or float(other["age"])<16.0 or is_military(other): continue
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
	var action:String=str({"stone":"mining","ore":"mining","fish":"fishing","food":"farming","wood":"chopping"}.get(kind,""))
	if not action.is_empty(): _mark_action(p,action,1.2)
	var effect:String=str({"stone":"mine","ore":"mine","fish":"fish","food":"harvest","meat":"pickup","wood":"pickup"}.get(kind,"pickup"))
	sound_at(effect,p)
	return true

func add_resource(p:Dictionary,kind:String,amount:int) -> bool:
	if free_load(p)<resource_weight(kind)*amount:
		news="Carga cheia. Deposite os recursos na aldeia."
		return false
	p[kind]=int(p.get(kind,0))+amount
	if p.has("town"): gain_xp(p,float(amount),"trabalho")
	return true

func deposit_inventory(p:Dictionary) -> bool:
	var town:Dictionary=get_town(int(p.get("town",0)))
	if town.is_empty(): return false
	if Vector2(float(p["x"]),float(p["y"])).distance_to(Vector2(float(town["x"]),float(town["y"])))>1.2:
		news="Aproxime-se do centro da aldeia para descarregar."
		return false
	for key in RESOURCE_NAMES.keys():
		store_resource(town,preferred_storage(town,str(key),p),str(key),float(p.get(key,0)))
		p[key]=0
	var cargo:Dictionary=p.get("cargo",{})
	if not cargo.is_empty() and not bool(cargo.get("project",false)):
		var kind:String=str(cargo["kind"])
		store_resource(town,preferred_storage(town,kind,p),kind,float(cargo["amount"]))
		p["cargo"]={}
	news="Recursos entregues ao estoque da aldeia."
	return true

func house_levels(town:Dictionary) -> Array:
	if not town.has("house_levels"): town["house_levels"]=[]
	var levels:Array=town["house_levels"]
	while levels.size()<int(town.get("houses",2)): levels.append(1)
	return levels

func housing_capacity(town:Dictionary) -> int:
	var total:int=0
	for level in house_levels(town):
		total+=[4,6,10,14][clampi(int(level)-1,0,3)]
	if bool(town.get("castle",false)): total+=8
	return total

func upgrade_index(town:Dictionary) -> int:
	var levels:Array=house_levels(town)
	var cap:int=mini(4,maxi(int(town["level"]),2 if int(town.get("houses",0))>=3 and active_population(int(town["id"]))>=8 else 1))
	for i in range(levels.size()):
		if int(levels[i])<cap: return i
	return -1

func ruler_title(town:Dictionary,p:Dictionary) -> String:
	if int(town["level"])<4: return "Lider tribal"
	return "Rei" if int(p["gender"])==0 else "Rainha"

func strength(p:Dictionary) -> float:
	return float(p.get("strength",35+posmod(int(p["id"])*37,61)))

func defense(p:Dictionary) -> float:
	return float([0,2,5,9,14][clampi(int(p.get("armor",0)),0,4)])+(2.0 if bool(p.get("combat_training",false)) else 0.0)+(2.0 if str(p.get("armor_material",""))=="croc_hide" else 0.0)

func attack_damage(p:Dictionary) -> float:
	return 2.0+strength(p)*0.05+float([0,2,5,9,14][clampi(int(p.get("weapon",0)),0,4)])+(4.0 if bool(p.get("combat_training",false)) else 0.0)+(2.0 if bool(p.get("feather_arrows",false)) else 0.0)

func is_military(person:Dictionary) -> bool:
	return str(person.get("military_role","")) in ["royal","soldier","archer","general"]

func army_members(town:Dictionary,include_royal:bool=true) -> Array:
	var result:Array=[]
	for person in people:
		if bool(person["alive"]) and int(person["town"])==int(town["id"]) and is_military(person) and (include_royal or str(person["military_role"])!="royal"): result.append(person)
	return result

func kingdom_id(town:Dictionary) -> int:
	return int(town.get("kingdom",town["id"]))

func army_limit(population:int,eligible:int,era:int) -> int:
	var limit:int=floori(float(population)*[0.16,0.20,0.25,0.30,0.30][clampi(era-1,0,4)])
	if population>=6 and eligible>=3: limit=maxi(1,limit)
	return mini(limit,maxi(0,mini(eligible-2,floori(float(eligible)*0.5))))

func royal_guard_size(count:int) -> int:
	if count>=25: return 10
	if count>=12: return 5
	if count>=3: return 2
	return mini(1,count)

func _release_military(person:Dictionary) -> void:
	if is_military(person) or str(person.get("profession","")) in ["Guarda","Guarda pessoal","Guerreiro","Arqueiro","General"]:
		person["profession"]=str(person.get("civil_profession","Agricultor"))
		if str(person["profession"]) in ["Guarda","Guarda pessoal","Guerreiro","Arqueiro","General","Crianca"]: person["profession"]="Agricultor"
		person["role"]="Aldeao"
	person["military_role"]=""

func _assign_military(person:Dictionary,kind:String,town:Dictionary,slot:int) -> void:
	if not is_military(person):
		if not person.has("civil_profession"):
			var profession:String=str(person.get("profession","Agricultor"))
			person["civil_profession"]="Agricultor" if profession in ["Guarda","Guarda pessoal","Guerreiro","Arqueiro","General","Crianca","Governante"] else profession
		# Civis devem terminar entregas antes do recrutamento.
	person["military_role"]=kind
	person["military_slot"]=slot
	person["profession"]=str({"royal":"Guarda pessoal","soldier":"Guerreiro","archer":"Arqueiro","general":"General"}[kind])
	person["role"]=str({"royal":"Guarda real" if int(town["level"])>=4 else "Guarda tribal","soldier":"Guerreiro","archer":"Arqueiro","general":"General"}[kind])
	person["specialty_v57"]=true
	train_guard(person)

func update_roles(town:Dictionary) -> void:
	if not bool(town.get("merit_election",false)) or int(town["leader"])==0:
		choose_successor(town,0)
		town["merit_election"]=true
		town["law"]="merito"
	var leader:Dictionary=get_person(int(town["leader"]))
	if not leader.is_empty() and bool(leader["alive"]):
		_release_military(leader)
		leader["role"]=ruler_title(town,leader) if kingdom_id(town)==int(town["id"]) else "Governador"
		leader["profession"]="Governante"
		leader["specialty_v57"]=true
	var adults:Array=[]
	for person in people:
		if not bool(person["alive"]) or int(person["town"])!=int(town["id"]) or int(person["id"])==int(town["leader"]): continue
		if float(person["age"])>=16 and float(person["age"])<65:
			adults.append(person)
		else: _release_military(person)
	# Nao repor mortos nem reorganizar tropas durante uma campanha.
	if int(town.get("siege_by",0))>0 or int(town.get("raid_target",0))>0: return
	adults.sort_custom(func(a,b): return strength(a)+float(a.get("war_xp",0))*0.30>strength(b)+float(b.get("war_xp",0))*0.30)
	var count:int=army_limit(active_population(int(town["id"])),adults.size(),int(town["level"]))
	var royal:int=mini(royal_guard_size(count),maxi(0,count-1)) if kingdom_id(town)==int(town["id"]) else 0
	var field:Array=[]
	var assigned:int=0
	for person in adults:
		if not person.get("cargo",{}).is_empty():
			_release_military(person)
			continue
		if assigned<royal: _assign_military(person,"royal",town,assigned)
		elif assigned<count: field.append(person)
		else:
			_release_military(person)
			continue
		assigned+=1
	field.sort_custom(func(a,b): return float(a.get("intelligence",50))+float(a.get("level",1))*5.0>float(b.get("intelligence",50))+float(b.get("level",1))*5.0)
	var generals:int=mini(2,floori(float(field.size())/7.0)) if int(town["level"])>=3 else 0
	var archers:int=maxi(1,floori(float(field.size()-generals)*0.35)) if int(town["level"])>=2 and field.size()-generals>=3 else 0
	for index in range(field.size()):
		_assign_military(field[index],"general" if index<generals else ("archer" if index<generals+archers else "soldier"),town,index)

func military_duty(person:Dictionary,town:Dictionary,step:float) -> void:
	var role:String=str(person.get("military_role",""))
	var ruler:Dictionary=get_person(int(town["leader"]))
	var origin:=Vector2(float(town["x"]),float(town["y"]))
	var pos:=Vector2(float(person["x"]),float(person["y"]))
	var slot:int=int(person.get("military_slot",0))
	var goal:=origin
	var enemy:Dictionary={}
	var enemy_town:Dictionary={}
	if role!="royal" and wars:
		enemy_town=get_town(int(town.get("raid_target",0)))
		if enemy_town.is_empty(): enemy_town=get_town(int(town.get("siege_by",0)))
	if role=="royal" and not ruler.is_empty() and bool(ruler["alive"]):
		var total:int=0
		for guard in army_members(town):
			if str(guard["military_role"])=="royal": total+=1
		var angle:float=float(slot)*TAU/maxi(1,total)
		goal=Vector2(float(ruler["x"]),float(ruler["y"]))+Vector2(cos(angle),sin(angle))*(0.7 if total<=2 else 1.1)
		_set_delivery_goal(person,goal,"Protegendo governante")
	elif not enemy_town.is_empty() and kingdom_id(enemy_town)!=kingdom_id(town):
		var invading:bool=int(town.get("raid_target",0))==int(enemy_town["id"])
		var best:float=1000.0
		var tactics:int=army_tactics(town)
		for other in army_members(enemy_town):
			if not invading and Vector2(float(other["x"]),float(other["y"])).distance_to(origin)>5.0: continue
			var q:=Vector2(float(other["x"]),float(other["y"]))
			var distance:float=pos.distance_to(q)
			var priority:float=distance
			if tactics>=1 and not str(person.get("shield_kind","")).is_empty() and str(other.get("military_role",""))=="archer": priority*=0.6
			if priority<best:
				best=priority
				enemy=other
		goal=Vector2(float(enemy_town["x"]),float(enemy_town["y"])) if invading else origin
		if not enemy.is_empty():
			goal=Vector2(float(enemy["x"]),float(enemy["y"]))
			var distance:float=pos.distance_to(goal)
			if role=="archer" and str(person.get("weapon_kind",""))=="bow" and int(person.get("ammo",0))>0 and distance<2.0: goal=pos
			elif tactics>=1 and role=="archer":
				var escort:Dictionary=nearby_shield(person,town,3.0)
				if not escort.is_empty():
					var front:=Vector2(float(escort["x"]),float(escort["y"]))
					goal=front+(front-goal).normalized()*0.7
		if tactics>=2 and role=="soldier" and str(person.get("shield_kind","")).is_empty() and not enemy.is_empty() and pos.distance_to(goal)>1.1:
			var heading:Vector2=(goal-origin).normalized()
			goal+=Vector2(-heading.y,heading.x)*(0.55 if slot%2==0 else -0.55)
		_set_delivery_goal(person,goal,"Marchando para conquista" if invading else "Defendendo aldeia")
	else:
		var angle:float=float(slot)*2.39996+day*0.035
		goal=origin+Vector2(cos(angle),sin(angle))*(2.2 if role=="archer" else (1.0 if role=="general" else 3.0))
		_set_delivery_goal(person,goal,"Vigiando com arco" if role=="archer" else ("Comandando exercito" if role=="general" else "Patrulhando aldeia"))
	if role=="royal" and wars:
		var best:float=0.9
		for other in people:
			if not bool(other["alive"]) or not is_military(other) or int(other["town"])==int(town["id"]): continue
			var other_town:Dictionary=get_town(int(other["town"]))
			if other_town.is_empty() or kingdom_id(other_town)==kingdom_id(town) or politics.get_status(self,int(town["id"]),int(other["town"]))!="war": continue
			var q:=Vector2(float(other["x"]),float(other["y"]))
			var d:float=pos.distance_to(q)
			if d<best and q.distance_to(goal)<1.5:
				best=d
				enemy=other
	person["target_x"]=clampf(float(person["target_x"]),1,WIDTH-2)
	person["target_y"]=clampf(float(person["target_y"]),1,SIZE-2)
	if not enemy.is_empty() and float(person.get("military_cd",0))<=0:
		var d:float=pos.distance_to(Vector2(float(enemy["x"]),float(enemy["y"])))
		var ranged:bool=role=="archer" and str(person.get("weapon_kind",""))=="bow" and int(person.get("ammo",0))>0
		if d<(2.2 if ranged else 0.9):
			person["military_cd"]=(1.8 if ranged else 1.1)*maxf(0.75,1.0-float(person.get("war_xp",0))*0.001)
			_mark_action(person,"combat",1.0)
			if ranged:
				person["ammo"]=int(person["ammo"])-1
				sound_at("bow",person)
				magic_bolts.append({"x":pos.x,"y":pos.y,"target":enemy["id"],"kind":"human","life":3.0,"damage":attack_damage(person),"caster":person["id"],"arrow":true})
			else:
				sound_at("sword" if str(person.get("weapon_kind",""))=="sword" else "hit",person)
				_swamp_damage(enemy,attack_damage(person))
				gain_xp(person,2.0 if bool(enemy["alive"]) else 12.0,"combate")
				gain_war_xp(person,town,2.0 if bool(enemy["alive"]) else 10.0)
			person["task"]="Defendendo governante" if role=="royal" else "Combatendo inimigo"
	town["morale"]=minf(100,float(town.get("morale",60))+step*0.08)

func begin_campaign(attacker:Dictionary,defender:Dictionary) -> bool:
	if kingdom_id(attacker)==kingdom_id(defender) or int(attacker.get("raid_target",0))>0 or int(attacker.get("siege_by",0))>0 or int(defender.get("siege_by",0))>0 or int(defender.get("raid_target",0))>0: return false
	if army_members(attacker,false).is_empty(): return false
	sound_at("war",attacker)
	attacker["raid_target"]=defender["id"]
	defender["siege_by"]=attacker["id"]
	news=str(attacker["name"])+" enviou seu exercito contra "+str(defender["name"])+"."
	return true

func _update_campaigns() -> void:
	for attacker in towns:
		var target:int=int(attacker.get("raid_target",0))
		if target<=0: continue
		var defender:Dictionary=get_town(target)
		var troops:Array=army_members(attacker,false)
		if defender.is_empty() or troops.is_empty() or not wars or politics.get_status(self,int(attacker["id"]),target)!="war":
			attacker["raid_target"]=0
			if not defender.is_empty(): defender["siege_by"]=0
			continue
		if not army_members(defender).is_empty(): continue
		var origin:=Vector2(float(defender["x"]),float(defender["y"]))
		for soldier in troops:
			if Vector2(float(soldier["x"]),float(soldier["y"])).distance_to(origin)<1.1:
				annex_town(attacker,defender)
				break

func annex_town(attacker:Dictionary,defender:Dictionary) -> void:
	var old_kingdom:int=kingdom_id(defender)
	var new_kingdom:int=kingdom_id(attacker)
	if old_kingdom==new_kingdom: return
	loot_stock(attacker,defender)
	for veteran in army_members(attacker,false): gain_war_xp(veteran,attacker,12.0)
	attacker["victories"]=int(attacker.get("victories",0))+1
	sound_at("complete",defender)
	for town in towns:
		if kingdom_id(town)==old_kingdom:
			town["kingdom"]=new_kingdom
			town["raid_target"]=0
			town["siege_by"]=0
	attacker["raid_target"]=0
	defender["siege_by"]=0
	politics.set_treaty(self,int(attacker["id"]),int(defender["id"]),"peace")
	news=str(attacker["name"])+" conquistou e anexou "+str(defender["name"])+"!"
	for town in [attacker,defender]:
		var history:Array=town.get("historical_events",[])
		history.append({"day":int(day),"event":news})
		town["historical_events"]=history

func equip_worker(town:Dictionary,p:Dictionary) -> void:
	if float(p["age"])<16: return
	var era:int=clampi(int(town["level"]),1,4)
	var is_guard:bool=is_military(p)
	var is_ruler:bool=int(p["id"])==int(town["leader"])
	if is_guard or is_ruler:
		var target:int=era if bool(town.get("forge",false)) else mini(era,2)
		if target<=2 and float(town.get("wood",0))>=2:
			if float(town.get("croc_hide",0))>=2 and str(p.get("armor_material",""))!="croc_hide":
				town["croc_hide"]=float(town["croc_hide"])-2
				town["wood"]=float(town["wood"])-2
				p["armor"]=2
				p["armor_material"]="croc_hide"
			elif int(p.get("armor",0))<target and float(town.get("hide",0))>=2:
				town["hide"]=float(town["hide"])-2
				town["wood"]=float(town["wood"])-2
				p["armor"]=target
				p["armor_material"]="hide"
			elif int(p.get("armor",0))<2 and float(town.get("shell",0))>=2:
				town["shell"]=float(town["shell"])-2
				town["wood"]=float(town["wood"])-2
				p["armor"]=2
				p["armor_material"]="shell"
			elif int(p.get("armor",0))==0 and float(town.get("bone",0))>=2:
				town["bone"]=float(town["bone"])-2
				town["wood"]=float(town["wood"])-2
				p["armor"]=1
				p["armor_material"]="bone"
		elif target>2 and int(p.get("armor",0))<target and float(town.get("wood",0))>=2 and float(town.get("metal",0))>=4:
			town["wood"]=float(town["wood"])-2
			town["metal"]=float(town["metal"])-4
			p["armor"]=target
			p["armor_material"]="metal"
		if str(p.get("military_role",""))!="archer":
			var shield:String=str(p.get("shield_kind",""))
			for item in ["iron_shield","wood_shield"]:
				if shield==item: break
				if not take_equipment(town,p,item): continue
				if not shield.is_empty(): store_resource(town,preferred_storage(town,shield,p),shield,1)
				p["shield_kind"]=item
				break
		var kind:String=str(p.get("weapon_kind",""))
		var desired:Array=["bow","spear","club"] if str(p.get("military_role",""))=="archer" else ["sword","spear","club"]
		for item in desired:
			if kind==item: break
			if float(town.get(item,0))<1.0: continue
			if not take_equipment(town,p,str(item)): continue
			if not kind.is_empty() and RESOURCE_NAMES.has(kind): store_resource(town,preferred_storage(town,kind,p),kind,1)
			p["weapon_kind"]=item
			p["weapon"]=int({"club":1,"spear":2,"bow":2,"sword":4}[item])
			break
		if str(p.get("weapon_kind",""))=="bow" and int(p.get("ammo",0))<3:
			for n in range(6):
				if not take_equipment(town,p,"arrows"): break
				p["ammo"]=int(p.get("ammo",0))+1
	else:
		var profession:String=str(p.get("profession",""))
		var desired:Array=[]
		match profession:
			"Minerador": desired=["iron_pickaxe","pickaxe"]
			"Agricultor": desired=["hoe"]
			"Construtor": desired=["axe"]
			"Pescador": desired=["rod"]
		var current:String=str(p.get("tool_kind",""))
		for item in desired:
			if current==item: break
			if float(town.get(item,0))<1 or not take_equipment(town,p,str(item)): continue
			if not current.is_empty() and RESOURCE_NAMES.has(current): store_resource(town,preferred_storage(town,current,p),current,1)
			p["tool_kind"]=item
			p["tool"]=3 if item=="iron_pickaxe" else 1
			break

func init_traits(person:Dictionary) -> void:
	var id:int=int(person["id"])
	if not person.has("diplomacy"): person["diplomacy"]=35+posmod(id*71+19,61)
	if not person.has("intelligence"): person["intelligence"]=35+posmod(id*53+29,61)
	if not person.has("strength"): person["strength"]=35+posmod(id*37,61)
	if not person.has("aggression"): person["aggression"]=posmod(id*43+13,101)
	if not person.has("level"): person["level"]=1
	if not person.has("xp"): person["xp"]=0.0
	if not person.has("combat_training"): person["combat_training"]=false
	if not person.has("max_health"): person["max_health"]=100.0

func leadership_score(person:Dictionary) -> float:
	init_traits(person)
	return float(person["diplomacy"])*0.40+float(person["intelligence"])*0.35+strength(person)*0.25

func leader_aggression(town:Dictionary) -> float:
	var person:Dictionary=get_person(int(town["leader"]))
	if person.is_empty(): return 0.0
	init_traits(person)
	var mind:Dictionary=person.get("mind",{})
	return clampf(float(person["aggression"])*0.70+(1.0-float(mind.get("kindness",0.5)))*30.0,0,100)

func leader_diplomacy(town:Dictionary) -> float:
	var person:Dictionary=get_person(int(town["leader"]))
	if person.is_empty(): return 0.0
	init_traits(person)
	return float(person["diplomacy"])

# Ferramenta criadora: cada toque cria exatamente um ser, sem fabricar aldeias prontas.
const SPAWN_NAMES:Dictionary={
	"human":"Humano","chicken":"Galinha","deer":"Veado","rabbit":"Coelho",
	"frog":"Sapo","capybara":"Capivara","heron":"Garca","camel":"Camelo",
	"lizard":"Lagarto","snow_hare":"Lebre da neve","crocodile":"Crocodilo",
	"turtle":"Tartaruga","duck":"Pato","boar":"Javali","fox":"Raposa",
	"wolf":"Lobo","bear":"Urso","witch":"Bruxa do brejo"
}

func spawn_creature(species:String,point:Vector2) -> bool:
	if not SPAWN_NAMES.has(species): return false
	if point.x<1.0 or point.x>WIDTH-2 or point.y<1.0 or point.y>SIZE-2:
		news="Escolha um local dentro do mapa."
		return false
	var p:=point
	var terrain:String=str(tiles[int(p.y)][int(p.x)])
	if species=="witch":
		if bool(swamp_witch.get("alive",false)):
			news="Ja existe uma bruxa viva neste mundo."
			return false
		if terrain in ["water","mountain"]:
			news="Crie a bruxa em terra firme."
			return false
		var awarded:bool=bool(swamp_witch.get("staff_awarded",swamp_witch.has("killer")))
		swamp_witch={"name":"Bruxa do brejo","x":p.x,"y":p.y,"tx":p.x,"ty":p.y,"health":500.0,"max_health":500.0,"alive":true,"cast":3.0,"summon":2.0,"wander":3.0,"state":"Vigiando","manual_spawn":true,"staff_awarded":awarded}
		sound_event("summon",p)
		news="Bruxa do brejo criada no mapa."
		return true
	if species=="human":
		if terrain in ["water","mountain"]:
			news="Humanos precisam de terra firme."
			return false
		var living:int=0
		for person in people:
			if bool(person["alive"]): living+=1
		if living>=240:
			news="Limite de moradores atingido para preservar o desempenho."
			return false
		var town:Dictionary={}
		var best:float=5.0
		for other in towns:
			var distance:float=p.distance_to(Vector2(float(other["x"]),float(other["y"])))
			if distance<best:
				best=distance
				town=other
		if town.is_empty():
			if towns.size()>=12:
				news="Limite de aldeias. Crie um morador perto de uma aldeia existente."
				return false
			town=_found_empty_town(p)
		var id:int=make_person(int(town["id"]),p.x,p.y,20)
		var person:Dictionary=get_person(id)
		if int(town["leader"])==0:
			person["profession"]="Construtor"
			person["specialty_v57"]=true
			choose_successor(town,0)
			town["merit_election"]=true
		sound_event("spawn",p)
		news="%s chegou a %s."%[person["name"],town["name"]]
		return true
	if wildlife.size()+beasts.size()>=160:
		news="Limite de animais atingido."
		return false
	if species in ["wolf","bear"]:
		var id:int=new_id()
		var label:String=str(SPAWN_NAMES[species])
		beasts.append({"id":id,"name":label+" "+str(id),"species":label,"x":p.x,"y":p.y,"health":90.0 if species=="bear" else 55.0,"food":4,"wander":0.0,"target_x":p.x,"target_y":p.y,"alive":true,"temper":50,"color":0})
	else:
		wildlife.append({"id":100000+new_id(),"species":species,"x":p.x,"y":p.y,"tx":p.x,"ty":p.y,"timer":0.2,"hunger":15.0,"breed_timer":120.0,"state":"Explorando"})
	sound_event("spawn",p)
	if species in ["wolf","bear"]: init_animal_health(beasts.back())
	else: init_animal_health(wildlife.back())
	news=str(SPAWN_NAMES[species])+" criado no mapa."
	return true

func _found_empty_town(p:Vector2) -> Dictionary:
	var id:int=new_id()
	var town:Dictionary={"id":id,"name":"Nova tribo "+str(id),"x":int(p.x),"y":int(p.y),"hostile":false,"leader":0,"food":10.0,"wood":0.0,"stone":0.0,"water":8.0,"knowledge":0.0,"level":1,"law":"merito","home_biome":str(tiles[int(p.y)][int(p.x)]),"clothing":0.0,"drought_preparation":false,"houses":0,"house_levels":[],"farms":0,"campfire":false,"oven":false,"forge":false,"crossing":false,"castle":false,"construction":{},"historical_events":[]}
	towns.append(town)
	# Novas tribos recebem locais naturais de coleta, nao estruturas prontas.
	for kind in ["fish","mine"]:
		var best:float=10000.0
		var chosen:=Vector2(-1,-1)
		var wanted:String="water" if kind=="fish" else "mountain"
		for y in range(1,SIZE-1):
			for x in range(1,WIDTH-1):
				if str(tiles[y][x]) in ["water","mountain"]: continue
				var adjacent:bool=false
				for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
					if str(tiles[y+offset.y][x+offset.x])==wanted: adjacent=true
				if not adjacent: continue
				var distance:float=p.distance_squared_to(Vector2(x,y))
				if distance<best:
					best=distance
					chosen=Vector2(x,y)
		if chosen.x>=0: sites.append({"kind":kind,"x":chosen.x,"y":chosen.y,"town":id,"developed":false,"work":0.0})
	politics.prepare(self)
	return town

func swamp_at(p:Vector2) -> bool:
	if p.x<0 or p.y<0 or p.x>=WIDTH or p.y>=SIZE: return false
	return str(tiles[int(p.y)][int(p.x)])=="swamp"

func swamp_water(x:int,y:int) -> bool:
	if str(tiles[y][x])!="water": return false
	for offset in [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1)]:
		var nx:int=clampi(x+offset.x,0,WIDTH-1)
		var ny:int=clampi(y+offset.y,0,SIZE-1)
		if str(tiles[ny][nx])=="swamp": return true
	return false

func _seed_swamp_witch(force:bool=false) -> void:
	if not swamp_witch.is_empty() or (not force and rng.randf()>=0.35): return
	var options:Array[Vector2]=[]
	for y in range(2,SIZE-2):
		for x in range(2,WIDTH-2):
			if str(tiles[y][x])=="swamp": options.append(Vector2(x+0.35,y+0.35))
	if options.is_empty(): return
	var p:Vector2=options[rng.randi_range(0,options.size()-1)]
	swamp_witch={"name":"Bruxa do brejo","x":p.x,"y":p.y,"tx":p.x,"ty":p.y,"health":500.0,"max_health":500.0,"alive":true,"cast":5.0,"summon":15.0,"wander":3.0,"state":"Vigiando"}

func _swamp_target(p:Vector2,radius:float) -> Vector2:
	for attempt in range(18):
		var q:=p+Vector2(rng.randf_range(-radius,radius),rng.randf_range(-radius,radius))
		q.x=clampf(q.x,1,WIDTH-2)
		q.y=clampf(q.y,1,SIZE-2)
		if _witch_ground(q): return q
	return p

func _swamp_human(p:Vector2,radius:float) -> Dictionary:
	var nearest:Dictionary={}
	var best:float=radius
	for person in people:
		if not bool(person["alive"]): continue
		var q:=Vector2(float(person["x"]),float(person["y"]))
		if not _witch_ground(q): continue
		var d:float=p.distance_to(q)
		if d<best:
			best=d
			nearest=person
	return nearest

func _swamp_damage(person:Dictionary,damage:float) -> void:
	if person.is_empty() or not bool(person["alive"]): return
	var previous:float=float(person["health"])
	person["health"]=maxf(0.0,previous-maxf(1.0,damage-defense(person)))
	_mark_hit(person,previous-float(person["health"]))
	if float(person["health"])<=0: kill_person(person)

func strike_witch(person:Dictionary) -> bool:
	if person.is_empty() or not bool(person.get("alive",false)) or not person.has("town") or not bool(swamp_witch.get("alive",false)): return false
	var p:=Vector2(float(person["x"]),float(person["y"]))
	var q:=Vector2(float(swamp_witch["x"]),float(swamp_witch["y"]))
	if p.distance_to(q)>0.9 or not _witch_ground(p) or float(person.get("witch_attack_cd",0))>0: return false
	person["witch_attack_cd"]=0.9 if bool(person.get("combat_training",false)) else 1.6
	var previous:float=float(swamp_witch["health"])
	swamp_witch["health"]=maxf(0.0,previous-attack_damage(person))
	_mark_hit(swamp_witch,previous-float(swamp_witch["health"]))
	_mark_action(person,"combat",0.85)
	gain_xp(person,3.0,"combate")
	if float(swamp_witch["health"])<=0:
		swamp_witch["alive"]=false
		swamp_witch["killer"]=int(person["id"])
		sound_at("complete",person)
		if not bool(swamp_witch.get("staff_awarded",false)):
			person["witch_staff"]=true
			person["staff_cd"]=0.0
			swamp_witch["staff_awarded"]=true
			news=str(person["name"])+" derrotou a bruxa e conquistou o cajado unico!"
		else: news=str(person["name"])+" derrotou a bruxa novamente!"
		gain_xp(person,150.0,"combate")
		var town:Dictionary=get_town(int(person["town"]))
		if not town.is_empty():
			var history:Array=town.get("historical_events",[])
			history.append({"day":int(day),"event":news})
			town["historical_events"]=history
	return true

func cast_staff(person:Dictionary) -> bool:
	if not bool(person.get("witch_staff",false)) or not bool(person.get("alive",false)) or float(person.get("staff_cd",0))>0: return false
	var p:=Vector2(float(person["x"]),float(person["y"]))
	var best:float=3.8
	var target_id:int=-1
	var target_kind:String=""
	for spider in swamp_spiders:
		var d:float=p.distance_to(Vector2(float(spider["x"]),float(spider["y"])))
		if d<best:
			best=d
			target_id=int(spider["id"])
			target_kind="spider"
	if wars:
		for other in people:
			if not bool(other["alive"]) or int(other["town"])==int(person["town"]): continue
			if politics.get_status(self,int(person["town"]),int(other["town"]))!="war": continue
			var d:float=p.distance_to(Vector2(float(other["x"]),float(other["y"])))
			if d<best:
				best=d
				target_id=int(other["id"])
				target_kind="human"
	if target_id<0: return false
	magic_bolts.append({"x":p.x+0.22,"y":p.y-0.15,"target":target_id,"kind":target_kind,"life":4.0,"damage":24.0,"caster":int(person["id"])})
	person["staff_cd"]=4.5
	sound_at("magic",person)
	return true

func _update_swamp(dt:float,controlled_id:int=0) -> void:
	swamp_clock+=dt
	for index in range(combat_feedback.size()-1,-1,-1):
		if float(combat_feedback[index]["expires"])<=swamp_clock: combat_feedback.remove_at(index)
	for person in people:
		if not bool(person["alive"]): continue
		_update_spider_poison(person,dt)
		if not bool(person["alive"]): continue
		if person.has("witch_attack_cd"): person["witch_attack_cd"]=maxf(0,float(person["witch_attack_cd"])-dt)
		if bool(person.get("witch_staff",false)):
			person["staff_cd"]=maxf(0,float(person.get("staff_cd",0))-dt)
			if int(person["id"])!=controlled_id: cast_staff(person)
	if bool(swamp_witch.get("alive",false)):
		var witch:Dictionary=swamp_witch
		var p:=Vector2(float(witch["x"]),float(witch["y"]))
		witch["cast"]=maxf(0,float(witch["cast"])-dt)
		witch["summon"]=maxf(0,float(witch["summon"])-dt)
		witch["wander"]=float(witch["wander"])-dt
		var target:Dictionary=_swamp_human(p,3.8)
		if float(witch.get("summon_anim",0))>0:
			var previous:float=float(witch["summon_anim"])
			witch["summon_anim"]=maxf(0,previous-dt)
			witch["state"]="Invocando aranhas"
			if previous>0.60 and float(witch["summon_anim"])<=0.60:
				_spawn_spider_pair(witch)
		elif not target.is_empty() and float(witch["cast"])<=0:
			magic_bolts.append({"x":p.x+0.22,"y":p.y-0.15,"target":target["id"],"kind":"human","life":4.0,"damage":24.0})
			sound_at("magic",witch)
			witch["cast"]=4.5
			witch["state"]="Lancando magia"
		elif target.is_empty():
			witch["state"]="Vigiando"
			if float(witch["wander"])<=0:
				var q:Vector2=_swamp_target(p,2.0)
				witch["tx"]=q.x
				witch["ty"]=q.y
				witch["wander"]=rng.randf_range(4,8)
			var n:=p.move_toward(Vector2(float(witch["tx"]),float(witch["ty"])),dt*0.32)
			if _witch_ground(n):
				witch["x"]=n.x
				witch["y"]=n.y
		if float(witch["summon"])<=0 and float(witch.get("summon_anim",0))<=0 and swamp_spiders.size()<=6:
			witch["summon"]=18.0
			witch["summon_anim"]=1.2
			witch["state"]="Invocando aranhas"
			sound_at("summon",witch)
		for person in people:
			if int(person["id"])!=controlled_id and bool(person.get("alive",false)) and float(person["age"])>=16 and str(person.get("task",""))=="Combatendo bruxa": strike_witch(person)
	for i in range(swamp_spiders.size()-1,-1,-1):
		var spider:Dictionary=swamp_spiders[i]
		if float(spider["health"])<=0:
			swamp_spiders.remove_at(i)
			continue
		var p:=Vector2(float(spider["x"]),float(spider["y"]))
		if float(spider.get("emerge",0))>0:
			spider["emerge"]=maxf(0,float(spider["emerge"])-dt)
			var exit:=Vector2(float(spider["tx"]),float(spider["ty"]))
			var crawled:=p.move_toward(exit,dt*1.3)
			if _witch_ground(crawled):
				spider["x"]=crawled.x
				spider["y"]=crawled.y
			continue
		spider["bite"]=maxf(0,float(spider["bite"])-dt)
		spider["timer"]=float(spider["timer"])-dt
		var target:Dictionary=_swamp_human(p,2.3)
		var goal:=p
		if not target.is_empty():
			goal=Vector2(float(target["x"]),float(target["y"]))
			if p.distance_to(goal)<0.4 and float(spider["bite"])<=0:
				_swamp_damage(target,10.0)
				if bool(target["alive"]): apply_spider_poison(target)
				sound_at("hit",spider)
				spider["bite"]=2.5
				if bool(target.get("alive",false)) and float(target["age"])>=16.0:
					spider["health"]=float(spider["health"])-attack_damage(target)
					gain_xp(target,2.0,"combate")
					if float(spider["health"])<=0: gain_xp(target,12.0,"combate")
		elif float(spider["timer"])<=0:
			goal=_swamp_target(p,1.5)
			spider["tx"]=goal.x
			spider["ty"]=goal.y
			spider["timer"]=3.0
		else: goal=Vector2(float(spider["tx"]),float(spider["ty"]))
		var q:=p.move_toward(goal,dt*0.7)
		if _witch_ground(q):
			spider["x"]=q.x
			spider["y"]=q.y
	for i in range(magic_bolts.size()-1,-1,-1):
		var bolt:Dictionary=magic_bolts[i]
		var target:Dictionary={}
		if str(bolt["kind"])=="spider":
			for spider in swamp_spiders:
				if int(spider["id"])==int(bolt["target"]): target=spider
		else: target=get_person(int(bolt["target"]))
		bolt["life"]=float(bolt["life"])-dt
		if target.is_empty() or not bool(target.get("alive",true)) or float(target.get("health",0))<=0 or float(bolt["life"])<=0:
			magic_bolts.remove_at(i)
			continue
		var p:=Vector2(float(bolt["x"]),float(bolt["y"]))
		var goal:=Vector2(float(target["x"]),float(target["y"]))
		var q:=p.move_toward(goal,dt*1.65)
		bolt["x"]=q.x
		bolt["y"]=q.y
		if q.distance_to(goal)<0.18:
			if str(bolt["kind"])=="spider": target["health"]=maxf(0,float(target["health"])-float(bolt["damage"]))
			elif bool(bolt.get("arrow",false)):
				var hit:float=arrow_damage(target,float(bolt["damage"]))
				sound_at("shield" if hit<float(bolt["damage"]) else "hit",target)
				_swamp_damage(target,hit)
			else: _swamp_damage(target,float(bolt["damage"]))
			if bolt.has("caster"):
				var caster:Dictionary=get_person(int(bolt["caster"]))
				if not caster.is_empty() and bool(caster["alive"]):
					gain_xp(caster,12.0 if float(target["health"])<=0 else 3.0,"combate")
					if bool(bolt.get("arrow",false)):
						var home:Dictionary=get_town(int(caster["town"]))
						if not home.is_empty(): gain_war_xp(caster,home,10.0 if float(target["health"])<=0 else 2.0)
			magic_bolts.remove_at(i)

func xp_required(person:Dictionary) -> float:
	return 50.0+25.0*(int(person.get("level",1))-1)

func max_hp(person:Dictionary) -> float:
	return float(person.get("max_health",100.0))

func train_guard(person:Dictionary) -> void:
	init_traits(person)
	if bool(person["combat_training"]): return
	person["combat_training"]=true
	person["max_health"]=max_hp(person)+35.0
	person["health"]=minf(max_hp(person),float(person["health"])+35.0)

func gain_xp(person:Dictionary,amount:float,source:String="trabalho") -> void:
	if not person.has("town") or not bool(person.get("alive",false)): return
	init_traits(person)
	if int(person["level"])>=20: return
	person["xp"]=float(person["xp"])+maxf(0.0,amount)
	while float(person["xp"])>=xp_required(person) and int(person["level"])<20:
		person["xp"]=float(person["xp"])-xp_required(person)
		person["level"]=int(person["level"])+1
		person["max_health"]=max_hp(person)+12.0
		person["health"]=minf(max_hp(person),float(person["health"])+12.0)
		person["strength"]=minf(150.0,float(person["strength"])+(3.0 if source=="combate" else 1.0))
		person["intelligence"]=minf(150.0,float(person["intelligence"])+(3.0 if source=="estudo" or source=="trabalho" else 1.0))
		person["diplomacy"]=minf(150.0,float(person["diplomacy"])+(3.0 if source=="social" else 1.0))
		news=str(person["name"])+" avancou para o nivel "+str(person["level"])+"!"
	if int(person["level"])>=20: person["xp"]=0.0

func swamp_combat_job(person:Dictionary) -> bool:
	if not bool(swamp_witch.get("alive",false)): return false
	var p:=Vector2(float(person["x"]),float(person["y"]))
	var witch:=Vector2(float(swamp_witch["x"]),float(swamp_witch["y"]))
	if p.distance_to(witch)>3.8 or not _witch_ground(p): return false
	var trained:bool=is_military(person)
	if str(person.get("military_role",""))=="royal": return false
	var allies:int=0
	for other in people:
		if bool(other["alive"]) and int(other["town"])==int(person["town"]) and float(other["age"])>=16 and float(other["health"])>=max_hp(other)*0.35 and Vector2(float(other["x"]),float(other["y"])).distance_to(witch)<3.8:
			allies+=1
	if float(person["age"])>=16 and float(person["health"])>=max_hp(person)*0.35 and (trained or allies>=3):
		_set_delivery_goal(person,witch,"Combatendo bruxa")
		strike_witch(person)
		return true
	var away:Vector2=(p-witch).normalized()
	if away.length()<0.01: away=Vector2(1,0)
	var escape:Vector2=p+away*3.0
	escape.x=clampf(escape.x,1,WIDTH-2)
	escape.y=clampf(escape.y,1,SIZE-2)
	_set_delivery_goal(person,escape,"Fugindo da bruxa")
	return true

func init_animal_health(animal:Dictionary) -> void:
	var species:String=str(animal.get("species",""))
	var hp:float=float({"chicken":18,"rabbit":22,"frog":10,"deer":65,"capybara":55,"heron":30,"camel":105,"lizard":12,"snow_hare":25,"crocodile":180,"turtle":65,"duck":25,"boar":95,"fox":50,"Lobo":85,"Urso":220}.get(species,35))
	if not animal.has("max_health"):
		var previous:float=float(animal.get("health",hp))
		animal["max_health"]=hp
		animal["health"]=minf(hp,previous) if animal.has("health") and species not in ["Lobo","Urso"] else (hp if bool(animal.get("alive",true)) else 0.0)
	if not animal.has("hunger"): animal["hunger"]=15.0

func animal_damage(animal:Dictionary) -> float:
	return float({"crocodile":28,"fox":12,"boar":14,"deer":5,"Lobo":16,"Urso":32,"turtle":3,"capybara":4,"chicken":1,"rabbit":1,"frog":1,"heron":3,"camel":8,"lizard":1,"snow_hare":1,"duck":2}.get(str(animal.get("species","")),2))

func damage_animal(animal:Dictionary,amount:float) -> bool:
	init_animal_health(animal)
	if float(animal["health"])<=0.0: return false
	var previous:float=float(animal["health"])
	animal["health"]=maxf(0.0,previous-maxf(0.0,amount))
	_mark_hit(animal,previous-float(animal["health"]))
	if float(animal["health"])<=0:
		if animal.has("alive"): animal["alive"]=false
		_drop_animal_resources(animal)
		sound_at("animal_hurt",animal)
		return true
	animal["state"]="Fugindo"
	animal["timer"]=0.0
	sound_at("animal_hurt",animal)
	return false

func hunt_animal(person:Dictionary,animal:Dictionary) -> bool:
	if not bool(person.get("alive",false)) or float(person.get("hunt_cd",0))>0 or float(animal.get("health",1))<=0: return false
	if Vector2(float(person["x"]),float(person["y"])).distance_to(Vector2(float(animal["x"]),float(animal["y"])))>0.65: return false
	person["hunt_cd"]=1.6
	_mark_action(person,"combat",0.85)
	var killed:bool=damage_animal(animal,attack_damage(person))
	gain_xp(person,2.0,"combate")
	if killed:
		gain_xp(person,8.0,"combate")
		collect_nearby_drop(person)
	return true

const RESOURCE_NAMES:Dictionary={"wood":"Madeira","stone":"Pedra","ore":"Minerio","metal":"Metal","food":"Comida","water":"Agua","fish":"Peixe","meat":"Carne","hide":"Couro","croc_hide":"Couro de crocodilo","feather":"Penas","bone":"Ossos","shell":"Casco","fiber":"Fibra vegetal","cord":"Corda","club":"Bastao","spear":"Lanca tribal","bow":"Arco","sword":"Espada de ferro","pickaxe":"Picareta de pedra","iron_pickaxe":"Picareta de ferro","arrows":"Flechas","hoe":"Enxada","axe":"Machado","rod":"Vara de pesca","wood_shield":"Escudo de madeira","iron_shield":"Escudo de ferro"}

func animal_loot(species:String) -> Dictionary:
	match species:
		"crocodile": return {"meat":3,"croc_hide":2,"bone":1}
		"chicken","duck","heron": return {"meat":1,"feather":2}
		"deer","boar","camel","capybara","Urso": return {"meat":3,"hide":1,"bone":1}
		"fox","Lobo","rabbit","snow_hare": return {"meat":1,"hide":1}
		"turtle": return {"meat":1,"shell":1}
		"frog","lizard": return {"meat":1}
	return {"meat":1}

func _drop_animal_resources(animal:Dictionary) -> void:
	if bool(animal.get("dropped",false)) or not animal.has("x"): return
	animal["dropped"]=true
	if resource_drops.size()>=180: resource_drops.pop_front()
	resource_drops.append({"id":new_id(),"source":int(animal.get("id",-1)),"x":float(animal["x"]),"y":float(animal["y"]),"items":animal_loot(str(animal["species"])),"remaining":180.0})

func _consume_prey_meat(animal:Dictionary) -> void:
	for drop in resource_drops:
		if int(drop["source"])!=int(animal["id"]): continue
		var items:Dictionary=drop["items"]
		items.erase("meat")
		break

func _update_drops(dt:float) -> void:
	for i in range(resource_drops.size()-1,-1,-1):
		var drop:Dictionary=resource_drops[i]
		drop["remaining"]=float(drop["remaining"])-dt
		if drop["items"].is_empty() or float(drop["remaining"])<=0: resource_drops.remove_at(i)

func collect_nearby_drop(person:Dictionary) -> bool:
	if is_military(person): return false
	if not person.get("cargo",{}).is_empty(): return false
	var pos:=Vector2(float(person["x"]),float(person["y"]))
	for drop in resource_drops:
		if pos.distance_to(Vector2(float(drop["x"]),float(drop["y"])))>0.65: continue
		var items:Dictionary=drop["items"]
		for key in items.keys():
			var amount:float=minf(float(items[key]),floorf(free_load(person)/resource_weight(str(key))))
			if amount<=0: continue
			if not collect_cargo(person,str(key),amount): continue
			items[key]=float(items[key])-amount
			if float(items[key])<=0: items.erase(key)
			return true
	return false

func gather_drop_job(person:Dictionary,town:Dictionary) -> bool:
	if is_military(person): return false
	if float(person["age"])<16 or not person.get("cargo",{}).is_empty() or free_load(person)<1: return false
	var pos:=Vector2(float(person["x"]),float(person["y"]))
	var origin:=Vector2(float(town["x"]),float(town["y"]))
	var best:Dictionary={}
	var distance:float=5.0
	for drop in resource_drops:
		if drop["items"].is_empty(): continue
		var q:=Vector2(float(drop["x"]),float(drop["y"]))
		if q.distance_to(origin)>7: continue
		var d:float=pos.distance_to(q)
		if d<distance:
			best=drop
			distance=d
	if best.is_empty(): return false
	_set_delivery_goal(person,Vector2(float(best["x"]),float(best["y"])),"Recolhendo recursos")
	if distance<0.65: collect_nearby_drop(person)
	return true

func storage_position(town:Dictionary,key:String) -> Vector2:
	var origin:=Vector2(float(town["x"]),float(town["y"]))
	if key=="castle": return workshop_position(town,"castle")+Vector2(0,0.4)
	if key.begins_with("house_"):
		var spots:Array[Vector2]=[Vector2(0,-0.35),Vector2(1.60,0.35),Vector2(-1.25,-0.75),Vector2(2.15,-0.85),Vector2(-2.4,0.15),Vector2(0.95,-1.65),Vector2(-1.35,1.45),Vector2(2.9,1.15)]
		return origin+spots[clampi(int(key.trim_prefix("house_")),0,7)]+Vector2(0,0.42)
	return origin

func preferred_storage(town:Dictionary,kind:String,person:Dictionary={}) -> String:
	if bool(town.get("castle",false)) and kind not in ["food","water","fish","meat"]: return "castle"
	var count:int=int(town.get("houses",0))
	if count<=0: return "camp"
	return "house_"+str(posmod(int(person.get("id",0)),count))

# Estoques por edificio sao uma particao do total usado pela economia.
# Sincronizar consumos legados retira do estoque real, sem duplicar recursos.
func building_stocks(town:Dictionary) -> Dictionary:
	var stores:Dictionary=town.get("building_stocks",{})
	var keys:Array=["camp"]
	for index in range(int(town.get("houses",0))): keys.append("house_"+str(index))
	if bool(town.get("castle",false)): keys.append("castle")
	for key in keys:
		if not stores.has(key): stores[key]={}
	for kind in RESOURCE_NAMES.keys():
		var total:float=maxf(0,float(town.get(kind,0)))
		var allocated:float=0.0
		for key in stores.keys(): allocated+=float(stores[key].get(kind,0))
		if total>allocated+0.00001:
			var key:String=preferred_storage(town,str(kind))
			stores[key][kind]=float(stores[key].get(kind,0))+total-allocated
		elif allocated>total+0.00001:
			var remaining:float=allocated-total
			for key in stores.keys():
				var take:float=minf(remaining,float(stores[key].get(kind,0)))
				stores[key][kind]=float(stores[key].get(kind,0))-take
				remaining-=take
				if remaining<=0.00001: break
	town["building_stocks"]=stores
	return stores

func store_resource(town:Dictionary,key:String,kind:String,amount:float) -> void:
	if amount<=0: return
	var stocks:Dictionary=building_stocks(town)
	if not stocks.has(key): key="camp"
	stocks[key][kind]=float(stocks[key].get(kind,0))+amount
	town[kind]=float(town.get(kind,0))+amount

func loot_stock(attacker:Dictionary,defender:Dictionary) -> Dictionary:
	var source:Dictionary=building_stocks(defender)
	var stolen:Dictionary={}
	var budget:float=12.0
	for key in source.keys():
		for kind in RESOURCE_NAMES.keys():
			var amount:float=minf(floorf(float(source[key].get(kind,0))*0.20),minf(3.0,floorf(budget/resource_weight(kind))))
			if amount<=0: continue
			source[key][kind]=float(source[key][kind])-amount
			defender[kind]=maxf(0,float(defender.get(kind,0))-amount)
			store_resource(attacker,preferred_storage(attacker,kind),kind,amount)
			stolen[kind]=float(stolen.get(kind,0))+amount
			budget-=amount*resource_weight(kind)
	return stolen

# Receitas abstratas de jogo; materiais e produtos fazem parte do estoque.
const CRAFT_RECIPES:Dictionary={
	"club":{"wood":2},
	"wood_shield":{"wood":3,"fiber":1},
	"iron_shield":{"wood":2,"metal":2},
	"spear":{"wood":2,"stone":1},
	"cord":{"fiber":2},
	"bow":{"wood":2,"cord":1},
	"arrows":{"wood":1,"stone":1,"feather":1},
	"pickaxe":{"wood":2,"stone":2},
	"hoe":{"wood":2,"stone":1},
	"axe":{"wood":2,"stone":1},
	"rod":{"wood":1,"cord":1},
	"metal":{"ore":2,"wood":1},
	"sword":{"metal":3,"wood":1},
	"iron_pickaxe":{"metal":2,"wood":1}
}

func craft_allowed(town:Dictionary,item:String) -> bool:
	if not CRAFT_RECIPES.has(item): return false
	if item in ["metal","sword","iron_pickaxe","iron_shield"] and (not bool(town.get("forge",false)) or int(town["level"])<3): return false
	if item in ["cord","bow","arrows","rod"] and int(town["level"])<1: return false
	for material in CRAFT_RECIPES[item].keys():
		if float(town.get(material,0))<float(CRAFT_RECIPES[item][material]): return false
	return true

func craft_item(town:Dictionary,item:String) -> bool:
	if not craft_allowed(town,item): return false
	for material in CRAFT_RECIPES[item].keys():
		town[material]=float(town.get(material,0))-float(CRAFT_RECIPES[item][material])
	store_resource(town,preferred_storage(town,item),item,4.0 if item=="arrows" else 1.0)
	return true

func take_equipment(town:Dictionary,person:Dictionary,item:String) -> bool:
	var stocks:Dictionary=building_stocks(town)
	var pos:=Vector2(float(person["x"]),float(person["y"]))
	for key in stocks.keys():
		if float(stocks[key].get(item,0))<1: continue
		if pos.distance_to(storage_position(town,str(key)))>1.4: continue
		stocks[key][item]=float(stocks[key][item])-1
		town[item]=maxf(0,float(town.get(item,0))-1)
		return true
	return false

func equipment_job(person:Dictionary,town:Dictionary) -> bool:
	if float(person["age"])<16: return false
	var wanted:Array=[]
	if is_military(person):
		wanted=["bow","spear","club"] if str(person["military_role"])=="archer" else ["sword","spear","club"]
		if int(town.get("raid_target",0))>0 or int(town.get("siege_by",0))>0: return false
	else:
		match str(person.get("profession","")):
			"Minerador": wanted=["iron_pickaxe","pickaxe"]
			"Agricultor": wanted=["hoe"]
			"Construtor": wanted=["axe"]
			"Pescador": wanted=["rod"]
	var current:String=str(person.get("weapon_kind","")) if is_military(person) else str(person.get("tool_kind",""))
	var stocks:Dictionary=building_stocks(town)
	if is_military(person) and current=="bow" and int(person.get("ammo",0))<3:
		for key in stocks.keys():
			if float(stocks[key].get("arrows",0))<1: continue
			var depot:Vector2=storage_position(town,str(key))
			if Vector2(float(person["x"]),float(person["y"])).distance_to(depot)<=1.4:
				equip_worker(town,person)
				return false
			_set_delivery_goal(person,depot,"Reabastecendo flechas")
			return true
	if is_military(person) and str(person.get("military_role",""))!="archer":
		var shield:String=str(person.get("shield_kind",""))
		for item in ["iron_shield","wood_shield"]:
			if shield==item: break
			for key in stocks.keys():
				if float(stocks[key].get(item,0))<1: continue
				var pos:Vector2=storage_position(town,str(key))
				if Vector2(float(person["x"]),float(person["y"])).distance_to(pos)<=1.4:
					equip_worker(town,person)
					return false
				_set_delivery_goal(person,pos,"Buscando escudo")
				return true
	for item in wanted:
		if current==item: break
		for key in stocks.keys():
			if float(stocks[key].get(item,0))<1: continue
			var pos:Vector2=storage_position(town,str(key))
			if Vector2(float(person["x"]),float(person["y"])).distance_to(pos)<=1.4:
				equip_worker(town,person)
				return false
			_set_delivery_goal(person,pos,"Buscando equipamento")
			return true
	return false

func next_craft(town:Dictionary) -> String:
	var desired:Array=[]
	var bow_needed:bool=false
	for person in people:
		if not bool(person["alive"]) or int(person["town"])!=int(town["id"]) or float(person["age"])<16: continue
		var profession:String=str(person.get("profession",""))
		var tool:String=str(person.get("tool_kind",""))
		var weapon:String=str(person.get("weapon_kind",""))
		if profession=="Minerador":
			if tool not in ["pickaxe","iron_pickaxe"]: desired.append("pickaxe")
			elif tool!="iron_pickaxe" and bool(town.get("forge",false)): desired.append("iron_pickaxe")
		elif is_military(person):
			if str(person.get("military_role",""))!="archer" and not weapon.is_empty():
				if str(person.get("shield_kind","")).is_empty(): desired.append("wood_shield")
				if bool(town.get("forge",false)) and str(person.get("shield_kind",""))!="iron_shield": desired.append("iron_shield")
			if str(person.get("military_role",""))=="archer":
				if weapon!="bow":
					bow_needed=true
					desired.append("bow")
				else: desired.append("arrows")
			elif weapon!="sword":
				if bool(town.get("forge",false)): desired.append("sword")
				if weapon not in ["spear","sword"]: desired.append("spear")
				if weapon.is_empty(): desired.append("club")
		elif profession=="Agricultor" and tool!="hoe": desired.append("hoe")
		elif profession=="Construtor" and tool!="axe": desired.append("axe")
		elif profession=="Pescador" and tool!="rod":
			desired.append("rod")
			bow_needed=true
	if bool(town.get("forge",false)) and float(town.get("metal",0))<6 and craft_allowed(town,"metal"): return "metal"
	if bow_needed and float(town.get("cord",0))<1 and craft_allowed(town,"cord"): return "cord"
	for item in desired:
		if float(town.get(item,0))<(4 if item=="arrows" else 1) and craft_allowed(town,str(item)):
			return str(item)
	return ""

func crafting_job(person:Dictionary,town:Dictionary,step:float) -> bool:
	if not bool(town.get("campfire",false)) or float(person["age"])<16 or is_military(person) or int(person["id"])==int(town["leader"]): return false
	if not town.get("construction",{}).is_empty(): return false
	var job:Dictionary=town.get("craft_job",{})
	if not job.is_empty():
		var worker:Dictionary=get_person(int(job["worker"]))
		if worker.is_empty() or not bool(worker["alive"]) or is_military(worker):
			town["craft_job"]={}
			job={}
	if job.is_empty():
		if float(town.get("wood",0))<8.0: return false
		var item:String=next_craft(town)
		if item.is_empty(): return false
		job={"worker":person["id"],"item":item,"progress":0.0}
		town["craft_job"]=job
	if int(job["worker"])!=int(person["id"]): return false
	var item:String=str(job["item"])
	if not craft_allowed(town,item):
		town["craft_job"]={}
		return false
	var pos:Vector2=workshop_position(town,"forge" if item in ["metal","sword","iron_pickaxe","iron_shield"] else "campfire")
	_set_delivery_goal(person,pos,"Fabricando "+str(RESOURCE_NAMES[item]))
	if Vector2(float(person["x"]),float(person["y"])).distance_to(pos)<0.65:
		job["progress"]=float(job["progress"])+step
		if float(job["progress"])>=(12.0 if item in ["metal","sword","iron_pickaxe","iron_shield"] else 5.0):
			if craft_item(town,item):
				sound_at("forge" if item in ["metal","sword","iron_pickaxe","iron_shield"] else "build",person)
				gain_xp(person,5.0,"trabalho")
			town["craft_job"]={}
	return true

func gain_war_xp(person:Dictionary,town:Dictionary,amount:float) -> void:
	person["war_xp"]=minf(250.0,float(person.get("war_xp",0))+amount)
	town["war_xp"]=minf(1000.0,float(town.get("war_xp",0))+amount)

func army_tactics(town:Dictionary) -> int:
	var xp:float=float(town.get("war_xp",0))
	if int(town.get("level",1))>=3 and xp>=100: return 2
	if xp>=20 or int(town.get("level",1))>=2: return 1
	return 0

func nearby_shield(person:Dictionary,town:Dictionary,radius:float) -> Dictionary:
	var pos:=Vector2(float(person["x"]),float(person["y"]))
	var nearest:Dictionary={}
	var best:float=radius
	for ally in army_members(town,false):
		if int(ally["id"])==int(person["id"]) or str(ally.get("shield_kind","")).is_empty(): continue
		var d:float=pos.distance_to(Vector2(float(ally["x"]),float(ally["y"])))
		if d<best:
			best=d
			nearest=ally
	return nearest

func arrow_damage(person:Dictionary,damage:float) -> float:
	var shield:String=str(person.get("shield_kind",""))
	var reduction:float=0.0
	if shield=="wood_shield": reduction=0.35
	elif shield=="iron_shield": reduction=0.55
	if reduction>0: reduction=minf(0.8,reduction+float(person.get("war_xp",0))*0.001)
	elif is_military(person):
		var town:Dictionary=get_town(int(person["town"]))
		if not town.is_empty() and army_tactics(town)>=2 and not nearby_shield(person,town,0.9).is_empty(): reduction=0.20
	return maxf(1.0,damage*(1.0-reduction))

func sound_event(kind:String,pos:Vector2) -> void:
	if sound_events.size()<80: sound_events.append({"kind":kind,"position":pos})

func sound_at(kind:String,entity:Dictionary) -> void:
	if entity.has("x") and entity.has("y"): sound_event(kind,Vector2(float(entity["x"]),float(entity["y"])))

# Duas aranhas surgem debaixo do manto, e so depois procuram alvos.
func _spawn_spider_pair(witch:Dictionary) -> void:
	if swamp_spiders.size()>6 or not bool(witch.get("alive",false)): return
	var origin:=Vector2(float(witch["x"]),float(witch["y"]))
	for side in [-1,1]:
		var start:=origin+Vector2(float(side)*0.08,0.10)
		if not _witch_ground(start): start=origin
		var goal:=origin+Vector2(float(side)*0.68,0.32)
		if not _witch_ground(goal): goal=origin+Vector2(float(side)*0.20,0.25)
		if not _witch_ground(goal): goal=origin
		swamp_spiders.append({"id":new_id(),"x":start.x,"y":start.y,"tx":goal.x,"ty":goal.y,"health":50.0,"max_health":50.0,"timer":0.0,"bite":0.0,"emerge":0.6})

# Veneno nao acumula: uma dose completa causa 15 de dano em cinco segundos.
func apply_spider_poison(person:Dictionary) -> void:
	if bool(person.get("alive",false)) and float(person.get("poison_remaining",0))<=0:
		person["poison_remaining"]=5.0

func _update_spider_poison(person:Dictionary,dt:float) -> void:
	var remaining:float=float(person.get("poison_remaining",0))
	if remaining<=0 or not bool(person.get("alive",false)): return
	var elapsed:float=minf(remaining,dt)
	person["poison_remaining"]=maxf(0,remaining-elapsed)
	person["health"]=maxf(0,float(person["health"])-3.0*elapsed)
	if float(person["health"])<=0: kill_person(person)

# Animais hostis identificam alvos proximos, perseguem e atacam com recarga.
func _hostile_animal_step(animal:Dictionary,dt:float) -> bool:
	if not predators or not bool(animal.get("alive",true)) or float(animal.get("health",1))<=0: return false
	var species:String=str(animal.get("species",""))
	if species not in ["Lobo","Urso","crocodile","boar"]: return false
	var pos:=Vector2(float(animal["x"]),float(animal["y"]))
	animal["human_attack_cd"]=maxf(0,float(animal.get("human_attack_cd",0))-dt)
	var radius:float=float({"Lobo":3.8,"Urso":2.8,"crocodile":2.6,"boar":1.7}[species])
	var victim:Dictionary={}
	var best:float=radius
	for person in people:
		if not bool(person.get("alive",false)): continue
		var q:=Vector2(float(person["x"]),float(person["y"]))
		var d:float=pos.distance_to(q)
		if d>=best: continue
		var biome:String=str(tiles[clampi(int(q.y),0,SIZE-1)][clampi(int(q.x),0,WIDTH-1)])
		victim=person
		best=d
	if victim.is_empty():
		if str(animal.get("state","")) in ["Perseguindo humano","Atacando humano"]:
			animal["state"]="Explorando"
			animal["timer"]=0.0
			animal["wander"]=0.0
		return false
	var goal:=Vector2(float(victim["x"]),float(victim["y"]))
	animal["tx"]=goal.x
	animal["ty"]=goal.y
	animal["target_x"]=goal.x
	animal["target_y"]=goal.y
	animal["state"]="Perseguindo humano"
	if best>0.5:
		var pace:float=float({"Lobo":1.35,"Urso":0.95,"crocodile":0.88,"boar":1.18}[species])
		var next:=pos.move_toward(goal,dt*pace)
		var biome:String=str(tiles[clampi(int(next.y),0,SIZE-1)][clampi(int(next.x),0,WIDTH-1)])
		animal["x"]=next.x
		animal["y"]=next.y
		return true
	animal["state"]="Atacando humano"
	if float(animal["human_attack_cd"])<=0:
		animal["human_attack_cd"]=2.2 if species!="Urso" else 3.0
		_swamp_damage(victim,animal_damage(animal))
		sound_at("growl",animal)
		if bool(victim["alive"]) and float(victim["age"])>=16 and (is_military(victim) or bool(victim.get("combat_training",false))):
			hunt_animal(victim,animal)
		if not bool(victim["alive"]): animal["hunger"]=maxf(0,float(animal.get("hunger",0))-45)
	return true

func react_to_hostile_animal(person:Dictionary) -> bool:
	if not predators: return false
	var p:=Vector2(float(person["x"]),float(person["y"]))
	var threat:Dictionary={}
	var best:float=2.1
	for group in [beasts,wildlife]:
		for animal in group:
			if not bool(animal.get("alive",true)) or float(animal.get("health",1))<=0 or str(animal.get("species","")) not in ["Lobo","Urso","crocodile","boar"]: continue
			var d:float=p.distance_to(Vector2(float(animal["x"]),float(animal["y"])))
			if d<best:
				best=d
				threat=animal
	if threat.is_empty(): return false
	var q:=Vector2(float(threat["x"]),float(threat["y"]))
	if float(person["age"])>=16 and (is_military(person) or bool(person.get("combat_training",false))) and float(person["health"])>max_hp(person)*0.25:
		_set_delivery_goal(person,q,"Defendendo contra animal")
		if best<=0.65: hunt_animal(person,threat)
	else:
		var away:Vector2=(p-q).normalized()
		if away.length()<0.01: away=Vector2(1,0)
		var escape:Vector2=p+away*3
		_set_delivery_goal(person,Vector2(clampf(escape.x,1,WIDTH-2),clampf(escape.y,1,SIZE-2)),"Fugindo de animal")
	return true

func _preferred_animal_destination(p:Vector2,species:String) -> Vector2:
	var best:=p
	var score:float=1000.0
	for y in range(maxi(1,int(p.y)-6),mini(SIZE-1,int(p.y)+7)):
		for x in range(maxi(1,int(p.x)-6),mini(WIDTH-1,int(p.x)+7)):
			if not animal_habitat(species,str(tiles[y][x])): continue
			var q:=Vector2(x+0.5,y+0.5)
			var d:float=q.distance_to(p)
			if d>0.7 and d<score:
				best=q
				score=d
	if best==p: return Vector2(clampf(p.x+rng.randf_range(-2,2),1,WIDTH-2),clampf(p.y+rng.randf_range(-2,2),1,SIZE-2))
	return best

func _witch_ground(p:Vector2) -> bool:
	if p.x<1 or p.y<1 or p.x>WIDTH-2 or p.y>SIZE-2: return false
	if bool(swamp_witch.get("manual_spawn",false)): return str(tiles[int(p.y)][int(p.x)]) not in ["water","mountain"]
	return swamp_at(p)

func _animal_avoid_buildings(next:Vector2,previous:Vector2) -> Vector2:
	var spots:Array[Vector2]=[Vector2(0,-0.35),Vector2(1.60,0.35),Vector2(-1.25,-0.75),Vector2(2.15,-0.85),Vector2(-2.4,0.15),Vector2(0.95,-1.65),Vector2(-1.35,1.45),Vector2(2.9,1.15)]
	for town in towns:
		var origin:=Vector2(float(town["x"]),float(town["y"]))
		if next.distance_squared_to(origin)>20: continue
		for i in range(mini(int(town.get("houses",0)),spots.size())):
			var home:=origin+spots[i]
			var offset:=next-home
			if absf(offset.x)>0.48 or absf(offset.y)>0.34: continue
			var direction:=previous-home
			if direction.length_squared()<0.001: direction=Vector2(0,1)
			return home+direction.normalized()*0.57
	return next

func _bird_flight(animal:Dictionary,dt:float) -> bool:
	var species:String=str(animal["species"])
	if species not in ["heron","duck"]: return false
	var remaining:float=float(animal.get("flight_time",0))
	var pos:=Vector2(float(animal["x"]),float(animal["y"]))
	if remaining<=0:
		animal["flight_height"]=0.0
		animal["flight_wait"]=float(animal.get("flight_wait",8.0+float(int(animal["id"])%13)))-dt
		if float(animal["flight_wait"])>0 and str(animal.get("state",""))!="Fugindo": return false
		var goal:Vector2=_preferred_animal_destination(pos,species)
		if goal.distance_to(pos)<2.0: goal=pos+Vector2(rng.randf_range(-4,4),rng.randf_range(-3,3))
		goal=Vector2(clampf(goal.x,1,WIDTH-2),clampf(goal.y,1,SIZE-2))
		animal["flight_x"]=goal.x
		animal["flight_y"]=goal.y
		animal["flight_duration"]=maxf(3.5,pos.distance_to(goal)/1.5+1.0)
		remaining=float(animal["flight_duration"])
		animal["flight_wait"]=rng.randf_range(12,25)
		sound_at("bird",animal)
	var duration:float=float(animal.get("flight_duration",4))
	remaining=maxf(0,remaining-dt)
	animal["flight_time"]=remaining
	var height:float=clampf(minf((duration-remaining)/0.8,remaining/0.9),0,1)
	animal["flight_height"]=height
	animal["state"]="Decolando" if duration-remaining<0.8 else ("Pousando" if remaining<0.9 else "Voando")
	var target:=Vector2(float(animal["flight_x"]),float(animal["flight_y"]))
	var next:=pos.move_toward(target,dt*1.8)
	animal["x"]=next.x
	animal["y"]=next.y
	if remaining<=0:
		animal["tx"]=next.x
		animal["ty"]=next.y
		animal["timer"]=0.0
		animal["state"]="Descansando"
	return true

# Eventos de impacto sao temporarios, nao fazem parte do arquivo de mundo.
var combat_feedback:Array=[]
func _mark_hit(actor:Dictionary,amount:float) -> void:
	if amount<=0 or not actor.has("x") or not actor.has("y"): return
	actor["hit_until"]=swamp_clock+0.22
	if combat_feedback.size()>=100: combat_feedback.pop_front()
	combat_feedback.append({"x":float(actor["x"]),"y":float(actor["y"]),"amount":amount,"expires":swamp_clock+1.1})
func _mark_action(actor:Dictionary,kind:String,duration:float) -> void:
	actor["visual_action"]=kind
	actor["action_until"]=swamp_clock+duration
func visible_action(actor:Dictionary) -> String:
	var task:String=str(actor.get("task",""))
	if float(actor.get("action_until",0))>swamp_clock: return str(actor.get("visual_action",""))
	var pos:=Vector2(float(actor.get("x",0)),float(actor.get("y",0)))
	var goal:=Vector2(float(actor.get("target_x",pos.x)),float(actor.get("target_y",pos.y)))
	if pos.distance_to(goal)>0.65: return ""
	match task:
		"Pescando": return "fishing"
		"Minerando": return "mining"
		"Cultivando": return "farming"
		"Construindo": return "building"
		"Coletando madeira": return "chopping"
		"Combatendo inimigo","Combatendo bruxa","Defendendo contra animal","Cacando": return "combat"
	return ""
