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

func set_treaty(sim, first_id: int, second_id: int, status: String, decisive:bool=false) -> bool:
	if first_id == second_id or not status in ["peace", "alliance", "war"]:
		return false
	prepare(sim)
	var a: Dictionary = sim.get_town(first_id)
	var b: Dictionary = sim.get_town(second_id)
	if a.is_empty() or b.is_empty():
		return false
	if get_status(sim,first_id,second_id)=="war" and status!="war" and not decisive: return false
	if status=="war" and get_status(sim,first_id,second_id)!="war":
		for town in [a,b]:
			town["wartime_ruler"]=int(town.get("leader",0))
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
			if sim.kingdom_id(a)==sim.kingdom_id(b) or sim.kingdom_id(a)!=int(a["id"]) or sim.kingdom_id(b)!=int(b["id"]): continue
			var status := get_status(sim, int(a["id"]), int(b["id"]))
			var relation: Dictionary = get_relation(sim, int(a["id"]), int(b["id"]))
			if status == "peace" and sim.day > float(relation.get("truce_until", 0.0)):
				_change_status(sim, a, b, "neutral")
			if not sim.wars or not sim.rivals:
				continue
			status = get_status(sim, int(a["id"]), int(b["id"]))
			var aggression:float=maxf(sim.leader_aggression(a),sim.leader_aggression(b))
			var diplomacy:float=(sim.leader_diplomacy(a)+sim.leader_diplomacy(b))*0.5
			var opinion:float=float(relation.get("opinion",0))
			if status=="neutral":
				var change:float=(diplomacy-aggression)*0.045
				if bool(a["hostile"])!=bool(b["hostile"]): change-=1.0
				opinion=clampf(opinion+change,-100,100)
				relation["opinion"]=opinion
				get_relation(sim,int(b["id"]),int(a["id"]))["opinion"]=opinion
				var attacker:Dictionary=a if sim.leader_aggression(a)>=sim.leader_aggression(b) else b
				var target:Dictionary=b if int(attacker["id"])==int(a["id"]) else a
				if aggression>=70 and opinion< -25 and sim.rng.randf()<0.015+(aggression-70)*0.001:
					set_treaty(sim,int(attacker["id"]),int(target["id"]),"war")
				elif opinion>65 and diplomacy>=65 and aggression<55 and sim.rng.randf()<0.03:
					set_treaty(sim,int(a["id"]),int(b["id"]),"alliance")
			elif status=="war":
				if sim.rng.randf()<0.08+aggression*0.0016:
					_raid(sim,a,b)

func _change_status(sim, a: Dictionary, b: Dictionary, status: String) -> void:
	for town in [a, b]:
		var other_id: int = int(b["id"]) if int(town["id"]) == int(a["id"]) else int(a["id"])
		var relation: Dictionary = get_relation(sim, int(town["id"]), other_id)
		relation["status"] = status

func _raid(sim, a: Dictionary, b: Dictionary) -> void:
	var attacker:Dictionary=a if sim.rng.randf()<0.5 else b
	var defender:Dictionary=b if int(attacker["id"])==int(a["id"]) else a
	if not sim.begin_campaign(attacker,defender): sim.begin_campaign(defender,attacker)

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
