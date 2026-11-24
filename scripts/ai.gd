extends RefCounted
## Inteligencia de agentes orientada a necessidades, personalidade e memoria.
## Deterministica por atualizacao da simulacao, sem rede ou IA generativa.
var elapsed := 0.0
const SOCIAL_DISTANCE := 2.7
const MAX_MEMORIES := 8

func advance(sim, delta: float, controlled_id: int = 0) -> void:
	elapsed += delta
	if elapsed < 0.75:
		return
	var step := minf(elapsed, 2.0)
	elapsed = 0.0
	for town in sim.towns:
		_init_town(town)
		_manage_town(sim, town, step)
	for person in sim.people:
		if not bool(person.get("alive", false)) or int(person["id"]) == controlled_id:
			continue
		_init_person(sim, person)
		_decide(sim, person, step)

func _init_person(sim, p: Dictionary) -> void:
	if not p.has("mind"):
		p["mind"] = {
			"kindness": sim.rng.randf(),
			"ambition": sim.rng.randf(),
			"bravery": sim.rng.randf(),
			"curiosity": sim.rng.randf(),
			"loyalty": sim.rng.randf()
		}
	if not p.has("needs"):
		p["needs"] = {"hunger": sim.rng.randf_range(0, 20), "energy": 85.0, "company": 45.0}
	if not p.has("relations"):
		p["relations"] = {}
	if not p.has("memories"):
		p["memories"] = []
	if not p.has("task"):
		p["task"] = "Observando"
	if not p.has("work_timer"):
		p["work_timer"] = 0.0
	if not p.has("profession") or (str(p["profession"]) == "Crianca" and float(p["age"]) >= 16.0):
		if float(p["age"]) < 16.0:
			p["profession"] = "Crianca"
			return
		var mind: Dictionary = p["mind"]
		if int(p["id"])%6==0:
			p["profession"]="Pescador"
		elif int(p["id"])%6==1:
			p["profession"]="Minerador"
		elif int(p["id"])%6==2:
			p["profession"]="Cozinheiro"
		elif float(mind["bravery"]) > 0.8:
			p["profession"] = "Guarda"
		elif float(mind["curiosity"]) > 0.76:
			p["profession"] = "Explorador"
		elif float(mind["ambition"]) > 0.72:
			p["profession"] = "Construtor"
		else:
			p["profession"] = "Agricultor"

func _init_town(t: Dictionary) -> void:
	if not t.has("houses"):
		t["houses"] = 2
	if not t.has("farms"):
		t["farms"] = 1
	if not t.has("morale"):
		t["morale"] = 60.0
	if not t.has("diplomacy"):
		t["diplomacy"] = {}
	if not t.has("historical_events"):
		t["historical_events"] = []
	if not t.has("political_tension"):
		t["political_tension"] = 0.0
	if not t.has("construction"):
		t["construction"] = {}

func _manage_town(sim, town: Dictionary, step: float) -> void:
	var pop: int = sim.active_population(int(town["id"]))
	# Moradores levantam UMA obra de cada vez. Madeira e tempo tem custos reais.
	if town.get("construction", {}).is_empty():
		if not bool(town.get("campfire",false)) and float(town["wood"])>=10:
			sim.start_construction(int(town["id"]),"campfire")
		elif pop > int(town["houses"]) * 5 and float(town["wood"]) >= 14.0 and int(town["houses"]) < 8:
			sim.start_construction(int(town["id"]), "house")
		elif float(town["food"]) < float(pop) * 1.5 and float(town["wood"]) >= 18.0 and int(town["farms"]) < 6:
			sim.start_construction(int(town["id"]), "farm")
		elif bool(town.get("campfire",false)) and not bool(town.get("oven",false)) and float(town.get("stone",0))>=12 and float(town["wood"])>=8:
			sim.start_construction(int(town["id"]),"oven")
		elif not bool(town.get("crossing",false)) and float(town.get("stone",0))>=4 and float(town["wood"])>=16:
			sim.start_construction(int(town["id"]),"crossing")
		elif int(town["level"])>=3 and bool(town.get("oven",false)) and not bool(town.get("forge",false)) and float(town.get("stone",0))>=24 and float(town["wood"])>=20:
			sim.start_construction(int(town["id"]),"forge")
	var harvest: float = step * float(town["farms"]) * 0.15
	town["food"] = maxf(0.0, float(town["food"]) + harvest)
	town["morale"] = clampf(float(town["morale"]) + (0.07 if float(town["food"]) > pop else -0.18) * step, 0.0, 100.0)
	if sim.wars and sim.rivals:
		var tension := float(town["political_tension"])
		tension += step * (0.035 if bool(town["hostile"]) else 0.015)
		town["political_tension"] = clampf(tension, 0.0, 100.0)

func _decide(sim, p: Dictionary, step: float) -> void:
	var n: Dictionary = p["needs"]
	var m: Dictionary = p["mind"]
	n["hunger"] = clampf(float(n["hunger"]) + step * 0.36, 0.0, 100.0)
	n["energy"] = clampf(float(n["energy"]) - step * 0.22, 0.0, 100.0)
	n["company"] = clampf(float(n["company"]) + step * 0.21, 0.0, 100.0)
	var home: Dictionary = sim.get_town(int(p["town"]))
	if home.is_empty():
		return
	if float(n["hunger"]) >= 55.0:
		_set_task(sim, p, home, "Comendo", 0.25)
		if float(home["food"]) >= 0.4:
			home["food"] = float(home["food"]) - 0.4
			n["hunger"] = maxf(0.0, float(n["hunger"]) - 45.0)
			p["health"] = minf(100.0, float(p["health"]) + 1.0)
		else:
			p["health"] = float(p["health"]) - step * 0.12
			if float(p["health"]) <= 0.0:
				sim.kill_person(p)
		return
	if float(n["energy"]) < 28.0:
		n["energy"] = minf(100.0, float(n["energy"]) + step * 5.0)
		_set_task(sim, p, home, "Descansando", 0.35)
		return
	if sim.transport_job(p,home): return
	if float(p["age"])>=16 and bool(home.get("campfire",false)):
		var equipment:String=str(p.get("transport","hands"))
		var near_store:bool=Vector2(float(p["x"]),float(p["y"])).distance_to(Vector2(float(home["x"]),float(home["y"])))<0.8
		if near_store and equipment=="hands" and float(home["wood"])>=5 and float(home.get("knowledge",0))>=0.5:
			home["wood"]=float(home["wood"])-5
			p["transport"]="basket"
		elif near_store and equipment=="basket" and int(home["level"])>=2 and float(home["wood"])>=14 and float(home.get("stone",0))>=3:
			home["wood"]=float(home["wood"])-14
			home["stone"]=float(home["stone"])-3
			p["transport"]="cart"
	if float(n["company"]) >= 53.0:
		if _socialize(sim, p, home):
			_set_task(sim, p, home, "Conversando", 0.75)
			n["company"] = maxf(0.0, float(n["company"]) - 38.0)
			return
	if not p.has("specialty_v57") and float(p["age"])>=16.0:
		p["specialty_v57"]=true
		match int(p["id"])%8:
			0, 3: p["profession"]="Pescador"
			1, 4: p["profession"]="Minerador"
			2: p["profession"]="Cozinheiro"
	# Garante que uma aldeia sem madeira tenha pelo menos um coletor.
	if float(p["age"])>=16 and float(home["wood"])<14.0 and int(p["id"])!=int(home["leader"]) and int(p["id"])%2==0:
		_gather_wood(sim,p,home)
		return
	# A personalidade altera os objetivos de trabalho e as exploracoes.
	match str(p["profession"]):
		"Pescador":
			if _site_work(sim,p,home,"fish","Pescando"):
				sim.collect_cargo(p,"fish",3.0)
		"Minerador":
			if _site_work(sim,p,home,"mine","Minerando"):
				var deposit:Dictionary=sim.local_site("mine",int(home["id"]))
				if not bool(deposit.get("developed",false)):
					sim.collect_cargo(p,"stone",2.0)
					deposit["work"]=float(deposit.get("work",0))+step
					if float(deposit["work"])>=16 and float(home["wood"])>=6:
						home["wood"]=float(home["wood"])-6
						deposit["developed"]=true
						sim.news=str(home["name"])+" abriu uma mina."
				elif int(home["level"])>=3 and float(home.get("stone",0))>=12:
					sim.collect_cargo(p,"ore",2.0)
				else:
					sim.collect_cargo(p,"stone",2.0)
		"Cozinheiro":
			if bool(home.get("forge",false)) and float(home.get("ore",0))>0:
				if _site_work(sim,p,home,"forge","Forjando"):
					var fuel:float=minf(float(home["wood"]),step*0.08)
					var ore:float=minf(float(home.get("ore",0)),fuel)
					home["wood"]=float(home["wood"])-fuel
					home["ore"]=float(home.get("ore",0))-ore
					home["metal"]=float(home.get("metal",0))+ore
			elif not bool(home.get("campfire",false)):
				_set_task(sim,p,home,"Preparando alimentos",0.6)
			elif _site_work(sim,p,home,"oven" if bool(home.get("oven",false)) else "campfire","Cozinhando"):
				var fuel: float=minf(float(home["wood"]),step*0.05)
				var fish:float=minf(float(home.get("fish",0)),fuel*4.0)
				var meat:float=minf(float(home.get("meat",0)),maxf(0,fuel*4.0-fish))
				if fish+meat>0:
					home["wood"]=float(home["wood"])-(fish+meat)/4.0
					home["fish"]=float(home.get("fish",0))-fish
					home["meat"]=float(home.get("meat",0))-meat
					home["food"]=float(home["food"])+(fish+meat)*1.5
		"Construtor":
			if not home.get("construction", {}).is_empty():
				var project:Dictionary=home["construction"]
				_set_task(sim,p,home,"Construindo",0.65)
				if project.has("x"):
					p["target_x"]=float(project["x"])-(0.7 if str(project["kind"])=="crossing" else 0.0)
					p["target_y"]=float(project["y"])
			else:
				_set_task(sim, p, home, "Coletando madeira", 2.4)
				_gather_wood(sim,p,home)
		"Explorador":
			_set_task(sim, p, home, "Explorando", 3.7)
			home["knowledge"] = float(home["knowledge"]) + step * (0.005 + float(m["curiosity"]) * 0.015)
		"Guarda":
			_set_task(sim, p, home, "Patrulhando", 1.8)
			home["morale"] = minf(100.0, float(home["morale"]) + step * 0.1)
		"Crianca":
			_set_task(sim, p, home, "Brincando", 1.2)
		_:
			if bool(home.get("campfire",false)) and int(p["id"])%5==0 and float(home.get("meat",0))<3:
				_hunt(sim,p,home)
			else:
				var field:Vector2=Vector2(float(home["x"])-1.4,float(home["y"])+1.15)
				sim._set_delivery_goal(p,field,"Cultivando")
				if Vector2(float(p["x"]),float(p["y"])).distance_to(field)<0.65:
					sim.collect_cargo(p,"food",3.0)
	# Laços familiares e rivalidades alteram a lealdade entre pessoas.
	if float(m["ambition"]) > 0.88 and str(p["role"]) == "Aldeao":
		var ruler: Dictionary = sim.get_person(int(home["leader"]))
		if not ruler.is_empty() and sim.rng.randf() < 0.02:
			_remember(p, "Sonha em liderar " + str(home["name"]) + ".", sim)
	if sim.rng.randf() < 0.06:
		_socialize(sim, p, home)

func _set_task(sim, p: Dictionary, home: Dictionary, task: String, distance: float) -> void:
	var old_task: String = str(p.get("task", ""))
	p["work_timer"] = float(p.get("work_timer", 0.0)) - 0.75
	if old_task == task and float(p["work_timer"]) > 0.0:
		return
	p["task"] = task
	p["work_timer"] = sim.rng.randf_range(2.5, 5.0)
	var angle: float = sim.rng.randf_range(-PI, PI)
	var radius: float = sim.rng.randf_range(distance * 0.45, distance)
	p["target_x"] = clampf(float(home["x"]) + cos(angle) * radius, 1.0, float(sim.WIDTH - 2))
	p["target_y"] = clampf(float(home["y"]) + sin(angle) * radius, 1.0, float(sim.SIZE - 2))
	p["work_goal"] = true

func _socialize(sim, p: Dictionary, home: Dictionary) -> bool:
	var neighbors: Array = []
	for other in sim.people:
		if int(other["id"]) == int(p["id"]) or not bool(other["alive"]):
			continue
		if int(other["town"]) != int(home["id"]):
			continue
		if Vector2(float(other["x"]), float(other["y"])).distance_to(Vector2(float(p["x"]), float(p["y"]))) < SOCIAL_DISTANCE:
			neighbors.append(other)
	if neighbors.is_empty():
		p["target_x"] = float(home["x"]) + sim.rng.randf_range(-1.0, 1.0)
		p["target_y"] = float(home["y"]) + sim.rng.randf_range(-1.0, 1.0)
		return false
	var other: Dictionary = neighbors[sim.rng.randi_range(0, neighbors.size() - 1)]
	var other_id := str(other["id"])
	var relations: Dictionary = p["relations"]
	var friendship := float(relations.get(other_id, 0.0))
	var kindness := float(p["mind"]["kindness"])
	friendship = clampf(friendship + 4.0 + kindness * 4.0 - float(p["mind"]["ambition"]) * 2.0, -100.0, 100.0)
	relations[other_id] = friendship
	if not other.has("relations"):
		other["relations"] = {}
	var reverse: Dictionary = other["relations"]
	reverse[str(p["id"])] = clampf(float(reverse.get(str(p["id"]), 0.0)) + 3.0, -100.0, 100.0)
	if friendship > 50.0 and int(p["partner"]) == 0 and int(other["partner"]) == 0 and not _is_close_family(p, other):
		if float(p["age"]) >= 18.0 and float(other["age"]) >= 18.0:
			p["partner"] = other["id"]
			other["partner"] = p["id"]
			_remember(p, "Formou uma familia com " + str(other["name"]) + ".", sim)
			_remember(other, "Formou uma familia com " + str(p["name"]) + ".", sim)
			sim.news = str(p["name"]) + " e " + str(other["name"]) + " formaram uma familia."
	elif friendship < -50.0:
		_remember(p, "Desconfiou de " + str(other["name"]) + ".", sim)
	return true

func _is_close_family(first: Dictionary, second: Dictionary) -> bool:
	var first_id: int = int(first["id"])
	var second_id: int = int(second["id"])
	if first_id == second_id:
		return true
	if int(first["father"]) == second_id or int(first["mother"]) == second_id:
		return true
	if int(second["father"]) == first_id or int(second["mother"]) == first_id:
		return true
	if int(first["father"]) > 0 and int(first["father"]) == int(second["father"]):
		return true
	if int(first["mother"]) > 0 and int(first["mother"]) == int(second["mother"]):
		return true
	return false

func _remember(p: Dictionary, event: String, sim) -> void:
	var memories: Array = p["memories"]
	if memories.size() > 0 and str(memories[-1].get("event", "")) == event:
		return
	memories.append({"day": int(sim.day), "event": event})
	if memories.size() > MAX_MEMORIES:
		memories.pop_front()

func _chronicle(town: Dictionary, event: String, sim) -> void:
	var history: Array = town["historical_events"]
	history.append({"day": int(sim.day), "event": event})
	if history.size() > 12:
		history.pop_front()
	sim.news = str(town["name"]) + ": " + event

func on_death(sim, person: Dictionary) -> void:
	# Parentes e companheiros guardam eventos da linhagem entre sessoes.
	for witness in sim.people:
		if not bool(witness.get("alive", false)) or int(witness["id"]) == int(person["id"]):
			continue
		var is_family: bool = int(witness.get("partner", 0)) == int(person["id"]) or int(witness.get("father", 0)) == int(person["id"]) or int(witness.get("mother", 0)) == int(person["id"])
		if is_family:
			_init_person(sim, witness)
			_remember(witness, "Perdeu " + str(person["name"]) + ".", sim)
			var n: Dictionary = witness["needs"]
			n["company"] = minf(100.0, float(n["company"]) + 38.0)

func _site_work(sim,p:Dictionary,home:Dictionary,kind:String,task:String) -> bool:
	var site: Dictionary=sim.local_site(kind,int(home["id"]))
	if site.is_empty():
		_set_task(sim,p,home,"Procurando recursos",1.0)
		return false
	p["task"]=task
	p["work_timer"]=3.0
	p["work_goal"]=true
	p["target_x"]=float(site["x"])
	p["target_y"]=float(site["y"])
	return Vector2(float(p["x"]),float(p["y"])).distance_to(Vector2(float(site["x"]),float(site["y"])))<0.6

func _gather_wood(sim,p:Dictionary,home:Dictionary) -> void:
	var origin:=Vector2(float(p["x"]),float(p["y"]))
	var best:Dictionary={}
	var distance:float=1000.0
	for tree in sim.trees.values():
		if str(tree["state"])!="live" or sim.tree_scale(tree)<0.65: continue
		var q:=Vector2(float(tree["x"])+float(tree["ox"]),float(tree["y"])+float(tree["oy"]))
		var d:float=origin.distance_to(q)
		if d<distance:
			distance=d
			best=tree
	if best.is_empty(): return
	var goal:=Vector2(float(best["x"])+float(best["ox"]),float(best["y"])+float(best["oy"]))
	sim._set_delivery_goal(p,goal,"Coletando madeira")
	if distance<0.65 and sim.free_load(p)>=6.0:
		if sim.cut_tree(p,int(best["x"]),int(best["y"])):
			p["wood"]=int(p.get("wood",0))-3
			sim.collect_cargo(p,"wood",3.0)

func _hunt(sim,p:Dictionary,home:Dictionary) -> void:
	var pos:=Vector2(float(p["x"]),float(p["y"]))
	var best:Dictionary={}
	var distance:float=6.0
	for animal in sim.wildlife:
		if str(animal["species"]) not in ["rabbit","deer","boar","chicken"]: continue
		var q:=Vector2(float(animal["x"]),float(animal["y"]))
		if q.distance_to(Vector2(float(home["x"]),float(home["y"])))>5.0: continue
		var d:float=pos.distance_to(q)
		if d<distance:
			distance=d
			best=animal
	if best.is_empty():
		_set_task(sim,p,home,"Procurando alimento",2.0)
		return
	sim._set_delivery_goal(p,Vector2(float(best["x"]),float(best["y"])),"Cacando")
	if distance<0.45 and sim.collect_cargo(p,"meat",3.0):
		sim.wildlife.erase(best)
