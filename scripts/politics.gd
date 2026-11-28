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
					"opinion": (-10.0 if bool(source["hostile"]) != bool(target["hostile"]) else 50.0),
					"score": (45.0 if bool(source["hostile"]) != bool(target["hostile"]) else 75.0),
					"truce_until": 0.0
				}
			elif not relations[key].has("score"):
				var previous:Dictionary=relations[key]
				var status:String=str(previous.get("status","neutral"))
				previous["score"]=100.0 if status=="alliance" else (15.0 if status=="war" else (75.0 if status=="peace" else clampf((float(previous.get("opinion",15))+100.0)*0.5,30,99)))

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
	var score:float=15.0 if status=="war" else (100.0 if status=="alliance" else 75.0)
	var opinion:float=score*2.0-100.0
	var truce_until: float = sim.day + TRUCE_DAYS if status == "peace" or status == "alliance" else 0.0
	for town in [a, b]:
		var other_id: int = second_id if int(town["id"]) == first_id else first_id
		var relation: Dictionary = town["diplomacy"][str(other_id)]
		relation["status"] = status
		relation["opinion"] = opinion
		relation["score"] = score
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

func relation_score(sim,first_id:int,second_id:int) -> float:
	if first_id==second_id: return 100.0
	var relation:Dictionary=get_relation(sim,first_id,second_id)
	return float(relation.get("score",75.0))

func change_score(sim,first_id:int,second_id:int,change:float) -> float:
	var a:Dictionary=sim.get_town(first_id)
	var b:Dictionary=sim.get_town(second_id)
	if a.is_empty() or b.is_empty() or first_id==second_id: return 100.0
	var relation:Dictionary=get_relation(sim,first_id,second_id)
	var reverse:Dictionary=get_relation(sim,second_id,first_id)
	if relation.is_empty() or reverse.is_empty(): return 75.0
	if str(relation.get("status","neutral"))=="war": return float(relation.get("score",15.0))
	var score:float=clampf(float(relation.get("score",75.0))+change,0,100)
	# A chave de guerras continua valendo: conflitos de fronteira nao a ativam sozinhos.
	if not sim.wars: score=maxf(30.0,score)
	if score<30.0:
		set_treaty(sim,first_id,second_id,"war")
		# Preserva o valor que de fato cruzou o limite.
		for rel in [relation,reverse]:
			rel["score"]=score
			rel["opinion"]=score*2.0-100.0
		return score
	var status:String="alliance" if score>=100.0 else ("border" if score<=50.0 else "neutral")
	if str(relation.get("status",""))=="peace" and score>50 and sim.day<=float(relation.get("truce_until",0)): status="peace"
	for rel in [relation,reverse]:
		rel["score"]=score
		rel["opinion"]=score*2.0-100.0
		rel["status"]=status
	return score

func border_incident(sim,owner_id:int,visitor_id:int) -> float:
	var relation:Dictionary=get_relation(sim,owner_id,visitor_id)
	var score:float=relation_score(sim,owner_id,visitor_id)
	if score>=100.0 or str(relation.get("status",""))=="war": return score
	# Um incidente por par a cada 12 segundos de simulacao, nao por quadro ou aldeao.
	if sim.swamp_clock<float(relation.get("border_cooldown_until",-1.0)): return score
	for rel in [relation,get_relation(sim,visitor_id,owner_id)]:
		rel["border_cooldown_until"]=sim.swamp_clock+12.0
		rel["last_border_day"]=sim.day
	score=change_score(sim,owner_id,visitor_id,-3.0)
	var a:Dictionary=sim.get_town(owner_id)
	var b:Dictionary=sim.get_town(visitor_id)
	if score>=30.0:
		sim.news="%s: incursao de %s. Relacao %.0f/100."%[a["name"],b["name"],score]
		_record(a,sim.news,sim)
		_record(b,sim.news,sim)
	return score

func advance(sim, delta: float) -> void:
	elapsed += delta
	if elapsed < UPDATE_INTERVAL: return
	elapsed = 0.0
	prepare(sim)
	for i in range(sim.towns.size()):
		for j in range(i+1,sim.towns.size()):
			var a:Dictionary=sim.towns[i]
			var b:Dictionary=sim.towns[j]
			if sim.kingdom_id(a)==sim.kingdom_id(b) or sim.kingdom_id(a)!=int(a["id"]) or sim.kingdom_id(b)!=int(b["id"]): continue
			var aid:int=int(a["id"])
			var bid:int=int(b["id"])
			var status:String=get_status(sim,aid,bid)
			var relation:Dictionary=get_relation(sim,aid,bid)
			if status=="peace" and sim.day>float(relation.get("truce_until",0)):
				_change_status(sim,a,b,"neutral")
			if status=="war":
				if sim.wars and sim.rivals and sim.rng.randf()<0.08+maxf(sim.leader_aggression(a),sim.leader_aggression(b))*0.0016: _raid(sim,a,b)
				continue
			if status=="peace" and sim.day<=float(relation.get("truce_until",0)): continue
			if sim.day-float(relation.get("last_border_day",-100.0))<2.0: continue
			var aggression:float=maxf(sim.leader_aggression(a),sim.leader_aggression(b))
			var diplomacy:float=(sim.leader_diplomacy(a)+sim.leader_diplomacy(b))*0.5
			var change:float=clampf((diplomacy-aggression)*0.012,-0.6,0.6)
			if not sim.wars or not sim.rivals: change=maxf(0.0,change)
			# Aliados so perdem pontos por acoes diplomaticas, nao pelo tempo.
			if status=="alliance": continue
			change_score(sim,aid,bid,change)

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
			"border": translated = "Conflito de fronteira"
		lines.append("%s: %s - %.0f/100" % [other["name"], translated, relation_score(sim,town_id,int(other["id"]))])
	return "\n".join(lines)
