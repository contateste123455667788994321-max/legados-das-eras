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
	_check(world.tiles.size() == World.SIZE and world.tiles[0].size()==World.WIDTH, "Mapa largo gerado")
	var decay_world=World.new()
	decay_world.generate_world()
	var abandoned:Dictionary=decay_world.towns[0]
	abandoned["houses"]=2
	abandoned["house_levels"]=[1,2]
	var abandoned_id:int=int(abandoned["id"])
	decay_world._update_abandoned_houses()
	_check(decay_world.house_decay(abandoned)==0.0 and int(abandoned["houses"])==2,"Casas habitadas nao deterioram")
	for resident in decay_world.people:
		if int(resident["town"])==abandoned_id: resident["alive"]=false
	decay_world._update_abandoned_houses()
	decay_world.day+=365.0 * 5.0
	decay_world._update_abandoned_houses()
	_check(decay_world.house_decay(abandoned)>0.0 and int(abandoned["houses"])==2,"Casas abandonadas mofam antes do colapso")
	decay_world.day+=World.HOUSE_DECAY_DAYS-365.0*5.0
	decay_world._update_abandoned_houses()
	_check(int(abandoned["houses"])==1 and decay_world.house_levels(abandoned).size()==1,"Primeira casa desaba apos o prazo")
	decay_world.day+=World.HOUSE_COLLAPSE_INTERVAL
	decay_world._update_abandoned_houses()
	_check(int(abandoned["houses"])==0 and decay_world.house_levels(abandoned).is_empty(),"Casas abandonadas desaparecem gradualmente")
	decay_world.make_person(abandoned_id,float(abandoned["x"]),float(abandoned["y"]))
	decay_world._update_abandoned_houses()
	_check(decay_world.house_decay(abandoned)==0.0 and not abandoned.has("abandoned_day"),"Reocupacao encerra deterioracao")
	var random_map=World.new()
	random_map.generate_world()
	_check(world.map_seed!=random_map.map_seed and world.tiles!=random_map.tiles,"Cada mundo novo possui distribuicao aleatoria")
	for town in world.towns:
		_check(int(town["houses"])==0 and int(town["farms"])==0 and world.housing_capacity(town)==0 and town["construction"].is_empty(),"Mundo novo inicia sem casas ou fazendas prontas")
	_check(world.house_layout(world.towns[0]).size()==8 and world.farm_layout(world.towns[0]).size()==6,"Aldeia usa lotes organizados para casas e plantacoes")
	_check(not world.sites.is_empty(), "Locais de producao gerados")
	_check(not world.wildlife.is_empty(), "Fauna pacifica gerada")
	_check(world.habitats_v59 and world.wildlife.size()>24,"Fauna dos novos biomas")
	_check(world.fauna_v3,"Novas especies disponiveis no mundo")
	for species in ["cow","sheep","goat","horse","pig","dog","cat","eagle","owl","crow","bat","penguin"]:
		_check(World.SPAWN_NAMES.has(species) and world.spawn_creature(species,Vector2(5,5)),"Criacao manual de "+species)
		_check(float(world.wildlife.back()["health"])>0,"Vida de "+species)
	_check(World.FLYING_SPECIES.has("eagle") and not World.FLYING_SPECIES.has("penguin"),"Voo apenas para especies capazes")
	_check(world.ecology_v60,"Ecologia diferenciada ativa")
	var swim_world=World.new()
	swim_world.generate_world()
	for yy in range(7,10):
		for xx in range(7,10): swim_world.tiles[yy][xx]="water"
	_check(swim_world.water_depth(Vector2(8,8))>=0.60,"Agua central tem profundidade para nadar")
	swim_world.tiles[8][7]="grass"
	_check(swim_world.water_depth(Vector2(7,8))==0.0,"Terra firme nao tem profundidade")
	var dry_shore:int=0
	var wet_shore:int=0
	var shore_matches:bool=true
	for i in range(49):
		var point:=Vector2(7.0+float(i)/48.0,8.0)
		var visually_wet:bool=swim_world.water_surface_weight(point)>0.46
		if visually_wet: wet_shore+=1
		else: dry_shore+=1
		if (swim_world.water_depth(point)>0.0)!=visually_wet: shore_matches=false
	_check(dry_shore>0 and wet_shore>0 and shore_matches,"Margem irregular: nada apenas nos pixels de agua")

	var swimmer:Dictionary={"x":8.0,"y":8.0,"task":"Pescando"}
	_check(swim_world.visible_action(swimmer)=="swimming","Humano guarda itens ao nadar")
	_check(swim_world.swim_speed({"species":"duck"},1.0)>swim_world.swim_speed(swimmer,1.0),"Pato nada mais rapido que humano")
	swim_world.sites.append({"kind":"crossing","x":8,"y":8})
	_check(swim_world.water_depth(Vector2(8,8))==0,"Ponte permite caminhada")
	swim_world.trees.clear()
	swim_world._plant_tree(5,5,true)
	var stump:Dictionary=swim_world.trees["5:5"]
	stump["state"]="stump"
	stump["stump_until"]=swim_world.day+1.0
	swim_world._update_trees(0.1)
	_check(swim_world.trees.has("5:5"),"Toco permanece durante prazo")
	swim_world.day+=2.0
	swim_world._update_trees(0.1)
	_check(not swim_world.trees.has("5:5"),"Toco desaparece apos prazo")
	world.sound_events.clear()
	world.sound_event("wood",Vector2(5,5))
	_check(world.sound_events.size()==1 and str(world.sound_events[0]["kind"])=="wood","Eventos sonoros sem alterar simulacao")
	world.sound_events.clear()
	for animal in world.wildlife:
		_check(float(animal["health"])>0 and float(animal["max_health"])>=float(animal["health"]),"Animal nasce com vida")
	var duck:Dictionary={"species":"duck"}
	world.init_animal_health(duck)
	_check(not world.damage_animal(duck,5.0) and float(duck["health"])==20.0,"Pato recebe dano sem morrer instantaneamente")
	_check(world.damage_animal(duck,20.0) and float(duck["health"])==0.0,"Animal morre ao zerar vida")
	var crocodile:Dictionary={"id":-50,"species":"crocodile","x":5.0,"y":5.0}
	world.damage_animal(crocodile,200.0)
	_check(int(world.resource_drops.back()["items"]["croc_hide"])==2,"Crocodilo deixa couro especial")
	var stock_town:Dictionary=world.towns[0]
	world.store_resource(stock_town,"house_0","bone",2)
	var camp_stocks:Dictionary=world.building_stocks(stock_town)
	_check(not camp_stocks.has("house_0") and float(camp_stocks.get("camp",{}).get("bone",0))==2 and float(stock_town["bone"])==2,"Tribo sem casas guarda recursos no acampamento")
	# Uma aldeia independente com casa pronta permite validar o estoque por edificio.
	var housed_town:Dictionary={"houses":1,"house_levels":[1],"bone":0.0}
	world.store_resource(housed_town,"house_0","bone",2)
	_check(float(world.building_stocks(housed_town).get("house_0",{}).get("bone",0))==2 and float(housed_town["bone"])==2,"Estoque por casa e total coerentes")
	var craft_town:Dictionary={"id":777,"x":5,"y":5,"houses":1,"level":1,"wood":20.0,"stone":5.0,"fiber":2.0,"forge":false}
	var early_camp := {"houses":0, "level":1, "wood":2.0}
	_check(world.craft_item(early_camp,"wood_spear") and early_camp["wood"] == 0.0 and early_camp["wood_spear"] == 1.0, "Lança de madeira disponível antes de obter pedra")
	var previous_damage := 0.0
	for kind in ["wood_spear", "spear", "iron_spear", "sword", "steel_sword"]:
		var damage:float = world.attack_damage({"id": 71, "strength": 40, "weapon_kind": kind, "weapon": World.WEAPON_LEVEL[kind]})
		_check(damage > previous_damage, "Progressão de dano: " + World.RESOURCE_NAMES[kind])
		previous_damage = damage
	_check(not world.craft_item(craft_town,"sword"),"Espada nao existe antes da forja")
	_check(world.craft_item(craft_town,"spear") and float(craft_town["spear"])==1,"Lanca produzida e armazenada")
	_check(not world.craft_item({"level":1,"wood":2.0},"wood_shield"),"Escudo exige materiais")
	var defender:Dictionary={"shield_kind":"wood_shield","war_xp":100.0}
	_check(world.arrow_damage(defender,20.0)<world.arrow_damage({},20.0),"Escudo reduz dano de flecha")
	_check(world.arrow_damage({"shield_kind":"iron_shield","war_xp":100.0},20.0)<world.arrow_damage(defender,20.0),"Escudo de ferro protege mais")
	_check(not world.craft_item(craft_town,"bow"),"Arco exige corda")
	_check(world.craft_item(craft_town,"cord") and world.craft_item(craft_town,"bow"),"Fibra vira corda e arco")
	_check(world.craft_item(craft_town,"pickaxe"),"Picareta primitiva fabricada")
	craft_town["forge"]=true
	craft_town["level"]=3
	craft_town["ore"]=6.0
	for n in range(3): world.craft_item(craft_town,"metal")
	_check(world.craft_item(craft_town,"sword") and float(craft_town["metal"])==0,"Minerio fundido vira espada")
	_check(world.animal_habitat("crocodile","water") and not world.animal_habitat("crocodile","sand"),"Crocodilo respeita habitat")
	_check(world._animal_prey("crocodile","duck") and not world._animal_prey("deer","duck"),"Predacao especifica por especie")
	_check(world.towns.size() == 3, "Tres aldeias iniciais")
	var swamp=World.new()
	swamp.generate_world()
	swamp._seed_swamp_witch(true)
	_check(float(swamp.swamp_witch["health"])==500.0,"Bruxa possui cinco vezes a vida humana")
	swamp._spawn_spider_pair(swamp.swamp_witch)
	_check(swamp.swamp_spiders.size()==2 and float(swamp.swamp_spiders[0]["health"])==50.0 and float(swamp.swamp_spiders[1]["health"])==50.0,"Invocacao de duas aranhas com 50 de vida")
	swamp.swamp_spiders.clear()
	var poisoned:Dictionary=swamp.people[1]
	var before_poison:float=float(poisoned["health"])
	swamp.apply_spider_poison(poisoned)
	swamp._update_spider_poison(poisoned,2.0)
	swamp.apply_spider_poison(poisoned)
	swamp._update_spider_poison(poisoned,3.0)
	_check(is_equal_approx(float(poisoned["health"]),before_poison-15.0) and float(poisoned["poison_remaining"])==0.0,"Veneno dura cinco segundos e causa 15 de dano sem acumular")
	poisoned["health"]=before_poison
	var champion:Dictionary=swamp.people[0]
	champion["x"]=swamp.swamp_witch["x"]
	champion["y"]=swamp.swamp_witch["y"]
	swamp.swamp_witch["health"]=1.0
	_check(swamp.strike_witch(champion),"Humano derrota bruxa")
	_check(int(champion["level"])>1 and swamp.max_hp(champion)>100,"Vitoria concede XP e vida maxima")
	var recruit:Dictionary=swamp.people[1]
	var base_hp:float=swamp.max_hp(recruit)
	swamp.train_guard(recruit)
	_check(swamp.max_hp(recruit)==base_hp+35,"Treinamento militar aumenta vida")
	var old_intelligence:float=float(recruit["intelligence"])
	swamp.gain_xp(recruit,swamp.xp_required(recruit),"estudo")
	_check(int(recruit["level"])==2 and float(recruit["intelligence"])>old_intelligence,"XP de estudo aumenta inteligencia")
	_check(not bool(swamp.swamp_witch["alive"]) and bool(champion.get("witch_staff",false)),"Vencedor recebe cajado unico")
	_check(not swamp.strike_witch(swamp.people[1]),"Cajado nao pode ser duplicado")
	swamp._seed_swamp_witch(true)
	_check(not bool(swamp.swamp_witch["alive"]),"Bruxa nao renasce automaticamente")
	swamp.tiles[5][5]="grass"
	_check(swamp.spawn_creature("witch",Vector2(5,5)) and bool(swamp.swamp_witch["alive"]),"Criador invoca bruxa em terra firme")
	_check(not swamp.spawn_creature("witch",Vector2(5,5)),"Apenas uma bruxa viva por mundo")
	_check(bool(swamp.swamp_witch["staff_awarded"]),"Invocacao manual preserva unicidade do cajado")
	swamp.swamp_witch["alive"]=false
	var bird:Dictionary={"species":"heron","id":991,"x":5.0,"y":5.0,"flight_wait":0.0}
	_check(swamp._bird_flight(bird,0.1) and float(bird["flight_height"])>0,"Garca decola de verdade")
	swamp.swamp_spiders.append({"id":99999,"x":champion["x"],"y":champion["y"],"health":35.0})
	_check(swamp.cast_staff(champion) and not swamp.cast_staff(champion),"Cajado dispara com recarga")
	var creator=World.new()
	creator.generate_world()
	var start:Dictionary=creator.towns[0]
	var point:=Vector2(float(start["x"]),float(start["y"]))
	var count:int=creator.people.size()
	_check(creator.spawn_creature("human",point) and creator.people.size()==count+1,"Criador adiciona exatamente um humano")
	_check(int(creator.people.back()["town"])==int(start["id"]),"Criador integra morador na aldeia proxima")
	creator.tiles[10][37]="swamp"
	var animals:int=creator.wildlife.size()
	_check(creator.spawn_creature("crocodile",Vector2(37,10)) and creator.wildlife.size()==animals+1,"Criador adiciona crocodilo no pantano")
	creator.tiles[10][38]="sand"
	_check(creator.spawn_creature("crocodile",Vector2(38,10)),"Criador permite crocodilo fora do habitat")
	_check(creator.spawn_creature("wolf",Vector2(38,10)),"Criador permite lobo em outro bioma")
	var towns_count:int=creator.towns.size()
	creator.tiles[10][40]="grass"
	_check(creator.spawn_creature("human",Vector2(40,10)) and creator.towns.size()==towns_count+1,"Humano distante funda nova tribo")
	_check(int(creator.towns.back()["houses"])==0 and int(creator.towns.back()["farms"])==0,"Nova tribo nao recebe edificios prontos")
	# Civilizacoes nao podem evoluir para Era 4 no primeiro ano.
	var rate_world = World.new()
	rate_world.generate_world()
	rate_world.towns[0]["knowledge"] = 1000.0
	rate_world.update_world(0.1)
	_check(int(rate_world.towns[0]["level"]) == 1, "Pesquisa nao permite saltar eras no primeiro ano")
	rate_world.day = 730.0
	rate_world.update_world(0.1)
	_check(int(rate_world.towns[0]["level"]) == 2, "Segunda era depende da passagem de geracoes")


	# Um jogador deve poder mandar construir, ver o trabalho e manter os recursos.
	var founding_world = World.new()
	founding_world.generate_world()
	founding_world.towns[0]["wood"]=14.0
	founding_world.agent_ai.advance(founding_world,1.0)
	_check(str(founding_world.towns[0]["construction"].get("kind",""))=="house" and int(founding_world.towns[0]["houses"])==0,"Primeira casa e iniciada pela IA, nao gerada pronta")
	var building_world = World.new()
	building_world.generate_world()
	var target_town: Dictionary = building_world.towns[0]
	var target_id: int = int(target_town["id"])
	var original_houses: int = int(target_town.get("houses", 2))
	_check(building_world.housing_capacity(target_town)==0,"Tribo nova nao tem capacidade de moradia antes de construir")
	target_town["houses"]=2
	target_town["house_levels"]=[1,1]
	_check(building_world.housing_capacity(target_town)==8,"Duas cabanas abrigam oito moradores")
	target_town["house_levels"]=[1,2]
	_check(building_world.housing_capacity(target_town)==10,"Casa ampliada aumenta capacidade")
	target_town["houses"]=0
	target_town["house_levels"]=[]
	_check(not building_world.start_construction(target_id,"castle"),"Castelo exige tecnologia")
	_check(building_world.workshop_stone_cost("castle")==300.0 and building_world.construction_cost("castle")==150.0,"Castelo exige 300 pedras e 150 madeira")
	var fence_world=World.new()
	fence_world.generate_world()
	var fence_town:Dictionary=fence_world.towns[0]
	fence_town["x"]=12
	fence_town["y"]=12
	for yy in range(6,19):
		for xx in range(6,19):
			fence_world.tiles[yy][xx]="water" if xx==7 else "grass"
	var fence_count:int=0
	var gate_count:int=0
	var fence_valid:bool=true
	var fence_next:Dictionary=fence_world.next_palisade(fence_town)
	while not fence_next.is_empty() and fence_count<50:
		var fx:int=int(fence_next["x"])
		var fy:int=int(fence_next["y"])
		var gate:Dictionary=fence_town["palisade_gate"]
		if str(fence_world.tiles[fy][fx])=="water": fence_valid=false
		if bool(fence_next.get("gate",false)):
			gate_count+=1
			if fx!=int(gate["x"]) or fy!=int(gate["y"]): fence_valid=false
		var built:Array=fence_town.get("palisades",[])
		built.append(fence_next)
		fence_town["palisades"]=built
		fence_count+=1
		fence_next=fence_world.next_palisade(fence_town)
	_check(fence_valid and fence_count>0 and fence_count<40 and gate_count==1 and fence_next.is_empty(),"Paliçada preserva rio e portão único")
	var siege_wall:Dictionary={"x":12,"y":17,"axis":"h","gate":true,"health":100.0}
	fence_town["palisades"]=[siege_wall]
	_check(not fence_world.damage_palisade(fence_town,siege_wall,35.0) and float(siege_wall["health"])==65.0,"Portão perde vida a cada ataque")
	_check(fence_world.damage_palisade(fence_town,siege_wall,65.0) and fence_town["palisades"].is_empty(),"Portão destruído abre passagem")
	_check(fence_world.WALL_HP==150.0 and fence_world.GATE_HP==100.0,"Resistência individual das defesas")

	var original_wood: float = float(target_town["wood"])
	_check(not building_world.start_construction(target_id, "bridge"), "Nao aceita construcoes desconhecidas")
	_check(not building_world.start_construction(target_id,"forge"),"Forja exige tecnologia e recursos")
	_check(not bool(target_town.get("oven",false)) and building_world.local_site("oven",target_id).is_empty(),"Forno nao nasce pronto")
	_check(not building_world.start_construction(target_id,"oven"),"Forno exige pedra e madeira")
	_check(not building_world.start_construction(target_id, "house"), "Recusa obra sem madeira")
	target_town["wood"] = 50.0
	_check(building_world.start_construction(target_id, "house"), "Jogador inicia uma casa com recursos")
	_check(float(target_town["wood"]) == 36.0, "Uma casa consome 14 madeiras")
	_check(not building_world.start_construction(target_id, "farm"), "Uma vila so pode executar uma obra por vez")
	_check(int(target_town["houses"]) == original_houses, "Casa nao surge magicamente antes da obra")
	building_world.progress_construction(target_town,20.0)
	_check(float(target_town["construction"]["progress"])==0.0,"Sem materiais ou trabalhadores a obra nao avanca")
	var worker:Dictionary=building_world.people[0]
	worker["x"]=target_town["x"]
	worker["y"]=target_town["y"]
	var project:Dictionary=target_town["construction"]
	building_world.transport_job(worker,target_town)
	_check(not worker.get("cargo",{}).is_empty(),"Trabalhador retira carga do estoque")
	_check(building_world.carried_weight(worker)<=building_world.load_capacity(worker),"Respeita peso")
	for trip in range(6):
		worker["x"]=project["x"]
		worker["y"]=project["y"]
		building_world.transport_job(worker,target_town)
		if float(project["delivered"]["wood"])>=14: break
		worker["x"]=target_town["x"]
		worker["y"]=target_town["y"]
		building_world.transport_job(worker,target_town)
	_check(float(project["delivered"]["wood"])==14.0,"Madeira entregue em viagens")
	building_world.transport_job(worker,target_town)
	building_world.progress_construction(target_town,20.0)
	_check(int(target_town["houses"]) == original_houses + 1, "A casa fica pronta depois do trabalho")
	_check(target_town.get("construction", {}).is_empty(), "A obra pronta sai da fila")
	_check(target_town.get("historical_events", []).size() > 0, "Obra entra na historia da aldeia")
	building_world.agent_ai.advance(building_world,1.0)
	var gardener: Dictionary = building_world.people[5]
	_check(str(gardener.get("task", "")) != "", "Morador tem atividade visivel")
	_check(float(gardener.get("work_timer", 0.0)) > 0.0, "Morador possui destino de trabalho")

	var terrain_kinds := {}
	for row in world.tiles:
		for kind in row:
			terrain_kinds[str(kind)] = true
	for biome in ["grass", "forest", "sand", "snow", "mountain", "water"]:
		_check(terrain_kinds.has(biome), "Mapa tem bioma " + biome)
	_check(str(world.towns[0].get("home_biome", "")) != "", "Aldeias guardam o bioma de origem")
	_check(terrain_kinds.size() >= 5, "Mapa possui regioes ecologicas variadas")
	_check(world.people.size() == 18, "Habitantes iniciais")
	_check(world.army_limit(6,3,1)==1,"Aldeia pequena preserva trabalhadores")
	_check(world.royal_guard_size(3)==2 and world.royal_guard_size(12)==5 and world.royal_guard_size(25)==10,"Escolta proporcional")
	var conquest=World.new()
	conquest.generate_world()
	var capital:Dictionary=conquest.towns[0]
	var enemy:Dictionary=conquest.towns[1]
	conquest.annex_town(capital,enemy)
	_check(conquest.kingdom_id(capital)==conquest.kingdom_id(enemy),"Conquista preserva aldeia como territorio")
	_check(float(world.people[3]["age"]) < 16.0, "O mundo ja nasce com criancas")
	_check(int(world.people[3]["father"]) > 0 and int(world.people[3]["mother"]) > 0, "Crianca ja nasce em familia")
	var forest_tiles := 0
	var desert_tiles := 0
	var snow_tiles := 0
	for row in world.tiles:
		for tile in row:
			match str(tile):
				"forest": forest_tiles += 1
				"sand": desert_tiles += 1
				"snow": snow_tiles += 1
	_check(forest_tiles >= 10 and desert_tiles >= 10 and snow_tiles >= 10, "Biomas amplos presentes no mapa")
	# Forca um casal adulto conhecido para testar nascimentos e linhagens.
	var parent_a: Dictionary = world.people[0]
	var parent_b: Dictionary = world.people[1]
	parent_a["gender"] = 0
	parent_b["gender"] = 1
	parent_a["age"] = 26.0
	parent_b["age"] = 25.0
	parent_a["partner"] = parent_b["id"]
	parent_b["partner"] = parent_a["id"]
	var count_before: int = world.people.size()
	world._new_children()
	_check(world.people.size()==count_before,"Sem moradia, aldeias fundadoras nao aumentam a populacao")
	# Simula duas casas ja concluidas para testar a reproducao separadamente.
	world.towns[0]["houses"]=2
	world.towns[0]["house_levels"]=[1,1]
	world._new_children()
	_check(world.people.size() > count_before, "Casais podem ter filhos quando ha moradia")
	for i in range(count_before, world.people.size()):
		var child: Dictionary = world.people[i]
		_check(int(child["father"]) > 0 and int(child["mother"]) > 0, "Criancas tem pais identificaveis")
		_check(int(child["father"]) != int(child["mother"]), "Linhagem usa dois pais diferentes")

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
	_check(not world.politics.set_treaty(world, first_town, second_town, "peace"), "Guerra nao termina por tratado prematuro")
	_check(world.politics.set_treaty(world, first_town, second_town, "peace",true), "Paz apos desfecho militar")
	_check(world.politics.get_status(world, second_town, first_town) == "peace", "Tratado reconhecido pelos dois lados")
	_check(not world.politics.set_treaty(world, first_town, first_town, "war"), "Nao permite guerra contra si mesmo")

	var paused_day: float = world.day
	world.speed = 0.0
	world.update_world(1.0)
	_check(is_equal_approx(world.day, paused_day), "Pausa congela o tempo")
	world.speed = 1.0
	world.toggle_predators()
	_check(world.predators and world.beasts.size() == 8, "Animais ativaveis")
	var attack_world=World.new()
	attack_world.generate_world()
	attack_world.predators=true
	var victim:Dictionary=attack_world.people[0]
	attack_world.people=[victim]
	victim["alive"]=true
	victim["health"]=100.0
	victim["x"]=5.0
	victim["y"]=5.0
	var wolf:Dictionary={"id":-401,"species":"Lobo","alive":true,"health":85.0,"max_health":85.0,"x":6.2,"y":5.0}
	var victim_hp:float=float(victim["health"])
	_check(attack_world._hostile_animal_step(wolf,0.1) and float(wolf["x"])<6.2 and float(victim["health"])==victim_hp,"Lobo persegue alvo sem causar dano a distancia")
	wolf["x"]=5.3
	_check(attack_world._hostile_animal_step(wolf,0.1) and float(victim["health"])<victim_hp,"Lobo ataca humano ao alcance")
	var after_hit:float=float(victim["health"])
	attack_world._hostile_animal_step(wolf,0.1)
	_check(float(victim["health"])==after_hit,"Lobo respeita intervalo entre ataques")
	attack_world.predators=false
	_check(not attack_world._hostile_animal_step(wolf,1.0),"Ataques desativados respeitam controle do jogador")
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
	var new_leader:Dictionary=loaded.get_person(int(loaded.towns[0]["leader"]))
	for candidate in loaded.people:
		if bool(candidate["alive"]) and int(candidate["town"])==int(loaded.towns[0]["id"]) and float(candidate["age"])>=16:
			_check(loaded.leadership_score(new_leader)>=loaded.leadership_score(candidate),"Lider eleito por merito")
	# Exercita a janela de diplomacia em modo headless para verificar controles reais.
	var game: Node2D = Main.new()
	root.add_child(game)
	_check(not game.texture_missing, "Todos os desenhos de pixel art foram importados")
	_check(game._valid_world_path("user://world.json") and game._valid_world_path("user://worlds/123.json") and not game._valid_world_path("user://worlds/../123.json"),"Mundos usam arquivos separados e caminhos validados")
	game._open_home(false)
	_check(game.home_open and game.home_buttons.size()==3 and game.world.speed==0,"Menu inicial pausa o mundo e tem tres botoes")
	_check(is_instance_valid(game.home_art) and game.home_art.texture.resource_path == game.HOME_ART_PATH, "Menu usa a paisagem de Vale Dourado")
	_check(game.home_art.size.is_equal_approx(game.home_panel.size), "Arte do menu preenche toda a tela sem barras")
	game._enter_world()
	_check(not game.home_open and game.world.speed>0,"Continuar fecha menu e retoma simulacao")
	var new_humans: Texture2D = game.landscape_objects["habitantes"]
	_check(new_humans.get_size() == Vector2(1920, 1728), "Prancha humana com 36 figurinos, quatro variantes e dez poses")
	var portrait_actor := {"id":11, "gender":1, "age":28, "profession":"Ferreiro"}
	var portrait: AtlasTexture = game._human_portrait(portrait_actor)
	_check(portrait.atlas == new_humans and portrait.region == game._human_source(portrait_actor, 0), "Ficha usa exatamente o figurino do mapa")
	portrait_actor["military_role"] = "soldier"
	portrait_actor["armor"] = 3
	_check(game._human_source(portrait_actor, 6).position.y != portrait.region.position.y, "Armadura e combate selecionam sprites militares reais")
	var visual_worker:Dictionary={"x":5.0,"y":5.0,"target_x":8.0,"target_y":5.0,"task":"Pescando"}
	_check(game.world.visible_action(visual_worker).is_empty(),"Pescador guarda vara durante deslocamento")
	visual_worker["target_x"]=5.0
	_check(game.world.visible_action(visual_worker)=="fishing","Pescador mostra ferramenta ao chegar")
	_check(game.tile_textures.size() == 9, "Nove imagens de terrenos e estacoes carregadas")
	_check(game.actor_textures.size() == 9 and game.actor_textures.get("tribal_hut") is Texture2D and game.actor_textures.get("hut") is Texture2D, "Nove sprites incluindo cabana tribal e casa evoluida carregados")
	_check(int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 1280, "Tela horizontal configurada")
	_check(game.MAP_AREA.size.x > 1200.0 and game.MAP_AREA.size.y > 600.0, "Mapa quase preenche a tela horizontal")
	_check(not is_instance_valid(game.viewport_3d), "Jogo exclusivamente 2D")
	_check(is_instance_valid(game.view_button), "Controle direto no mapa")
	game.call("_toggle_view")
	_check(game.controlled_id>0 and game.action_button.visible, "Controle e coleta no mapa")
	game.call("_toggle_view")
	_check(game.controlled_id==0 and not game.action_button.visible, "Mapa limpo ao soltar")
	game.call("_focus_biome", "snow")
	_check(not game.character_view, "Atalho para clima frio retorna ao mapa")
	_check(str(ProjectSettings.get_setting("autoload/PatchLoader", "")).contains("patch_loader.gd"), "Pacotes do jogo carregam antes da tela inicial")
	_check(game.tile_textures.size() >= 9, "Arte do mundo continua disponivel")
	var zoom_buttons_found := false
	for child in game.get_children():
		if child is Button and str(child.text).begins_with("Zoom"):
			zoom_buttons_found = true
	_check(not zoom_buttons_found, "Tela nao possui botao de zoom, gestos multitouch assumem a funcao")
	_check(game.has_method("_draw_clock"), "Relogio visual do tempo existe")
	game.call("_toggle_view")
	_check(game.controlled_id>0, "Controle de personagem no mapa")
	game.call("_toggle_view")
	_check(game.controlled_id==0, "Jogador pode soltar personagem")
	game.call("_show_construction")
	var construction_dialog_found := false
	for popup in game.get_children():
		if popup is ConfirmationDialog and popup.title == "Construir na aldeia":
			construction_dialog_found = true
			popup.hide()
	_check(construction_dialog_found, "Jogador consegue abrir escolha de casas e fazendas")
	_check(game._preferred_town_id() > 0, "Botao construir encontra uma aldeia proxima")
	game.call("_show_diplomacy")
	var found_window := false
	for child in game.get_children():
		if child is ConfirmationDialog and child.title == "Diplomacia entre aldeias":
			found_window = true
			child.hide()
	_check(found_window, "Janela de diplomacia abre com controles reais")
	game.call("_show_options")
	var options_found := false
	for child in game.get_children():
		if child is PopupMenu:
			options_found = true
	_check(options_found, "Menu de opcoes acessivel ao jogador")
	_check(game.update_manager._manifest_url == "https://raw.githubusercontent.com/contateste123455667788994321-max/legados-das-eras/main/manifest.json", "Atualizador usa canal HTTPS oficial")
	_check(game.update_manager._is_https(game.update_manager._manifest_url), "Canal de atualizacao tem endereco seguro")
	_check(game.update_manager._base_version_code == 4, "APK base suporta futuros pacotes internos")
	var update_button_found := false
	for child in game.get_children():
		if child is Button and child.text == "Atualizar":
			update_button_found = true
	_check(update_button_found, "Botao Atualizar acessivel diretamente no jogo")

	# Valida o fluxo real do atualizador ZIP -> PCK, sem rede e sem trocar o APK.
	var updates_dir := ProjectSettings.globalize_path("user://updates")
	_check(DirAccess.make_dir_recursive_absolute(updates_dir) == OK, "Pasta para atualizacoes disponivel")
	var downloaded_zip := "user://updates/download.bin"
	var writer := ZIPPacker.new()
	var open_result: Error = writer.open(downloaded_zip)
	_check(open_result == OK, "Criar pacote ZIP de teste")
	if open_result == OK:
		var zip_entry := "Legado-das-Eras-conteudo.pck"
		_check(writer.start_file(zip_entry) == OK, "Criar entrada PCK no ZIP")
		var stub := "PACOTE-DE-TESTE-LEGADO".to_utf8_buffer()
		_check(writer.write_file(stub) == OK, "Gravar conteudo do ZIP")
		writer.close_file()
		writer.close()
		var size_file := FileAccess.open(downloaded_zip, FileAccess.READ)
		var compressed_size: int = size_file.get_length()
		size_file.close()
		game.update_manager._next_patch = {
			"pack_format": "zip",
			"pack_sha256": FileAccess.get_sha256(downloaded_zip),
			"pack_pck_sha256": "",
			"pack_bytes": compressed_size,
			"version_code": 5,
			"version_name": "0.5.0-teste",
			"min_apk_code": 4
		}
		game.update_manager._on_patch_received(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray())
		var local_pack := "user://updates/active.pck"
		_check(FileAccess.file_exists(local_pack), "ZIP extraido e ativado dentro do jogo")
		_check(game.update_manager._restart_requested,"Atualizacao solicita reinicio automatico apos ativacao")
		_check(game.update_restarting,"Mundo salvo e simulacao parada antes do reinicio")
		game.cancel_update_restart()
		var installed_meta := FileAccess.get_file_as_string("user://updates/active.json")
		var parsed = JSON.parse_string(installed_meta)
		_check(typeof(parsed) == TYPE_DICTIONARY and int(parsed.get("version_code", 0)) == 5, "Atualizacao interna registra versao instalada")
		_check(typeof(parsed) == TYPE_DICTIONARY and str(parsed.get("sha256", "")) == FileAccess.get_sha256(local_pack), "Pacote interno recebe hash correto")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(local_pack))
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://updates/active.json"))

	game.queue_free()

	if failures == 0:
		print("SUCESSO: todos os testes basicos passaram.")
	else:
		push_error(str(failures) + " testes falharam.")
	quit(0 if failures == 0 else 1)
