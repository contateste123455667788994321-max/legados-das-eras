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
	if not p.has("profession"):
		var mind: Dictionary = p["mind"]
		if float(mind["bravery"]) > 0.8:
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

func _manage_town(sim, town: Dictionary, step: float) -> void:
	var pop := sim.active_population(int(town["id"]))
	# Construcoes efetivamente consomem materiais e aumentam capacidade produtiva.
	if pop > int(town["houses"]) * 5 and float(town["wood"]) >= 14.0:
		town["wood"] = float(town["wood"]) - 14.0
		town["houses"] = int(town["houses"]) + 1
		_chronicle(town, "Novas casas acolhem familias.", sim)
	if float(town["food"]) < float(pop) * 1.5 and float(town["wood"]) >= 18.0:
		town["wood"] = float(town["wood"]) - 18.0
		town["farms"] = int(town["farms"]) + 1
		_chronicle(town, "Os moradores abriram uma nova fazenda.", sim)
	town["food"] = maxf(0.0, float(town["food"]) + step * float(town["farms"]) * 0.15)
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
		p["target_x"] = float(home["x"])
		p["target_y"] = float(home["y"])
		return
	if float(n["company"]) >= 53.0:
		if _socialize(sim, p, home):
			n["company"] = maxf(0.0, float(n["company"]) - 38.0)
			return
	# A personalidade altera os objetivos de trabalho e as exploracoes.
	match str(p["profession"]):
		"Construtor":
			home["wood"] = float(home["wood"]) + step * (0.3 + float(m["ambition"]) * 0.6)
		"Explorador":
			home["knowledge"] = float(home["knowledge"]) + step * (0.08 + float(m["curiosity"]) * 0.3)
			if sim.rng.randf() < 0.10:
				p["target_x"] = clampf(float(p["x"]) + sim.rng.randf_range(-4, 4), 2.0, float(sim.SIZE - 3))
				p["target_y"] = clampf(float(p["y"]) + sim.rng.randf_range(-4, 4), 2.0, float(sim.SIZE - 3))
		"Guarda":
			p["target_x"] = float(home["x"]) + sim.rng.randf_range(-1.5, 1.5)
			p["target_y"] = float(home["y"]) + sim.rng.randf_range(-1.5, 1.5)
			home["morale"] = minf(100.0, float(home["morale"]) + step * 0.1)
		_:
			home["food"] = float(home["food"]) + step * (0.25 + float(m["kindness"]) * 0.25)
	# Laços familiares e rivalidades alteram a lealdade entre pessoas.
	if float(m["ambition"]) > 0.88 and str(p["role"]) == "Aldeao":
		var ruler: Dictionary = sim.get_person(int(home["leader"]))
		if not ruler.is_empty() and sim.rng.randf() < 0.02:
			_remember(p, "Sonha em liderar " + str(home["name"]) + ".", sim)
	if sim.rng.randf() < 0.06:
		_socialize(sim, p, home)

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
	if friendship > 50.0 and int(p["partner"]) == 0 and int(other["partner"]) == 0:
		if float(p["age"]) >= 18.0 and float(other["age"]) >= 18.0:
			p["partner"] = other["id"]
			other["partner"] = p["id"]
			_remember(p, "Formou uma familia com " + str(other["name"]) + ".", sim)
			_remember(other, "Formou uma familia com " + str(p["name"]) + ".", sim)
			sim.news = str(p["name"]) + " e " + str(other["name"]) + " formaram uma familia."
	elif friendship < -50.0:
		_remember(p, "Desconfiou de " + str(other["name"]) + ".", sim)
	return true

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
