extends RefCounted
## Politica offline: relacoes persistentes, tratados, guerras e ataques economicos.
const UPDATE_INTERVAL := 4.0
const TRUCE_DAYS := 90.0
var elapsed := 0.0

func prepare(sim) -> void:
	for town in sim.towns:
		if not town.has("diplomacy") or typeof(town["diplomacy"]) != TYPE_DICTIONARY:
			town["diplomacy"] = {}
	for source in sim.towns:
		for target in sim.towns:
			if int(source["id"]) == int(target["id"]):
				continue
			var relations: Dictionary = source["diplomacy"]
			var key := str(target["id"])
			if not relations.has(key):
				relations[key] = {
					"status": "neutral",
					"opinion": (-65.0 if bool(source["hostile"]) != bool(target["hostile"]) else 15.0),
					"truce_until": 0.0
				}

func get_relation(sim, first_id: int, second_id: int) -> Dictionary:
	var source: Dictionary = sim.get_town(first_id)
	if source.is_empty() or first_id == second_id:
		return {}
	var relations: Dictionary = source.get("diplomacy", {})
	return relations.get(str(second_id), {})

func get_status(sim, first_id: int, second_id: int) -> String:
	return str(get_relation(sim, first_id, second_id).get("status", "neutral"))

func set_treaty(sim, first_id: int, second_id: int, status: String) -> bool:
	if first_id == second_id or not status in ["peace", "alliance", "war"]:
		return false
	prepare(sim)
	var a: Dictionary = sim.get_town(first_id)
	var b: Dictionary = sim.get_town(second_id)
	if a.is_empty() or b.is_empty():
		return false
	var opinion := -95.0 if status == "war" else (85.0 if status == "alliance" else 35.0)
	var truce_until: float = sim.day + TRUCE_DAYS if status == "peace" or status == "alliance" else 0.0
	for town in [a, b]:
		var other_id: int = second_id if int(town["id"]) == first_id else first_id
		var relation: Dictionary = town["diplomacy"][str(other_id)]
		relation["status"] = status
		relation["opinion"] = opinion
		relation["truce_until"] = truce_until
	match status:
		"peace":
			sim.news = "%s e %s assinaram um tratado de paz." % [a["name"], b["name"]]
		"alliance":
			sim.news = "%s e %s formaram uma alianca." % [a["name"], b["name"]]
		"war":
			sim.news = "%s declarou guerra a %s!" % [a["name"], b["name"]]
	_record(a, sim.news, sim)
	_record(b, sim.news, sim)
	return true

func advance(sim, delta: float) -> void:
	elapsed += delta
	if elapsed < UPDATE_INTERVAL:
		return
	elapsed = 0.0
	prepare(sim)
	for i in range(sim.towns.size()):
		for j in range(i + 1, sim.towns.size()):
			var a: Dictionary = sim.towns[i]
			var b: Dictionary = sim.towns[j]
			var status := get_status(sim, int(a["id"]), int(b["id"]))
			var relation: Dictionary = get_relation(sim, int(a["id"]), int(b["id"]))
			if status == "peace" and sim.day > float(relation.get("truce_until", 0.0)):
				_change_status(sim, a, b, "neutral")
			if not sim.wars or not sim.rivals:
				continue
			status = get_status(sim, int(a["id"]), int(b["id"]))
			if status == "neutral" and (bool(a["hostile"]) != bool(b["hostile"])):
				if sim.rng.randf() < 0.02:
					set_treaty(sim, int(a["id"]), int(b["id"]), "war")
			elif status == "war":
				if sim.rng.randf() < 0.20:
					_raid(sim, a, b)

func _change_status(sim, a: Dictionary, b: Dictionary, status: String) -> void:
	for town in [a, b]:
		var other_id: int = int(b["id"]) if int(town["id"]) == int(a["id"]) else int(a["id"])
		var relation: Dictionary = get_relation(sim, int(town["id"]), other_id)
		relation["status"] = status

func _raid(sim, a: Dictionary, b: Dictionary) -> void:
	var attacker: Dictionary = a if sim.rng.randf() < 0.5 else b
	var defender: Dictionary = b if int(attacker["id"]) == int(a["id"]) else a
	if sim.active_population(int(attacker["id"])) < 2 or sim.active_population(int(defender["id"])) < 2:
		return
	var attackers: int = sim.active_population(int(attacker["id"]))
	var defenders: int = sim.active_population(int(defender["id"]))
	var attack_score: float = float(attackers) * sim.rng.randf_range(0.7, 1.3) + float(attacker.get("morale", 50)) * 0.05
	var defense_score: float = float(defenders) * sim.rng.randf_range(0.7, 1.3) + float(defender.get("morale", 50)) * 0.05
	if attack_score > defense_score:
		var loot: float = minf(float(defender["food"]), sim.rng.randf_range(2.0, 7.0))
		defender["food"] = maxf(0.0, float(defender["food"]) - loot)
		attacker["food"] = float(attacker["food"]) + loot
		defender["morale"] = maxf(0.0, float(defender.get("morale", 60.0)) - 8.0)
		sim.news = "%s saqueou alimentos de %s." % [attacker["name"], defender["name"]]
	else:
		attacker["morale"] = maxf(0.0, float(attacker.get("morale", 60.0)) - 4.0)
		sim.news = "%s resistiu a um ataque de %s." % [defender["name"], attacker["name"]]
	_record(attacker, sim.news, sim)
	_record(defender, sim.news, sim)

func _record(town: Dictionary, event: String, sim) -> void:
	if not town.has("historical_events"):
		town["historical_events"] = []
	var history: Array = town["historical_events"]
	history.append({"day": int(sim.day), "event": event})
	if history.size() > 20:
		history.pop_front()

func describe(sim, town_id: int) -> String:
	var town: Dictionary = sim.get_town(town_id)
	if town.is_empty():
		return "Selecione uma aldeia no mapa primeiro."
	prepare(sim)
	var lines: Array[String] = []
	for other in sim.towns:
		if int(other["id"]) == town_id:
			continue
		var status := get_status(sim, town_id, int(other["id"]))
		var translated := "Neutra"
		match status:
			"peace": translated = "Paz"
			"alliance": translated = "Alianca"
			"war": translated = "Guerra"
		lines.append("%s: %s" % [other["name"], translated])
	return "\n".join(lines)
