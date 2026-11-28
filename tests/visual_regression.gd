extends SceneTree
# Capturas reais do renderizador Godot, com cenarios de teste controlados.
# Nao altera saves de usuarios: executado apenas em ambiente de CI.
const Main=preload("res://scripts/main.gd")
const World=preload("res://scripts/world.gd")
var game:Node2D
var failures:int=0

func _initialize() -> void:
	call_deferred("_run")

func _capture(name:String,point:Vector2,scale:float) -> void:
	game.zoom=scale
	game._focus_at(point)
	game._refresh_ui()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var img:Image=root.get_texture().get_image()
	if img==null or img.is_empty():
		failures+=1
		push_error("Captura vazia: "+name)
		return
	var path:String="res://visuals/"+name+".png"
	if img.save_png(path)!=OK:
		failures+=1
		push_error("Nao foi possivel salvar "+path)
	else: print("CAPTURA REAL: "+path)

func _run() -> void:
	root.size=Vector2i(1536,864)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://visuals"))
	game=Main.new()
	root.add_child(game)
	await process_frame
	game._enter_world()
	game.set_process(false)
	game.world=World.new()
	game.world.generate_world()
	var w=game.world
	w.save_path="user://visual_test_only.json"
	w.speed=0.0
	w.rng.seed=44712
	w.day=15.0
	w.trees.clear()
	w.wildlife.clear()
	w.beasts.clear()
	w.ancestrals.clear()
	w.swamp_witch.clear()
	w.swamp_spiders.clear()
	for y in range(World.SIZE):
		for x in range(World.WIDTH):
			w.tiles[y][x]="grass" if x<23 else ("snow" if x<31 else ("swamp" if x<38 else "sand"))
	w.river_centers=[12,30]
	w.river_phase=0.0
	w._connect_rivers()
	for i in range(w.towns.size()):
		var town:Dictionary=w.towns[i]
		town["x"]=[6,19,40][i%3]
		town["y"]=7
		town["home_biome"]="grass" if i<2 else "sand"
		town["houses"]=4
		town["house_levels"]=[1,2,1,2]
		town["farms"]=2
		town["campfire"]=true
		town["castle"]=true
		town["castle_level"]=i%3+1
		for person in w.people:
			if int(person["town"])!=int(town["id"]): continue
			person["x"]=float(town["x"])+float(int(person["id"])%3-1)*0.7
			person["y"]=float(town["y"])+1.8+float(int(person["id"])%2)*0.5
	w._prepare_sites()
	for x in [3,5,8,14,16,21,24,27,29,33,36]:
		for y in [3,12]:
			if str(w.tiles[y][x])!="water":
				w._plant_tree(x,y,true)
	w._rebuild_border_cells()
	game.landscape_texture=null
	w.news="Teste visual - construcoes e fronteiras"
	await _capture("01-vila-tribal",Vector2(7,7),2.1)
	await _capture("02-vila-castelo-nivel2",Vector2(19,7),2.1)
	await _capture("03-vila-deserto-nivel3",Vector2(40,7),2.1)
	for site in w.sites:
		if str(site["kind"])=="waterfall":
			w.news="Teste visual - cachoeira"
			await _capture("04-cachoeira",Vector2(float(site["x"])+0.5,float(site["y"])+1.5),3.0)
			break
	# Verifica o mesmo atlas em repouso e movimento, usando a cena real.
	w.towns.clear()
	w.people.clear()
	w.sites.clear()
	w.border_cells.clear()
	w.trees.clear()
	for y in range(1,18):
		for x in range(1,23): w.tiles[y][x]="grass"
	game.landscape_texture=null
	for i in range(Main.ANIMAL_ROWS.size()):
		var species:String=Main.ANIMAL_ROWS[i]
		var p:=Vector2(3.0+float(i%7)*2.1,4.0+float(i/7)*1.75)
		if not w.spawn_creature(species,p):
			failures+=1
			push_error("Falha ao criar "+species)
	for animal in w.wildlife:
		game.visual_motion[int(animal["id"])]={"moving":false,"phase":0.0,"face":1.0}
	for animal in w.beasts:
		game.visual_motion[int(animal["id"])]={"moving":false,"phase":0.0,"face":1.0}
	w.news="Teste visual - fauna em repouso"
	await _capture("05-fauna-parada",Vector2(10,7.5),1.45)
	w.speed=1.0
	for group in [w.wildlife,w.beasts]:
		for animal in group:
			game.visual_motion[int(animal["id"])]={"moving":true,"phase":PI/2.0,"face":1.0}
	w.news="Teste visual - fauna usando quadro de caminhada"
	await _capture("06-fauna-andando",Vector2(10,7.5),1.45)
	w.wildlife.clear()
	w.beasts.clear()
	w.speed=0.0
	w.spawn_creature("witch",Vector2(6.5,7))
	w.spawn_creature("golem",Vector2(9.5,7))
	w.spawn_creature("fenrir",Vector2(12.5,7))
	for i in range(3):
		w.swamp_spiders.append({"id":w.new_id(),"x":5.4+float(i)*1.0,"y":7.8,"emerge":0.0,"health":50.0})
	w.news="Teste visual - ancestrais, bruxa e aranhas"
	await _capture("07-ancestrais",Vector2(9.5,7),2.7)
	print("Capturas de renderizador concluidas: ",failures)
	quit(0 if failures==0 else 1)
