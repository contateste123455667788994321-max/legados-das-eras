extends Node2D
## Legado das Eras — tela jogavel. A simulacao permanece em world.gd.
const World = preload("res://scripts/world.gd")
const ActorCard = preload("res://scripts/actor_card.gd")
const Updates = preload("res://scripts/update_manager.gd")
const GameAudio = preload("res://scripts/game_audio.gd")
const CAMPFIRE_FRAMES := preload("res://assets/landscape/fogueira_do_vale.png")
const TILE_SIZE := 44.0
const MAP_ORIGIN := Vector2(15.0, 79.0)
var MAP_AREA := Rect2(12.0, 78.0, 1256.0, 626.0)
var screen_width:float=1280.0
var right_hud:Array[Control]=[]
var scene_depth:Array=[]
const AUTOSAVE_SECONDS := 20.0

var world = World.new()
var soundscape:Node
var selected_person_id := 0
var selected_beast_id := 0
var selected_town_id := 0
var controlled_id := 0
var map_offset := Vector2.ZERO
var zoom := 1.05
var visual_motion:Dictionary={}
var update_restarting:bool=false
var update_previous_speed:float=1.0
var home_open:bool=false
var home_panel:Control
var home_art: TextureRect
const HOME_ART_PATH := "res://assets/landscape/legado_das_eras_vale_dourado.png"
const HOME_ART_SIZE := Vector2(1280, 720)
const HOME_BUTTON_SIZE := Vector2(348, 58)
const HOME_BUTTON_TOPS := [270, 338, 407]
var home_buttons:Array[Button]=[]
var title_font:SystemFont
const ANIMAL_ROWS:Array[String]=["chicken","deer","rabbit","frog","capybara","heron","camel","lizard","snow_hare","crocodile","turtle","duck","boar","fox","wolf","bear","cow","sheep","goat","horse","pig","dog","cat","eagle","owl","crow","bat","penguin"]
var game_hud:Array[Control]=[]
var startup_speed:float=1.0
const WORLDS_DIR:String="user://worlds"
const MENU_CONFIG:String="user://menu.cfg"
const LEGACY_WORLD:String="user://world.json"
var people_variants:Array[Texture2D]=[]
var landscape_texture: ImageTexture
var landscape_signature := 0
var landscape_objects: Dictionary = {}
var dragging := false
var drag_started := Vector2.ZERO
var active_touches: Dictionary = {}
var pinch_active := false
var pinch_distance := 0.0
var pinch_midpoint := Vector2.ZERO
var drag_touch_id := -1
var resume_speed := 1.0
var autosave_timer := 0.0
var ui_timer := 0.0
var last_news := ""
var tile_textures: Dictionary = {}
var actor_textures: Dictionary = {}
var texture_missing := false
var update_manager: Node
var viewport_3d: SubViewport
var character_world
var character_view := false
var look_yaw := 0.0
var look_pitch := 0.0
var joystick_touch := -1
var look_touch := -1
var joystick_center := Vector2.ZERO
var joystick_direction := Vector2.ZERO
var spawn_species:String=""
var spawn_button:Button
var view_button: Button
var action_button: Button
var inventory_button: Button

var actor_card: ActorCard
var info_label: Label
var stats_label: Label
var news_label: Label
var pause_button: Button
var speed_button: Button
var control_button: Button
var war_button: Button
var rival_button: Button
var predator_button: Button

func _ready() -> void:
	get_viewport().set_input_as_handled()
	var preferences:=ConfigFile.new()
	preferences.load(MENU_CONFIG)
	startup_speed=clampf(float(preferences.get_value("game","startup_speed",1.0)),0.5,4.0)
	if DisplayServer.get_name()!="headless":
		var path:String=str(preferences.get_value("game","last_world",LEGACY_WORLD))
		if _valid_world_path(path): world.save_path=path
	if not world.load_world():
		world.generate_world()
	world.speed = startup_speed
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	_load_art()
	soundscape=GameAudio.new()
	add_child(soundscape)
	update_manager = Updates.new()
	add_child(update_manager)
	_build_ui()
	for child in get_children():
		if child is Control: game_hud.append(child)
	get_window().content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	get_viewport().size_changed.connect(_resize_map)
	_resize_map()
	if not world.towns.is_empty():
		var first_town: Dictionary = world.towns[0]
		_focus_at(Vector2(float(first_town["x"]) + 0.5, float(first_town["y"]) + 0.5))
	_refresh_ui()
	if DisplayServer.get_name()!="headless": _open_home(false)
	queue_redraw()

func _process(delta: float) -> void:
	if update_restarting or home_open: return
	_move_controlled(delta)
	world.update_world(delta, controlled_id)
	_track_visual_motion(delta)
	if is_instance_valid(soundscape): soundscape.update_audio(world,_screen_to_world(MAP_AREA.get_center())-Vector2(0.5,0.5),MAP_AREA.size/(TILE_SIZE*zoom),delta)
	autosave_timer += delta
	ui_timer += delta
	if autosave_timer >= AUTOSAVE_SECONDS:
		world.save_world()
		autosave_timer = 0.0
	if ui_timer >= 0.30 or last_news != world.news:
		ui_timer = 0.0
		_refresh_ui()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if world != null and not world.tiles.is_empty() and not home_open:
			world.save_world()

func _load_art() -> void:
	for tile in ["grass", "water", "sand", "forest", "snow", "mountain", "grass_autumn", "forest_autumn", "grass_spring"]:
		var texture: Resource = load("res://assets/terrain/" + tile + ".svg")
		if texture is Texture2D:
			tile_textures[tile] = texture
		else:
			texture_missing = true
	for actor in ["hut", "farm", "fire", "person_m", "person_f", "child", "wolf", "bear"]:
		var texture: Resource = load("res://assets/sprites/" + actor + ".svg")
		if texture is Texture2D:
			actor_textures[actor] = texture
		else:
			texture_missing = true
	actor_textures["tribal_hut"]=actor_textures["hut"]
	for key in ["hut","farm"]:
		var new_art: Resource = load("res://assets/landscape/reference_"+key+".png")
		if new_art is Texture2D: actor_textures[key] = new_art
	landscape_objects["mine"] = preload("res://assets/landscape/mina_do_vale.png")
	landscape_objects["forge"] = preload("res://assets/landscape/forja_do_vale.png")
	landscape_objects["tree"] = preload("res://assets/landscape/arvore_aprovada.png")
	landscape_objects["pine"] = preload("res://assets/landscape/pinheiro_aprovado.png")
	landscape_objects["pine_snow"] = preload("res://assets/landscape/pinheiro_neve_aprovado.png")
	landscape_objects["tree_snow"] = landscape_objects["pine_snow"]
	landscape_objects["rock"] = preload("res://assets/landscape/rocha_aprovada.png")
	landscape_objects["flowers_approved"] = preload("res://assets/landscape/flores_aprovadas.png")
	landscape_objects["reference_characters"] = load("res://assets/landscape/reference_characters.png")
	landscape_objects["habitantes"] = preload("res://assets/landscape/habitantes.png")
	if texture_missing:
		push_warning("Alguns desenhos do mapa ainda nao foram carregados.")

func _build_ui() -> void:
	# Um unico mapa imersivo; todas as mecanicas ficam no menu do mundo.
	_label("LEGADO DAS ERAS", Vector2(22, 7), Vector2(260, 40), 25, Color("#f4d48b"))
	stats_label = _label("", Vector2(277, 14), Vector2(382, 27), 16, Color("#ecdec1"))
	news_label = _label("", Vector2(22, 48), Vector2(650, 24), 15, Color("#edd0a0"))
	news_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	speed_button = _button("1x", Vector2(737, 15), Vector2(72, 38), Callable(self, "_change_speed"))
	pause_button = _button("Pausar", Vector2(813, 15), Vector2(82, 38), Callable(self, "_toggle_pause"))
	spawn_button = _button("Criar", Vector2(899, 15), Vector2(112, 38), Callable(self, "_toggle_spawn"))
	view_button = _button("Controlar", Vector2(1015, 15), Vector2(100, 38), Callable(self, "_toggle_view"))
	var menu:Button=_button("Mundo", Vector2(1119, 15), Vector2(73, 38), Callable(self, "_show_options"))
	var update:Button=_button("Atualizar", Vector2(1196, 15), Vector2(80, 38), Callable(self, "_check_updates"))
	right_hud=[speed_button,pause_button,spawn_button,view_button,menu,update]
	info_label = _label("", Vector2(32, 660), Vector2(1150, 26), 16, Color("#fff0bb"))
	info_label.visible = false
	action_button = _button("Coletar", Vector2(1104, 590), Vector2(143, 52), Callable(self, "_character_action"))
	inventory_button = _button("Inventario", Vector2(929, 590), Vector2(166, 52), Callable(self, "_show_inventory"))
	action_button.visible = false
	inventory_button.visible = false

func _add_biome_touch(kind: String, pos: Vector2) -> void:
	var btn := Button.new()
	btn.text = ""
	btn.flat = true
	btn.position = pos
	btn.size = Vector2(86, 75)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	btn.pressed.connect(func() -> void: _focus_biome(kind))
	add_child(btn)

func _label(value: String, pos: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = value
	l.position = pos
	l.size = dimensions
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _button(value: String, pos: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var b := Button.new()
	b.text = value
	b.position = pos
	b.size = dimensions
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color("#f0f5f2"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#493b2a")
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.border_width_bottom = 2
	style.border_color = Color("#a78656")
	b.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color("#6a4e2c")
	b.add_theme_stylebox_override("hover", hover)
	var pressed_style := style.duplicate()
	pressed_style.bg_color = Color("#2a2118")
	b.add_theme_stylebox_override("pressed", pressed_style)
	b.pressed.connect(func() -> void:
		if is_instance_valid(soundscape): soundscape.play_ui()
	)
	b.pressed.connect(callback)
	add_child(b)
	return b

func _refresh_ui() -> void:
	if is_instance_valid(actor_card) and not actor_card.is_queued_for_deletion():
		actor_card.refresh()
	var years := int(world.day / 365.0)
	var day_of_year := int(world.day) % 365 + 1
	var living := 0
	for p in world.people:
		if bool(p["alive"]):
			living += 1
	stats_label.text = "Ano %d · Dia %d · %s · %d moradores" % [years + 1, day_of_year, _season_name(), living]
	last_news = world.news
	news_label.text = world.news if spawn_species.is_empty() else str(World.SPAWN_NAMES.get(spawn_species,""))+" | Toque no mapa para criar. "+world.news
	if is_instance_valid(spawn_button): spawn_button.text="Criar" if spawn_species.is_empty() else "Sair criacao"
	pause_button.text = "Retomar" if world.speed == 0.0 else "Pausar"
	var display_speed: float = resume_speed if world.speed == 0.0 else world.speed
	speed_button.text = "0.5x" if display_speed == 0.5 else "%.0fx" % display_speed

	if is_instance_valid(view_button):
		view_button.text = "Soltar" if controlled_id > 0 else "Controlar"
	info_label.visible = selected_person_id > 0 or selected_beast_id > 0 or selected_town_id > 0
	if selected_beast_id > 0:
		var beast: Dictionary = world.get_beast(selected_beast_id)
		if not beast.is_empty():
			info_label.text = "%s  |  %s  |  Vida: %d   (Mundo > Ficha)" % [str(beast["name"]), str(beast["species"]), int(float(beast["health"]))]
			return
	if selected_person_id > 0:
		var p: Dictionary = world.get_person(selected_person_id)
		if not p.is_empty():
			var birthplace: Dictionary = world.get_town(int(p["town"]))
			var home := str(birthplace.get("name", "Sem aldeia"))
			var state := "vivo" if bool(p["alive"]) else "falecido"
			var father: Dictionary = world.get_person(int(p["father"]))
			var mother: Dictionary = world.get_person(int(p["mother"]))
			var family := ""
			if not father.is_empty() or not mother.is_empty():
				family = " | Familia: %s / %s" % [str(father.get("name", "?")), str(mother.get("name", "?"))]
			var profession := str(p.get("profession", "Ainda sem profissao"))
			var memories: Array = p.get("memories", [])
			var latest_event := "Nenhuma lembranca registrada"
			if not memories.is_empty():
				latest_event = str(memories.back().get("event", latest_event))
			info_label.text = "%s • %d anos  |  %s • %s  |  %s" % [str(p["name"]), int(float(p["age"])), home, profession, str(p.get("task", "Observando"))]
			return
	if selected_town_id > 0:
		var t: Dictionary = world.get_town(selected_town_id)
		if not t.is_empty():
			var ruler: Dictionary = world.get_person(int(t["leader"]))
			var building: String = str(t.get("construction", {}).get("kind", ""))
			var status: String = " | Obra" if not building.is_empty() else ""
			info_label.text = "%s • Era %d • %d pessoas  |  Casas %d  |  Fazendas %d%s  |  Comida %d  |  Madeira %d" % [str(t["name"]), int(t["level"]), world.active_population(int(t["id"])), int(t.get("houses", 2)), int(t.get("farms", 1)), status, int(float(t["food"])), int(float(t["wood"]))]
			return
	info_label.text = ""

func _season_name() -> String:
	var index := int(world.day / 90.0) % 4
	return ["Primavera", "Verao", "Outono", "Inverno"][index]

func _terrain_type(tile: String) -> String:
	var season := int(world.day / 90.0) % 4
	if season == 2 and tile == "grass":
		return "grass_autumn"
	if season == 2 and tile == "forest":
		return "forest_autumn"
	if season == 0 and tile == "grass":
		return "grass_spring"
	if season == 3 and tile == "grass":
		return "snow"
	return tile

func _draw_sprite(key: String, center: Vector2, dimensions: Vector2, clip_to_map: bool = false) -> void:
	if not actor_textures.has(key):
		return
	var texture: Texture2D = actor_textures[key]
	var dest := Rect2(center - dimensions * 0.5, dimensions)
	if clip_to_map:
		var clipped: Rect2 = dest.intersection(MAP_AREA)
		if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
			return
		var source := Rect2((clipped.position - dest.position) / dest.size * texture.get_size(), clipped.size / dest.size * texture.get_size())
		draw_texture_rect_region(texture, clipped, source)
	else:
		draw_texture_rect(texture, dest, false)


func _landscape_color(kind: String, season: int) -> Color:
	match kind:
		"water": return Color("#247e9b")
		"swamp": return Color("#536e47")
		"sand": return Color("#cdb17a")
		"snow": return Color("#cedddf")
		"mountain": return Color("#777e71")
		"forest":
			return Color("#496c35") if season != 3 else Color("#a7b9b3")
		_:
			if season == 2: return Color("#a89b4d")
			if season == 3: return Color("#c6d6d0")
			return Color("#78a34a")

func _make_landscape() -> void:
	var season: int = int(world.day / 90.0) % 4
	var signature: int = hash([world.tiles, season])
	if landscape_texture != null and signature == landscape_signature:
		return
	landscape_signature = signature
	const DETAIL := 24
	var img := Image.create(World.WIDTH * DETAIL, World.SIZE * DETAIL, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 527
	noise.frequency = 0.039
	for py in range(img.get_height()):
		for px in range(img.get_width()):
			var fx: float = float(px) / DETAIL - 0.5 + noise.get_noise_2d(px, py) * 0.65
			var fy: float = float(py) / DETAIL - 0.5 + noise.get_noise_2d(px + 431, py + 217) * 0.65
			var x0: int = clampi(floori(fx), 0, World.WIDTH - 1)
			var y0: int = clampi(floori(fy), 0, World.SIZE - 1)
			var x1: int = clampi(floori(fx) + 1, 0, World.WIDTH - 1)
			var y1: int = clampi(floori(fy) + 1, 0, World.SIZE - 1)
			var tx: float = smoothstep(0.12, 0.88, fposmod(fx, 1.0))
			var ty: float = smoothstep(0.12, 0.88, fposmod(fy, 1.0))
			var a: Color = _landscape_color(str(world.tiles[y0][x0]), season)
			var b: Color = _landscape_color(str(world.tiles[y0][x1]), season)
			var d: Color = _landscape_color(str(world.tiles[y1][x0]), season)
			var e: Color = _landscape_color(str(world.tiles[y1][x1]), season)
			var col: Color = a if tx<0.5 and ty<0.5 else (b if ty<0.5 else (d if tx<0.5 else e))
			var water: float = lerpf(lerpf(float(str(world.tiles[y0][x0]) == "water"), float(str(world.tiles[y0][x1]) == "water"), tx), lerpf(float(str(world.tiles[y1][x0]) == "water"), float(str(world.tiles[y1][x1]) == "water"), tx), ty)
			var grain: float = float(posmod(px * 79 + py * 131 + px * py * 17, 97)) / 97.0
			var shade:float=roundf((noise.get_noise_2d(px,py)*0.26+(grain-0.5)*0.075)*22.0)/22.0
			var wetland:bool=str(world.tiles[y0][x0])=="swamp" or str(world.tiles[y0][x1])=="swamp" or str(world.tiles[y1][x0])=="swamp" or str(world.tiles[y1][x1])=="swamp"
			var wet:float=noise.get_noise_2d(px*0.48+803,py*0.48+301)
			if col==Color("#536e47"):
				col=Color("#393b38").lerp(Color("#525142"),clampf(wet+0.45,0.0,1.0))
				if wet>0.04: col=Color("#3c5145").lerp(Color("#263c3c"),clampf(wet*1.7,0.0,1.0))
			if water > 0.46:
				var depth:float=smoothstep(0.54,0.98,water)
				col = Color("#426858").lerp(Color("#102d2b"),depth) if wetland else Color("#58b8bc").lerp(Color("#104567"),depth)
				col=col.lerp(Color("#26778f") if not wetland else Color("#3d7660"),clampf((grain-0.35)*0.13,0.0,0.10))
				if water < 0.60: col = Color("#597768") if wetland else Color("#8dd1cd")
				elif grain > 0.89 and py % 5 == 0: col = col.lightened(0.20)
			elif water > 0.28:
				col = Color("#706342") if wetland else (Color("#b8cfd4") if season==3 else Color("#b6a274"))
			col = col.lightened(shade) if shade > 0.0 else col.darkened(-shade)
			img.set_pixel(px, py, col)
	landscape_texture = ImageTexture.create_from_image(img)
	landscape_render_image=img
	waterfall_cache.clear()

func _draw_landscape() -> void:
	_make_landscape()
	var side: float = TILE_SIZE * zoom
	var dest := Rect2(_world_to_screen(Vector2.ZERO), Vector2(World.WIDTH,World.SIZE) * side)
	var clipped: Rect2 = dest.intersection(MAP_AREA)
	if clipped.has_area():
		var source := Rect2((clipped.position-dest.position)/dest.size*landscape_texture.get_size(), clipped.size/dest.size*landscape_texture.get_size())
		draw_texture_rect_region(landscape_texture, clipped, source)
	for y in range(World.SIZE):
		for x in range(World.WIDTH):
			var kind: String = str(world.tiles[y][x])
			var seed: int = posmod(x*7919+y*104729+x*y*71, 997)
			var pos: Vector2 = _world_to_screen(Vector2(x + 0.25 + float(seed % 13)*0.04, y + 0.35 + float(seed % 9)*0.045))
			if not MAP_AREA.grow(-side*0.45).has_point(pos): continue
			var near_house := false
			for town in world.towns:
				if Vector2(x,y).distance_to(Vector2(float(town["x"]),float(town["y"]))) < 2.8:
					near_house = true
					break
			if near_house and kind!="water": continue
			if kind == "water":
				var phase: float = fposmod(float(Time.get_ticks_msec())*0.00016+float(seed)*0.017,1.0)
				var wave: Vector2 = pos+Vector2((phase-0.5)*side*0.38,side*0.04)
				if MAP_AREA.grow(-side*0.2).has_point(wave):
					draw_rect(Rect2(wave,Vector2(side*0.12,maxf(1,side*0.018))),Color("#94e4eb",0.66))
			elif kind == "grass" or kind == "forest":
				_draw_ground_details(kind,pos,side,seed)
				for n in range(5):
					var k: int = posmod(seed*31+n*127,997)
					var q: Vector2 = pos+Vector2(float(k%23)/23.0-0.5,float(k%17)/17.0-0.5)*side*0.85
					if not MAP_AREA.grow(-side*0.08).has_point(q): continue
					var ss: float = maxf(1.0,side*0.026)
					draw_rect(Rect2(q,Vector2(ss,ss*2)),Color("#496c2c"))
					draw_rect(Rect2(q+Vector2(ss,ss),Vector2(ss,ss)),Color("#91a94e"))
					if k%7==0: draw_rect(Rect2(q-Vector2(0,ss),Vector2(ss,ss)),Color("#ead0a5"))
			elif kind == "swamp":
				# Brejo limpo: apenas juncos grandes nas margens, sem folhinhas soltas.
				if seed%9==0 and world.water_depth(Vector2(x,y)+Vector2(0.45,0.0))>0.0:
					_draw_landscape_object("swamp_reeds",pos,side*0.82)
				if seed%13==0: _draw_mosquitoes(pos,seed,side)
			elif kind == "mountain":
				if seed%3!=0: _draw_landscape_object("rock", pos, side*(0.7+float(seed%5)*0.14))
			elif kind == "sand":
				_draw_ground_details(kind,pos,side,seed)
				if seed%4==0: _draw_landscape_object("cactus",pos,side*0.66)
			elif kind == "snow":
				_draw_ground_details(kind,pos,side,seed)

	for tree in world.trees.values():
		var p: Vector2 = _world_to_screen(Vector2(float(tree["x"])+0.5+float(tree["ox"]),float(tree["y"])+0.5+float(tree["oy"])))
		if not MAP_AREA.grow(-side*0.3).has_point(p): continue
		var s: float = side*(1.78 if world.swamp_at(Vector2(float(tree["x"]),float(tree["y"]))) else 1.22)*world.tree_scale(tree)
		var tree_key:String=_natural_tree_key(tree)
		var state: String = str(tree["state"])
		if state == "stump":
			draw_ellipse_stump(p,s)
		elif state == "falling":
			var key: String = tree_key
			if not landscape_objects.has(key):
				landscape_objects[key] = load("res://assets/landscape/"+key+".svg")
			if landscape_objects.get(key) is Texture2D and MAP_AREA.grow(-s*1.2).has_point(p):
				draw_set_transform(p,float(tree["fall"])*PI*0.5)
				draw_texture_rect(landscape_objects[key],Rect2(-s*0.5,-s*0.85,s,s),false)
				draw_set_transform(Vector2.ZERO)
			draw_ellipse_stump(p,s)
		else:
			# Arvores e personagens compartilham a mesma ordenacao pela base.
			var variation:float=0.91+float(posmod(int(tree["x"])*19+int(tree["y"])*13,9))*0.025
			scene_depth.append({"y":p.y,"kind":"tree","p":p,"size":s*variation,"key":tree_key})

# Decoracao pequena e deterministica: sem entidades, colisao, coleta ou alteracao de saves.
# Um atlas estatico e no maximo dois desenhos por terreno visivel.
func _draw_ground_details(kind:String,p:Vector2,side:float,seed:int) -> void:
	if seed%3==0: return
	if kind in ["grass","forest"] and seed%7 in [0,1,2]:
		_draw_landscape_object("flowers_approved",p+Vector2(-0.13,0.19)*side,side*0.40)
		return
	if kind in ["grass","forest","mountain"] and seed%7==3:
		_draw_landscape_object("rock",p+Vector2(0.12,0.15)*side,side*0.28)
		return
	if not landscape_objects.has("ground_details"):
		landscape_objects["ground_details"]=preload("res://assets/landscape/ground_details.svg")
	var atlas:Texture2D=landscape_objects["ground_details"]
	var index:int=0
	match kind:
		"grass": index=[0,1,2,3,4,5,6][seed%7]
		"forest": index=[1,3,4,5,6,7,8][seed%7]
		"swamp": index=[7,8,9,10][seed%4]
		"sand": index=[11,12,13][seed%3]
		"snow": index=[14,15,16][seed%3]
		_: return
	var size:float=side*(0.23+float(seed%5)*0.035)
	var anchor:=p+Vector2(-0.25+float(seed%4)*0.12,0.18)*side
	var dest:=Rect2(anchor-Vector2.ONE*size*0.5,Vector2.ONE*size)
	if MAP_AREA.encloses(dest):
		draw_texture_rect_region(atlas,dest,Rect2(index*24,0,24,24))
	if kind in ["grass","forest"] and seed%5==1:
		var extra:=Rect2(p+Vector2(0.16,-0.24)*side,Vector2.ONE*side*0.22)
		if MAP_AREA.encloses(extra):
			draw_texture_rect_region(atlas,extra,Rect2(3*24,0,24,24))

func draw_ellipse_stump(p:Vector2,s:float) -> void:
	_draw_landscape_object("stump_detailed",p,s*0.47)


func _draw_landscape_object(key: String, p: Vector2, size: float) -> void:
	if not landscape_objects.has(key):
		var tex: Resource = load("res://assets/landscape/" + key + ".svg")
		if tex is Texture2D: landscape_objects[key] = tex
		else: return
	var texture: Texture2D = landscape_objects[key]
	var dest := Rect2(p-Vector2(size*0.5,size*0.85), Vector2(size,size))
	var clipped: Rect2 = dest.intersection(MAP_AREA)
	if clipped.has_area():
		draw_texture_rect_region(texture, clipped, Rect2((clipped.position-dest.position)/dest.size*texture.get_size(),clipped.size/dest.size*texture.get_size()))


func _draw() -> void:
	if home_open:
		_draw_home_art()
		return
	# Interface discreta: mapa em quase toda a area util do aparelho.
	draw_rect(Rect2(0, 0, screen_width, 720), Color("#141e1a"), true)
	draw_rect(Rect2(0, 0, screen_width, 75), Color("#211e19"), true)
	draw_line(Vector2(0, 74), Vector2(screen_width, 74), Color("#ae8c54"), 2.0)
	_draw_clock()
	draw_rect(MAP_AREA, Color("#355943"), true)
	scene_depth.clear()
	_draw_landscape()
	_draw_water_reflections()
	_draw_rivers()
	_draw_territory_borders()
	# Caminhos sao camada de solo: nunca pintar sobre castelos, oficinas ou personagens.
	for town in world.towns:
		var origin:Vector2=_world_to_screen(Vector2(float(town["x"])+0.5,float(town["y"])+0.5))
		_draw_village_ground(town,origin,TILE_SIZE*zoom)
		_draw_village_paths(town,origin,TILE_SIZE*zoom,world.house_layout(town),world.farm_layout(town))
	_draw_world_sites()
	# Quantidade real de casas e fazendas aparece no mapa, conforme o estoque da vila.
	for town in world.towns:
		var house_spots:Array[Vector2]=world.house_layout(town)
		var farm_spots:Array[Vector2]=world.farm_layout(town)
		var center := _world_to_screen(Vector2(float(town["x"]) + 0.5, float(town["y"]) + 0.5))
		if not MAP_AREA.grow(140.0).has_point(center):
			continue
		var unit := TILE_SIZE * zoom
		for segment in town.get("palisades",[]):
			var fence_pos:Vector2=_world_to_screen(Vector2(float(segment["x"])+0.5,float(segment["y"])+0.5))
			_draw_palisade(fence_pos,unit,str(segment.get("axis","h")),segment)
		# A terra cultivada cresce quando uma fazenda fica pronta.
		for i in range(mini(int(town.get("farms", 1)), farm_spots.size())):
			var spot: Vector2 = farm_spots[i]
			_draw_sprite("farm", center + spot * unit, Vector2(1.45, 0.96) * unit, true)
		for i in range(mini(int(town.get("houses", 2)), house_spots.size())):
			var spot: Vector2 = house_spots[i]
			var house_size: float = 1.75 if i == 0 else 1.48
			var era: int = clampi(int(world.house_levels(town)[i]), 1, 4)
			var house_center:Vector2=center+spot*unit
			scene_depth.append({"y":house_center.y+house_size*unit*0.30,"kind":"house","p":house_center,"size":house_size*unit,"era":era,"biome":str(town.get("home_biome","grass"))})
		var site: Dictionary = town.get("construction", {})
		if not site.is_empty() and MAP_AREA.grow(-35.0).has_point(center):
			var kind: String = str(site.get("kind", "house"))
			var build_spot: Vector2 = house_spots[mini(int(town.get("houses", 2)), house_spots.size()-1)] if kind == "house" else farm_spots[mini(int(town.get("farms", 1)), farm_spots.size()-1)]
			var scaffold: Vector2 = _world_to_screen(Vector2(float(site["x"])+0.5,float(site["y"])+0.5)) if site.has("x") else center + build_spot * unit
			if MAP_AREA.grow(-unit).has_point(scaffold):
				_draw_landscape_object("construction_site",scaffold,unit*0.85)
				_draw_project_marker(site,scaffold,unit)
		if int(town["id"]) == selected_town_id and MAP_AREA.has_point(center):
			draw_arc(center, 35.0 * zoom, 0.0, TAU, 32, Color("#fff0a0"), 3.0)
	for animal in world.wildlife:
		if float(animal.get("health",1))<=0: continue
		var p: Vector2 = _world_to_screen(Vector2(float(animal["x"])+0.5,float(animal["y"])+0.5))
		scene_depth.append({"y":p.y if float(animal.get("flight_height",0))<=0.1 else 100000.0,"kind":"animal","p":p,"actor":animal})
	_draw_resource_drops()
	# Personagens separados visualmente por idade e aparencia.
	for p in world.people:
		if not bool(p["alive"]) and world.swamp_clock >= float(p.get("fell_at", -2.0)) + 1.4:
			continue
		var center := _world_to_screen(Vector2(float(p["x"]) + 0.5, float(p["y"]) + 0.5))
		if not MAP_AREA.has_point(center):
			continue
		scene_depth.append({"y":center.y,"kind":"person","p":center,"actor":p})
		if not bool(p["alive"]):
			continue
		if float(p.get("poison_remaining",0))>0 and MAP_AREA.grow(-12).has_point(center):
			var pulse:float=0.55+0.25*sin(world.swamp_clock*8.0)
			draw_arc(center,10.0*zoom,0,TAU,18,Color(0.48,0.78,0.24,pulse),1.5)
		if int(p["id"]) == selected_person_id:
			draw_arc(center, 14.0 * zoom, 0, TAU, 20, Color("#ffe890"), 2.0)
			var task_name: String = "Nv. %d | %s" % [int(p.get("level",1)),str(p.get("task","Observando"))]
			_draw_selected_life(p,center)
			var tag: Rect2 = Rect2(center + Vector2(-55, -41) * zoom, Vector2(110, 18) * zoom)
			if MAP_AREA.encloses(tag):
				draw_rect(tag, Color("#201f16", 0.92), true)
				draw_rect(tag, Color("#f7d890"), false, 1.0)
				draw_string(ThemeDB.fallback_font, tag.position + Vector2(3.0, 13.0) * zoom, task_name, HORIZONTAL_ALIGNMENT_CENTER, tag.size.x - 6.0, maxi(10, int(11.0 * zoom)), Color("#ffe1a2"))
		if int(p["id"]) == controlled_id:
			draw_arc(center, 18.0 * zoom, 0, TAU, 20, Color("#6cffda"), 3.0)
	for b in world.beasts:
		if not bool(b["alive"]):
			continue
		var center := _world_to_screen(Vector2(float(b["x"]) + 0.5, float(b["y"]) + 0.5))
		if not MAP_AREA.has_point(center):
			continue
		var key := "bear" if str(b["species"]) == "Urso" else "wolf"
		scene_depth.append({"y":center.y,"kind":"beast","p":center,"actor":b,"key":key})
		if int(b["id"]) == selected_beast_id:
			draw_arc(center, 15.0 * zoom, 0, TAU, 20, Color("#ffe890"), 2.0)
		if int(b["id"]) == controlled_id:
			draw_arc(center, 19.0 * zoom, 0, TAU, 20, Color("#6cffda"), 3.0)
	_draw_depth_entities()
	_draw_swamp_creatures()
	_draw_combat_feedback()
	draw_rect(MAP_AREA, Color("#bc985d", 0.70), false, 2.0)
	if info_label != null and info_label.visible:
		draw_rect(Rect2(17, 650, 1207, 41), Color("#172219", 0.86), true)
		draw_rect(Rect2(17, 650, 1207, 41), Color("#d1ab6c"), false, 1.0)

# Base irregular de terra pisada. A textura do bioma permanece visivel entre os pixels.
var foundation_cache:Dictionary={}
func _foundation_texture(biome:String,seed:int) -> Texture2D:
	var variant:int=posmod(seed,4)
	var key:String=biome+":"+str(variant)
	if foundation_cache.has(key): return foundation_cache[key]
	var ground:Color=Color("#ac925a")
	match biome:
		"snow": ground=Color("#a5aba4")
		"sand": ground=Color("#bd9c65")
		"swamp": ground=Color("#5e6242")
	var img:=Image.create(64,24,false,Image.FORMAT_RGBA8)
	for y in range(24):
		for x in range(64):
			var d:=Vector2((float(x)-31.5)/30.0,(float(y)-11.5)/11.0)
			var h:int=posmod(x*71+y*131+variant*29,97)
			var edge:float=1.0+float(h%7-3)*0.055
			if d.length_squared()>edge: continue
			var tone:Color=ground.darkened(float(h%5)*0.045)
			tone.a=0.12+0.27*(1.0-clampf(d.length(),0.0,1.0))
			img.set_pixel(x,y,tone)
	var tex:Texture2D=ImageTexture.create_from_image(img)
	foundation_cache[key]=tex
	return tex

func _draw_structure_ground(p:Vector2,size:float,biome:String,seed:int) -> void:
	if not MAP_AREA.grow(size).has_point(p): return
	var extent:=Vector2(size*0.54,size*0.19)
	# Se a base cruzar a margem, nao cobrir a agua com terra decorativa.
	for offset in [Vector2.ZERO,Vector2(-extent.x,0),Vector2(extent.x,0),Vector2(0,extent.y),Vector2(0,-extent.y)]:
		if world.water_depth(_screen_to_world(p+offset)-Vector2(0.5,0.5))>0.10: return
	var dest:=Rect2(p-extent,extent*2.0)
	var clipped:Rect2=dest.intersection(MAP_AREA)
	if not clipped.has_area(): return
	var tex:Texture2D=_foundation_texture(biome,seed)
	draw_texture_rect_region(tex,clipped,Rect2((clipped.position-dest.position)/dest.size*tex.get_size(),clipped.size/dest.size*tex.get_size()))

func _draw_village_ground(town:Dictionary,center:Vector2,unit:float) -> void:
	if not MAP_AREA.grow(unit*8).has_point(center): return
	var biome:String=str(town.get("home_biome","grass"))
	var houses:Array[Vector2]=world.house_layout(town)
	var castle:int=world.castle_level(town)
	if castle>0:
		var size:float=unit*[1.95,2.48,3.05][castle-1]
		_draw_structure_ground(center+Vector2(0,size*0.10),size,biome,int(town["id"]))
	for i in range(mini(int(town.get("houses",0)),houses.size())):
		var size:float=unit*(1.75 if i==0 else 1.48)*(1.0+float(clampi(int(world.house_levels(town)[i]),1,4)-1)*0.045)
		_draw_structure_ground(center+houses[i]*unit+Vector2(0,size*0.38),size,biome,int(town["id"])*17+i)

# Sombra de contato e ponto de apoio das raizes, sem achatar o desenho.
func _draw_rooted_tree(key:String,p:Vector2,size:float) -> void:
	_contact_shadow(p+Vector2(size*0.035,size*0.08),size*0.26,size*0.085)
	_draw_landscape_object(key,p-Vector2(0,size*0.06),size)

func _draw_village_paths(town:Dictionary,center:Vector2,unit:float,houses:Array[Vector2],farms:Array[Vector2]) -> void:
	if not MAP_AREA.grow(unit*8.0).has_point(center): return
	var house_count:int=mini(int(town.get("houses",0)),houses.size())
	var farm_count:int=mini(int(town.get("farms",0)),farms.size())
	if house_count==0 and farm_count==0: return
	var lane_y:float=2.05
	var left:float=0.0
	var right:float=0.0
	var castle_level:int=world.castle_level(town)
	var castle_size:float=[0.0,1.95,2.48,3.05][clampi(castle_level,0,3)]
	# Footprints correspond to the actual anchored sprites, not their transparent padding.
	var obstacles:Array[Rect2]=[]
	if castle_level>0:
		obstacles.append(Rect2(Vector2(-castle_size*0.49,-castle_size*0.82),Vector2(castle_size*0.98,castle_size*0.96)).grow(0.07))
	for i in range(house_count):
		var house_size:float=(1.75 if i==0 else 1.48)*(1.0+float(clampi(int(world.house_levels(town)[i]),1,4)-1)*0.045)
		obstacles.append(Rect2(houses[i]+Vector2(-house_size*0.44,-house_size*0.55),Vector2(house_size*0.88,house_size*0.95)).grow(0.06))
	for i in range(farm_count):
		obstacles.append(Rect2(farms[i]-Vector2(0.69,0.43),Vector2(1.38,0.86)))
	for i in range(house_count):
		var spot:Vector2=houses[i]
		var route_x:float=spot.x
		# Route rear houses around the keep, not through the castle.
		if castle_level>0 and spot.y<0.0 and absf(route_x)<castle_size*0.5+0.2:
			route_x=(-1.0 if spot.x<0 else 1.0)*(castle_size*0.5+0.25)
		left=minf(left,route_x)
		right=maxf(right,route_x)
		var door:Vector2=spot+Vector2(0,0.65)
		var corner:=Vector2(route_x,door.y)
		_draw_dirt_path(center,door,corner,unit,obstacles)
		_draw_dirt_path(center,corner,Vector2(route_x,lane_y),unit,obstacles)
	for i in range(farm_count):
		var spot:Vector2=farms[i]
		left=minf(left,spot.x)
		right=maxf(right,spot.x)
		_draw_dirt_path(center,Vector2(spot.x,lane_y),spot-Vector2(0,0.55),unit,obstacles)
	_draw_dirt_path(center,Vector2(left,lane_y),Vector2(right,lane_y),unit,obstacles)
	if castle_level>0:
		_draw_dirt_path(center,Vector2(0,castle_size*0.15+0.10),Vector2(0,lane_y),unit,obstacles)

func _draw_dirt_path(center:Vector2,a:Vector2,b:Vector2,unit:float,obstacles:Array[Rect2]) -> void:
	var count:int=maxi(2,ceili(a.distance_to(b)/0.055))
	for i in range(count+1):
		var t:float=float(i)/float(count)
		var local:Vector2=a.lerp(b,t)
		var blocked:bool=false
		for area in obstacles:
			if area.grow(0.08).has_point(local):
				blocked=true
				break
		if blocked: continue
		var p:Vector2=center+local*unit
		var side:float=unit*(0.19+0.025*sin(local.x*7+local.y*9))
		if world.water_depth(_screen_to_world(p)-Vector2(0.5,0.5))>0.0: continue
		if not MAP_AREA.grow(-side).has_point(p): continue
		draw_rect(Rect2(p-Vector2.ONE*side*0.5,Vector2.ONE*side),Color("#8b794e",0.42))
		draw_rect(Rect2(p-Vector2.ONE*side*0.39,Vector2.ONE*side*0.78),Color("#b39a67",0.86))
		if posmod(roundi(local.x*29)+roundi(local.y*23),7)==0:
			draw_rect(Rect2(p,Vector2.ONE*maxf(1,side*0.12)),Color("#d6bc87",0.7))

func _draw_territory_borders() -> void:
	var palette:Array[Color]=[Color("#bbb7a8"),Color("#69cafa"),Color("#f36d68"),Color("#a9cb84"),Color("#b7a2e0"),Color("#e8b183")]
	var cells:Dictionary=world.border_cells
	var grid:float=World.BORDER_GRID
	var edge_width:float=clampf(zoom*1.65,1.4,4.0)
	for key in cells:
		var cell:Vector2i=key
		var town:Dictionary=world.get_town(int(cells[cell]))
		if town.is_empty(): continue
		var realm:int=world.kingdom_id(town)
		var color:Color=palette[posmod(realm,palette.size())]
		var p:Vector2=(Vector2(cell)*grid)+Vector2(0.5,0.5)
		var corners:Array[Vector2]=[p,p+Vector2(grid,0),p+Vector2(grid,grid),p+Vector2(0,grid)]
		var offsets:Array[Vector2i]=[Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]
		for i in range(4):
			var neighbor:Dictionary=world.get_town(int(cells.get(cell+offsets[i],0)))
			if not neighbor.is_empty() and world.kingdom_id(neighbor)==realm: continue
			var start:Vector2=_world_to_screen(corners[i])
			var finish:Vector2=_world_to_screen(corners[(i+1)%4])
			if not MAP_AREA.has_point(start) or not MAP_AREA.has_point(finish): continue
			draw_line(start,finish,Color(color.r,color.g,color.b,0.18),edge_width*3.1)
			draw_line(start,finish,Color("#24312d",0.72),edge_width+1.5)
			draw_line(start,finish,Color(color.r,color.g,color.b,0.94),edge_width)

func _draw_world_sites() -> void:
	var unit:float=TILE_SIZE*zoom
	for site in world.sites:
		var p:Vector2=_world_to_screen(Vector2(float(site["x"])+0.5,float(site["y"])+0.5))
		var kind:String=str(site["kind"])
		if kind=="castle":
			var town:Dictionary=world.get_town(int(site.get("town",0)))
			if not town.is_empty():
				var level:int=world.castle_level(town)
				var size:float=unit*[1.95,2.48,3.05][clampi(level-1,0,2)]
				scene_depth.append({"y":p.y+size*0.13,"kind":"castle","p":p,"size":size,"stage":level+1,"biome":str(town.get("home_biome","grass"))})
		elif kind=="campfire":
			_draw_live_campfire(p,unit)
		elif kind=="fish":
			# A margem existente e o ponto de pesca; nao desenhar piscina artificial.
			continue
		elif kind=="waterfall":
			var sx:int=int(site["x"])
			var sy:int=int(site["y"])
			if world.is_river_cell(sx,sy-1) and world.is_river_cell(sx,sy) and world.is_river_cell(sx,sy+1):
				_draw_waterfall(p,unit)
		elif kind=="crossing":
			_draw_landscape_object("bridge",p,unit*1.9)
		elif kind=="mine" and not bool(site.get("developed",false)):
			_draw_landscape_object("rock",p,unit*0.95)
		elif kind=="forge":
			var size := unit * 1.65
			_draw_landscape_object("forge", p, size)
			_draw_forge_smoke(p + Vector2(0.26, -0.61) * size, size)
		elif kind=="oven":
			_draw_landscape_object("oven",p,unit*0.84)
			if MAP_AREA.grow(-unit).has_point(p):
				for i in range(3):
					var age:float=fposmod(world.swamp_clock*0.34+float(i)*0.33,1.0)
					draw_circle(p+Vector2(unit*(0.13+age*0.10),-unit*(0.59+age*0.55)),unit*(0.035+age*0.055),Color(0.72,0.72,0.68,(1-age)*0.18))
		else:
			_draw_landscape_object(kind,p,unit*(1.45 if kind=="mine" else 0.95))

func _draw_forge_smoke(chimney: Vector2, size: float) -> void:
	for i in range(4):
		var age := fposmod(world.swamp_clock * 0.62 + i / 4.0, 1.0)
		var puff_size := size * lerpf(0.044, 0.103, age)
		var center := chimney + Vector2(age * age * 0.20, -age * 0.30) * size
		var puff := Rect2(center - Vector2.ONE * puff_size * 0.5, Vector2.ONE * puff_size)
		if MAP_AREA.encloses(puff):
			draw_circle(center, puff_size * 0.5, Color(0.76, 0.73, 0.69, 0.37 * (1.0 - age)))

func _draw_live_campfire(p: Vector2, unit: float) -> void:
	var size := unit * 0.72
	var dest := Rect2(p - Vector2(0.5, 0.8) * size, Vector2.ONE * size)
	var clipped := dest.intersection(MAP_AREA)
	if not clipped.has_area():
		return
	var frame := int(world.swamp_clock * 6.0) % 3
	var source_size := Vector2(CAMPFIRE_FRAMES.get_width() / 3.0, CAMPFIRE_FRAMES.get_height())
	var source_origin := Vector2(frame * source_size.x, 0)
	var source := Rect2(source_origin + (clipped.position - dest.position) / size * source_size, clipped.size / size * source_size)
	draw_texture_rect_region(CAMPFIRE_FRAMES, clipped, source)

# Reflexos espelhados dos sprites existentes, recortados pela agua.
# Somente objetos visiveis e celulas de agua proximas geram comandos de desenho.
func _reflect_sprite(texture:Texture2D,source:Rect2,base:Vector2,size:Vector2,opacity:float=0.62) -> void:
	if texture==null or not MAP_AREA.grow(size.y).has_point(base): return
	var extent:=Rect2(base-Vector2(size.x*0.5,0),size)
	var a:Vector2=_screen_to_world(extent.position)
	var b:Vector2=_screen_to_world(extent.end)
	var unit:float=TILE_SIZE*zoom
	for y in range(maxi(0,floori(a.y)),mini(World.SIZE,ceili(b.y))):
		for x in range(maxi(0,floori(a.x)),mini(World.WIDTH,ceili(b.x))):
			if str(world.tiles[y][x])!="water" or world.is_bridge(x,y): continue
			var cell:=Rect2(_world_to_screen(Vector2(x,y)),Vector2.ONE*unit)
			# Inset only at land edges; neighboring water tiles join seamlessly.
			if x==0 or str(world.tiles[y][x-1])!="water":
				cell.position.x+=unit*0.10
				cell.size.x-=unit*0.10
			if x==World.WIDTH-1 or str(world.tiles[y][x+1])!="water": cell.size.x-=unit*0.10
			if y==0 or str(world.tiles[y-1][x])!="water":
				cell.position.y+=unit*0.10
				cell.size.y-=unit*0.10
			if y==World.SIZE-1 or str(world.tiles[y+1][x])!="water": cell.size.y-=unit*0.10
			var visible:Rect2=extent.intersection(cell).intersection(MAP_AREA)
			if not visible.has_area(): continue
			var band:float=maxf(2.0,unit*0.075)
			var top:float=visible.position.y
			while top<visible.end.y-0.1:
				var h:float=minf(band,visible.end.y-top)
				var part:=Rect2(Vector2(visible.position.x,top),Vector2(visible.size.x,h))
				var progress:float=clampf((part.get_center().y-extent.position.y)/size.y,0.0,1.0)
				var shimmer:float=sin(progress*22.0-world.swamp_clock*3.0+base.x*0.01)*unit*0.024
				var sample_x:float=clampf((part.position.x-extent.position.x+shimmer)/size.x,0.0,1.0)
				var sample_w:float=minf(part.size.x/size.x,1.0-sample_x)
				if sample_w>0.001:
					part.size.x=sample_w*size.x
					var uv:=Rect2(source.position+Vector2(sample_x,1.0-(top+h-extent.position.y)/size.y)*source.size,Vector2(sample_w,h/size.y)*source.size)
					var tint:=Color(0.77,0.91,0.84,opacity*(1.0-progress*0.58))
					draw_set_transform(Vector2(0,part.position.y+part.end.y),0,Vector2(1,-1))
					draw_texture_rect_region(texture,part,uv,tint)
					draw_set_transform(Vector2.ZERO)
				top+=h

func _water_ripple(center:Vector2,radius:float,seed:float) -> void:
	if not MAP_AREA.grow(-radius).has_point(center): return
	for ring in range(2):
		var phase:float=fposmod(world.swamp_clock*0.50+seed+float(ring)*0.5,1.0)
		var rx:float=radius*(0.35+phase*0.85)
		var ry:float=rx*0.36
		for i in range(18):
			var a:float=float(i)*TAU/18.0
			var b:float=float(i+1)*TAU/18.0
			var p:Vector2=center+Vector2(cos(a)*rx,sin(a)*ry)
			var q:Vector2=center+Vector2(cos(b)*rx,sin(b)*ry)
			if world.water_depth(_screen_to_world(p)-Vector2(0.5,0.5))<=0.0: continue
			if world.water_depth(_screen_to_world(q)-Vector2(0.5,0.5))<=0.0: continue
			draw_line(p,q,Color(0.64,0.84,0.80,(1.0-phase)*0.32),maxf(1.0,zoom*0.8))

func _draw_water_reflections() -> void:
	var unit:float=TILE_SIZE*zoom
	for entry in scene_depth:
		if str(entry["kind"])!="tree": continue
		var key:String=str(entry["key"])
		if not landscape_objects.has(key):
			landscape_objects[key]=load("res://assets/landscape/"+key+".svg")
		var tex:Texture2D=landscape_objects.get(key)
		if tex==null: continue
		var p:Vector2=entry["p"]
		var size:float=float(entry["size"])
		_reflect_sprite(tex,Rect2(Vector2.ZERO,tex.get_size()*Vector2(1,0.85)),p+Vector2(0,size*0.09),Vector2(size,size*0.64))
		_water_ripple(p+Vector2(0,size*0.10),size*0.32,float(int(p.x)%17)*0.07)
	for town in world.towns:
		var center:Vector2=_world_to_screen(Vector2(float(town["x"])+0.5,float(town["y"])+0.5))
		if not MAP_AREA.grow(unit*6).has_point(center): continue
		var row:int=int({"snow":1,"sand":2,"swamp":3}.get(str(town.get("home_biome","grass")),0))
		var houses:Array[Vector2]=world.house_layout(town)
		for i in range(mini(int(town.get("houses",0)),houses.size())):
			var era:int=clampi(int(world.house_levels(town)[i]),1,4)
			var size:float=unit*(1.75 if i==0 else 1.48)*(1.0+float(era-1)*0.045)
			var base:Vector2=center+houses[i]*unit+Vector2(0,size*0.41)
			_reflect_sprite(BUILDINGS_APPROVED,Rect2((0 if era==1 else 1)*96,row*96,96,86),base,Vector2(size,size*0.65))
		var level:int=world.castle_level(town)
		if level>0:
			var size:float=unit*[1.95,2.48,3.05][level-1]
			_reflect_sprite(BUILDINGS_APPROVED,Rect2((level+1)*96,row*96,96,86),center+Vector2(0,size*0.13),Vector2(size,size*0.65))
	for site in world.sites:
		if str(site["kind"])!="campfire": continue
		var base:Vector2=_world_to_screen(Vector2(float(site["x"])+0.5,float(site["y"])+0.5))
		var frame:int=int(world.swamp_clock*6.0)%3
		var source_size:=Vector2(CAMPFIRE_FRAMES.get_width()/3.0,CAMPFIRE_FRAMES.get_height()*0.8)
		_reflect_sprite(CAMPFIRE_FRAMES,Rect2(Vector2(frame*source_size.x,0),source_size),base+Vector2(0,unit*0.14),Vector2(unit*0.72,unit*0.58),0.58)

func _draw_rivers() -> void:
	var unit:float=TILE_SIZE*zoom
	var time:float=float(Time.get_ticks_msec())*0.00055
	for y in range(World.SIZE):
		for x in range(World.WIDTH):
			if str(world.tiles[y][x])!="water": continue
			var p:Vector2=_world_to_screen(Vector2(x+0.5,y+0.5))
			if not MAP_AREA.grow(-unit*0.65).has_point(p): continue
			if world.swamp_water(x,y):
				if posmod(x*31+y*71,11)==0: _draw_mosquitoes(p,x*31+y*71,unit)
				if posmod(x*19+y*13,5)==0: _water_ripple(p,unit*0.28,float(posmod(x*13+y*7,19))/19.0)
				continue
			var flow:Vector2=world.water_flow(Vector2(x,y))
			for i in range(4):
				var phase:float=fposmod(time+float(i)*0.25+float(x)*0.13,1.0)
				var q:Vector2=p+flow*(phase-0.5)*unit*0.8+Vector2(flow.y,-flow.x)*(float(i)-1.5)*unit*0.14
				draw_rect(Rect2(q,Vector2(unit*0.12, maxf(1.0,unit*0.027))),Color("#8edbe1",0.6))

const WATERFALL_APPROVED:Texture2D=preload("res://assets/landscape/cachoeira_aprovada.png")
var waterfall_cache:Dictionary={}
var landscape_render_image:Image
# Adaptar a arte ao rio de verdade: combinar as margens, retirar a borda oval,
# misturar a agua superior/inferior com a cor e a profundidade do terreno local.
func _waterfall_for_site(site:Vector2,extent:Vector2) -> Texture2D:
	var key:=Vector2i(site.floor())
	if waterfall_cache.has(key): return waterfall_cache[key]
	var src:Image=WATERFALL_APPROVED.get_image()
	if src.is_compressed() and src.decompress()!=OK: return WATERFALL_APPROVED
	src.convert(Image.FORMAT_RGBA8)
	var image:Image=src.duplicate()
	var width:int=src.get_width()
	var height:int=src.get_height()
	for y in range(height):
		for x in range(width):
			var c:Color=src.get_pixel(x,y)
			if c.a<0.01: continue
			var uv:=Vector2((float(x)+0.5)/float(width),(float(y)+0.5)/float(height))
			var pos:Vector2=site+(uv-Vector2(0.50,0.48))*extent
			var ground:Color=Color("#104567")
			if landscape_render_image!=null:
				var px:int=clampi(floori(pos.x*24.0),0,landscape_render_image.get_width()-1)
				var py:int=clampi(floori(pos.y*24.0),0,landscape_render_image.get_height()-1)
				ground=landscape_render_image.get_pixel(px,py)
			var is_water:bool=c.b>c.r*1.13 and c.g>c.r*1.04
			var river_pixel:bool=ground.b>ground.r*1.10 and ground.g>ground.r*1.05
			# A queda vertical permanece opaca. Apenas o rio no topo e a piscina
			# recortada do rodape se misturam ao rio existente.
			if is_water and (uv.y<0.22 or uv.y>0.73):
				var end_fade:float=smoothstep(0.0,0.21,uv.y) if uv.y<0.22 else 1.0-smoothstep(0.72,1.0,uv.y)
				c.a*=end_fade
				if not river_pixel:
					c.a*=smoothstep(0.73,0.88,1.0-absf(uv.x-0.5))*0.22
				if c.v<0.66:
					var tint:Color=ground if river_pixel else Color("#226881")
					var opacity:float=c.a
					c=c.lerp(tint,0.34)
					c.a=opacity
			# Transicao de 4 pixels na silhueta, preserva os detalhes internos.
			var distance:int=5
			for radius in range(1,5):
				var edge:bool=false
				for off in [Vector2i(radius,0),Vector2i(-radius,0),Vector2i(0,radius),Vector2i(0,-radius)]:
					var q:Vector2i=Vector2i(x,y)+Vector2i(off)
					if q.x<0 or q.y<0 or q.x>=width or q.y>=height or src.get_pixelv(q).a<0.1:
						edge=true
						break
				if edge:
					distance=radius
					break
			c.a*=smoothstep(0.0,4.5,float(distance))
			image.set_pixel(x,y,c)
	var tex:Texture2D=ImageTexture.create_from_image(image)
	waterfall_cache[key]=tex
	return tex

func _draw_waterfall(p:Vector2,u:float) -> void:
	var extent:=Vector2(2.65,2.65*129.0/180.0)
	var size:Vector2=extent*u
	var dest:=Rect2(p-size*Vector2(0.50,0.48),size)
	var clipped:Rect2=dest.intersection(MAP_AREA)
	if not clipped.has_area(): return
	var texture:Texture2D=_waterfall_for_site(_screen_to_world(p),extent)
	var texsize:Vector2=texture.get_size()
	draw_texture_rect_region(texture,clipped,Rect2((clipped.position-dest.position)/size*texsize,clipped.size/size*texsize))
	if not MAP_AREA.grow(-u).has_point(p): return
	var time:float=world.swamp_clock
	# Espuma dispersa acompanha somente os pontos de agua abaixo da queda.
	for i in range(12):
		var f:float=fposmod(time*0.75+float(i)*0.173,1.0)
		var q:Vector2=p+Vector2((float(i%7)-3.0)*0.10*(1.0+f*0.45),0.25+f*0.65)*u
		if world.water_depth(_screen_to_world(q)-Vector2(0.5,0.5))<=0.15: continue
		draw_rect(Rect2(q.round(),Vector2(u*(0.065+f*0.05),maxf(1,u*0.022))),Color(0.83,0.96,0.98,(1.0-f)*0.65))
	for i in range(8):
		var f:float=fposmod(time+float(i)*0.179,1.0)
		var q:Vector2=dest.position+Vector2(size.x*(0.37+float(i)*0.033),size.y*(0.25+f*0.38))
		draw_rect(Rect2(q.round(),Vector2(maxf(1,u*0.013),maxf(2,u*0.10))),Color(0.84,0.96,1.0,0.22*sin(f*PI)))

const HUMAN_CELL := 48
const HUMAN_POSES := 10
const HUMAN_JOBS := {"Agricultor":4, "Minerador":5, "Construtor":6, "Ferreiro":7, "Explorador":8, "Caçador":8, "Lenhador":10, "Governante":11}

func _human_row(person: Dictionary) -> int:
	var female := clampi(int(person.get("gender", 0)), 0, 1)
	var first_row := female * 16
	var stage: int = world.life_stage(person)
	if stage < 2:
		return first_row + 2
	var job := str(person.get("profession", ""))
	if job == "Governante":
		return first_row + 11
	if world.is_military(person):
		var armor := clampi(int(person.get("armor", 0)), 0, 4)
		var tier := 0
		if armor > 0:
			tier = 1 if armor < 3 else armor - 1
		return first_row + 12 + tier
	if stage == 3:
		return first_row + 3
	match job:
		"Pescador": return 25 if female else 17
		"Cozinheiro": return 34 + female
		"Curandeiro": return 32 + female
	return first_row + int(HUMAN_JOBS.get(job, 0))

func _human_source(person: Dictionary, pose: int = 0) -> Rect2:
	var identity := posmod(int(person.get("appearance", person.get("id", 0))) + int(person.get("skin", 0)) * 3 + int(person.get("hair", 0)), 4)
	return Rect2((identity * HUMAN_POSES + pose) * HUMAN_CELL, _human_row(person) * HUMAN_CELL, HUMAN_CELL, HUMAN_CELL)

# A arte original permanece intacta. Cache por quadro e cor, sem substituir atlas.
const KINGDOM_CLOTH:Array[Color]=[Color("#272b2d"),Color("#456a9b"),Color("#963d37"),Color("#53714b"),Color("#765c92"),Color("#93733e")]
var kingdom_cloth_cache:Dictionary={}
var kingdom_source_image:Image

func _kingdom_cloth_index(person:Dictionary) -> int:
	var town:Dictionary=world.get_town(int(person.get("town",0)))
	if town.is_empty(): return -1
	return posmod(world.kingdom_id(town),KINGDOM_CLOTH.size())

func _kingdom_human_frame(person:Dictionary,pose:int) -> Dictionary:
	var atlas:Texture2D=landscape_objects["habitantes"]
	var source:Rect2=_human_source(person,pose)
	var index:int=_kingdom_cloth_index(person)
	# Quedas e armaduras completas ficam intocadas: sem mascara de tecido aprovada.
	if index<0 or pose>=8 or (world.is_military(person) and int(person.get("armor",0))>0):
		return {"atlas":atlas,"source":source}
	var key:String="%d:%d:%d"%[index,int(source.position.x),int(source.position.y)]
	if kingdom_cloth_cache.has(key):
		return {"atlas":kingdom_cloth_cache[key],"source":Rect2(0,0,HUMAN_CELL,HUMAN_CELL)}
	if kingdom_source_image==null:
		kingdom_source_image=atlas.get_image()
		if kingdom_source_image.is_compressed() and kingdom_source_image.decompress()!=OK:
			kingdom_source_image=null
			return {"atlas":atlas,"source":source}
	var frame:Image=kingdom_source_image.get_region(Rect2i(source))
	var used:Rect2i=frame.get_used_rect()
	var cloth:Color=KINGDOM_CLOTH[index]
	for y in range(used.position.y,used.end.y):
		for x in range(used.position.x,used.end.x):
			var fy:float=float(y-used.position.y)/maxf(1.0,float(used.size.y))
			var fx:float=float(x-used.position.x)/maxf(1.0,float(used.size.x))
			# Apenas o nucleo do tronco e cores frias saturadas; pele, cabelo,
			# contornos, metal, ferramentas e tons ambiguos ficam como eram.
			if fy<0.48 or fy>0.72 or fx<0.34 or fx>0.66: continue
			var pixel:Color=frame.get_pixel(x,y)
			if pixel.a<0.98 or pixel.s<0.24 or pixel.v<0.20 or pixel.v>0.88: continue
			if pixel.h<0.24 or pixel.h>0.73: continue
			var recolored:=Color.from_hsv(cloth.h,cloth.s,clampf(pixel.v*(0.58 if index==0 else 0.94),0.12,0.88),pixel.a)
			frame.set_pixel(x,y,recolored)
	var texture:=ImageTexture.create_from_image(frame)
	if kingdom_cloth_cache.size()>=384: kingdom_cloth_cache.clear()
	kingdom_cloth_cache[key]=texture
	return {"atlas":texture,"source":Rect2(0,0,HUMAN_CELL,HUMAN_CELL)}

func _human_portrait(person: Dictionary) -> Texture2D:
	var portrait := AtlasTexture.new()
	var frame:Dictionary=_kingdom_human_frame(person,0)
	portrait.atlas = frame["atlas"]
	portrait.region = frame["source"]
	return portrait

func _draw_person_variant(p:Dictionary,center:Vector2) -> void:
	var stage: int = world.life_stage(p)
	var s: float = 22.0 * zoom * [0.53, 0.78, 1.0, 0.94][stage]
	var atlas: Texture2D = landscape_objects["habitantes"]
	var movement: Dictionary = visual_motion.get(int(p["id"]), {})
	var moving: bool = bool(movement.get("moving", false)) and world.speed > 0
	var phase := float(movement.get("phase", 0))
	var face := float(movement.get("face", 1.0))
	if not bool(p.get("alive", true)):
		var fallen_for: float = world.swamp_clock - float(p["fell_at"])
		var death_pose := 8 if fallen_for < 0.3 else 9
		_draw_walk_sprite(atlas, _human_source(p, death_pose), center, s, face, 0.0, false, 0.0)
		return
	var action: String = world.visible_action(p)
	var pose := int(fposmod(phase, TAU) / TAU * 4.0) if moving else 0
	var beat := int(world.swamp_clock * 4.0 + int(p["id"]) % 2) % 2
	if action == "combat":
		pose = 6 + beat
	elif action in ["mining", "chopping", "farming", "building", "smithing", "healing", "fishing", "cooking"] and not moving:
		pose = 4 + beat
	var bounce := absf(sin(phase)) * s * 0.018 if moving else 0.0
	var depth: float = world.water_depth(Vector2(float(p["x"]), float(p["y"])))
	if depth > 0:
		var stroke := int(world.swamp_clock * 4.0 + int(p["id"]) % 3) % 4
		var swim_frame:Dictionary=_kingdom_human_frame(p,stroke)
		_draw_water_actor(swim_frame["atlas"], swim_frame["source"], center, s, face, depth, "human", moving)
		return
	_contact_shadow(center, s * 0.22, s * 0.07)
	var cloth_frame:Dictionary=_kingdom_human_frame(p,pose)
	_draw_walk_sprite(cloth_frame["atlas"], cloth_frame["source"], center, s, face, phase, false, bounce)
	_draw_equipment(p,center,s,bounce,face)
	if bool(p.get("witch_staff",false)) and action=="combat":
		_draw_landscape_object("magic_staff",center+Vector2(face*s*0.27,0),s*0.78)
	var cargo:Dictionary=p.get("cargo",{})
	if not cargo.is_empty() and action.is_empty() and MAP_AREA.grow(-s).has_point(center):
		var cargo_icon:String="cart" if str(p.get("transport","hands"))=="cart" else str({"wood":"log_bundle","stone":"rock","ore":"rock"}.get(str(cargo["kind"]),"sack"))
		_draw_landscape_object(cargo_icon,center+Vector2(-face*s*0.32,0),s*0.53)
	if action=="deposit" and MAP_AREA.grow(-s).has_point(center):
		for i in range(3):
			var q:Vector2=center+Vector2(float(i-1)*s*0.12,s*0.05)
			draw_rect(Rect2(q,Vector2.ONE*maxf(1.0,s*0.06)),Color("#c6a371",0.75))


func _draw_clock() -> void:
	var c := Vector2(705+screen_width-1280.0, 34)
	draw_circle(c, 24.0, Color("#4a3829"))
	draw_circle(c, 19.0, Color("#d9c38c"))
	draw_circle(c, 16.5, Color("#423b2c"))
	var seasons: Array[Color] = [Color("#7dbb6a"), Color("#f5c66a"), Color("#b77e49"), Color("#b0d6d9")]
	for i in range(4):
		draw_arc(c, 17.3, float(i) * TAU / 4.0 - PI * 0.5, float(i + 1) * TAU / 4.0 - PI * 0.5, 12, seasons[i], 2.5, true)
	for hour in range(12):
		var a: float = float(hour) * TAU / 12.0 - PI * 0.5
		draw_line(c + Vector2(cos(a), sin(a)) * 13.0, c + Vector2(cos(a), sin(a)) * 16.0, Color("#f7dfa4"), 1.5)
	# Uma volta do ponteiro representa um ano completo; nao gira a cada 2 segundos.
	var year_progress: float = fposmod(world.day / 365.0, 1.0)
	var angle: float = year_progress * TAU - PI * 0.5
	draw_line(c, c + Vector2(cos(angle), sin(angle)) * 12.0, Color("#f6d68b"), 2.2, true)
	draw_line(c, c + Vector2(cos(angle * 0.083), sin(angle * 0.083)) * 8.0, Color("#ffefe0"), 3.1, true)
	draw_circle(c, 2.5, Color("#f4cf81"))

func _draw_character_hud() -> void:
	var base: Vector2 = joystick_center if joystick_touch >= 0 else Vector2(143, 574)
	draw_circle(base, 60.0, Color("#0d1c18", 0.55))
	draw_arc(base, 58.0, 0.0, TAU, 44, Color("#f0d49a", 0.58), 3.0, true)
	var grip: Vector2 = base + joystick_direction * 43.0
	draw_circle(grip, 25.0, Color("#806441", 0.78))
	draw_arc(grip, 25.0, 0.0, TAU, 28, Color("#edd5a5"), 2.0)
	var sight: Vector2 = MAP_AREA.get_center()
	draw_line(sight - Vector2(10, 0), sight - Vector2(3, 0), Color("#e7dbbc", 0.72), 2.0)
	draw_line(sight + Vector2(3, 0), sight + Vector2(10, 0), Color("#e7dbbc", 0.72), 2.0)
	draw_line(sight - Vector2(0, 10), sight - Vector2(0, 3), Color("#e7dbbc", 0.72), 2.0)
	draw_line(sight + Vector2(0, 3), sight + Vector2(0, 10), Color("#e7dbbc", 0.72), 2.0)
	var actor: Dictionary = world.get_actor(controlled_id)
	for i in range(4):
		var keys := ["wood", "food", "stone", "water"]
		var names := ["Madeira", "Comida", "Pedra", "Agua"]
		var slot := Rect2(418 + i * 110, 641, 106, 54)
		draw_rect(slot, Color("#26291f", 0.90), true)
		draw_rect(slot, Color("#b39c6e"), false, 2)
		draw_string(ThemeDB.fallback_font, slot.position + Vector2(8, 20), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#e8d4ab"))
		draw_string(ThemeDB.fallback_font, slot.position + Vector2(8, 43), str(int(actor.get(keys[i], 0))), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color.WHITE)
	draw_rect(Rect2(865, 643, 380, 42), Color("#1c2a21", 0.8), true)
	draw_string(ThemeDB.fallback_font, Vector2(875, 670), "Andar à esquerda  •  olhar à direita", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#f8e0b3"))


func _draw_panel(rect: Rect2, fill: Color) -> void:
	draw_rect(rect, Color("#12130f"), true)
	draw_rect(rect.grow(-3), fill, true)
	draw_rect(rect, Color("#b9965a"), false, 3.0)
	draw_line(rect.position + Vector2(7, 7), Vector2(rect.end.x - 7, rect.position.y + 7), Color("#e2bb75", 0.56), 1.0)

func _draw_tile_card(key: String, rect: Rect2) -> void:
	draw_rect(rect, Color("#171d17"), true)
	if tile_textures.has(key):
		draw_texture_rect(tile_textures[key] as Texture2D, rect.grow(-3), false)
	else:
		draw_rect(rect.grow(-3), Color("#4a7756"), true)
	draw_rect(rect, Color("#b99a61"), false, 2.0)

func _world_to_screen(world_pos: Vector2) -> Vector2:
	return MAP_ORIGIN + map_offset + world_pos * TILE_SIZE * zoom

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return (screen_pos - MAP_ORIGIN - map_offset) / (TILE_SIZE * zoom)

func _unhandled_input(event: InputEvent) -> void:
	if home_open: return
	# A base Android antiga pode duplicar toques como eventos de mouse.
	# Ignorar esses clones preserva pinça e analógico nas atualizações PCK.
	if OS.has_feature("mobile") and (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	if character_view:
		_character_input(event)
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			if MAP_AREA.has_point(touch.position):
				active_touches[touch.index] = touch.position
				if active_touches.size() == 1:
					drag_touch_id = touch.index
					drag_started = touch.position
					dragging = true
				else:
					dragging = false
					pinch_active = true
					_reset_pinch()
		else:
			var belonged_to_map: bool = active_touches.has(touch.index)
			active_touches.erase(touch.index)
			if belonged_to_map:
				if pinch_active:
					# Nao selecionar habitantes acidentalmente ao soltar um gesto com dois dedos.
					if active_touches.size() >= 2:
						_reset_pinch()
					else:
						pinch_active = false
						pinch_distance = 0.0
						dragging = false
						drag_touch_id = -1
				elif dragging and drag_touch_id == touch.index:
					if drag_started.distance_to(touch.position) < 14.0:
						_touch_map(touch.position)
					dragging = false
					drag_touch_id = -1

	elif event is InputEventScreenDrag:
		var motion: InputEventScreenDrag = event
		if not active_touches.has(motion.index):
			return
		active_touches[motion.index] = motion.position
		if active_touches.size() >= 2 and not character_view:
			_update_pinch()
		elif dragging and drag_touch_id == motion.index and not character_view:
			map_offset += motion.relative
			_clamp_map()
	elif event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP and MAP_AREA.has_point(mouse.position):
			_zoom_around(mouse.position, zoom * 1.13)
		elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN and MAP_AREA.has_point(mouse.position):
			_zoom_around(mouse.position, zoom / 1.13)
		elif mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed and MAP_AREA.has_point(mouse.position):
				drag_started = mouse.position
				dragging = true
			elif not mouse.pressed and dragging:
				if drag_started.distance_to(mouse.position) < 12.0:
					_touch_map(mouse.position)
				dragging = false
	elif event is InputEventMouseMotion and dragging and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if not character_view:
			map_offset += event.relative
			_clamp_map()

func _character_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and MAP_AREA.has_point(touch.position):
			if touch.position.x < MAP_AREA.get_center().x and joystick_touch < 0:
				joystick_touch = touch.index
				joystick_center = touch.position
				joystick_direction = Vector2.ZERO
			elif look_touch < 0:
				look_touch = touch.index
		elif not touch.pressed:
			if touch.index == joystick_touch:
				joystick_touch = -1
				joystick_direction = Vector2.ZERO
			if touch.index == look_touch:
				look_touch = -1
	elif event is InputEventScreenDrag:
		var motion: InputEventScreenDrag = event
		if motion.index == joystick_touch:
			joystick_direction = ((motion.position - joystick_center) / 63.0).limit_length(1.0)
		elif motion.index == look_touch:
			look_yaw -= motion.relative.x * 0.005
			look_pitch = clampf(look_pitch - motion.relative.y * 0.004, -0.55, 0.55)
	elif event is InputEventMouseMotion:
		var mouse: InputEventMouseMotion = event
		if (mouse.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and MAP_AREA.has_point(mouse.position):
			look_yaw -= mouse.relative.x * 0.004
			look_pitch = clampf(look_pitch - mouse.relative.y * 0.0035, -0.55, 0.55)

func _reset_pinch() -> void:
	if active_touches.size() < 2:
		pinch_distance = 0.0
		return
	var fingers: Array = active_touches.keys()
	var first: Vector2 = active_touches[fingers[0]]
	var second: Vector2 = active_touches[fingers[1]]
	pinch_distance = maxf(first.distance_to(second), 1.0)
	pinch_midpoint = (first + second) * 0.5

func _update_pinch() -> void:
	if active_touches.size() < 2:
		return
	var fingers: Array = active_touches.keys()
	var first: Vector2 = active_touches[fingers[0]]
	var second: Vector2 = active_touches[fingers[1]]
	var current_distance: float = maxf(first.distance_to(second), 1.0)
	var center: Vector2 = (first + second) * 0.5
	if pinch_distance > 2.0:
		# O centro pode mudar durante a pinça: permitir zoom E deslocamento suave.
		var anchor: Vector2 = _screen_to_world(pinch_midpoint)
		zoom = clampf(zoom * (current_distance / pinch_distance), maxf(MAP_AREA.size.x / (float(World.WIDTH) * TILE_SIZE), MAP_AREA.size.y / (float(World.SIZE) * TILE_SIZE)), 3.5)
		map_offset = center - MAP_ORIGIN - anchor * TILE_SIZE * zoom
		_clamp_map()
	pinch_distance = current_distance
	pinch_midpoint = center

func _zoom_around(screen_point: Vector2, desired_zoom: float) -> void:
	var anchor: Vector2 = _screen_to_world(screen_point)
	zoom = clampf(desired_zoom, maxf(MAP_AREA.size.x / (float(World.WIDTH) * TILE_SIZE), MAP_AREA.size.y / (float(World.SIZE) * TILE_SIZE)), 3.5)
	map_offset = screen_point - MAP_ORIGIN - anchor * TILE_SIZE * zoom
	_clamp_map()

func _touch_map(position: Vector2) -> void:
	_close_actor_card()
	if character_view:
		if controlled_id > 0:
			var actor: Dictionary = world.get_actor(controlled_id)
			if not actor.is_empty():
				var d: Vector2 = (position - MAP_AREA.get_center()).normalized()
				actor["target_x"] = clampf(float(actor["x"]) + d.x * 2.4, 1.0, float(World.WIDTH - 2))
				actor["target_y"] = clampf(float(actor["y"]) + d.y * 2.4, 1.0, float(World.SIZE - 2))
		return
	var point := _screen_to_world(position)
	if not spawn_species.is_empty():
		if MAP_AREA.has_point(position): world.spawn_creature(spawn_species,point-Vector2(0.5,0.5))
		_refresh_ui()
		return
	if point.x < -0.5 or point.y < -0.5 or point.x > World.WIDTH or point.y > World.SIZE:
		return
	var nearest_id := 0
	var nearest_beast_id := 0
	var min_dist := 0.46
	for p in world.people:
		if not bool(p["alive"]):
			continue
		var d := Vector2(float(p["x"]) + 0.5, float(p["y"]) + 0.5).distance_to(point)
		if d < min_dist:
			min_dist = d
			nearest_id = int(p["id"])
			nearest_beast_id = 0
	for b in world.beasts:
		if not bool(b["alive"]):
			continue
		var d := Vector2(float(b["x"]) + 0.5, float(b["y"]) + 0.5).distance_to(point)
		if d < min_dist:
			min_dist = d
			nearest_id = 0
			nearest_beast_id = int(b["id"])
	if controlled_id==0:
		var chosen_animal:Dictionary={}
		for animal in world.wildlife:
			if float(animal.get("health",1))<=0: continue
			var d:float=Vector2(float(animal["x"])+0.5,float(animal["y"])+0.5).distance_to(point)
			if d<min_dist:
				min_dist=d
				chosen_animal=animal
		if not chosen_animal.is_empty():
			selected_person_id = 0
			selected_beast_id = 0
			selected_town_id = 0
			_refresh_ui()
			_show_animal_card(chosen_animal)
			return
	if nearest_id > 0:
		selected_person_id = nearest_id
		selected_beast_id = 0
		selected_town_id = 0
		if controlled_id == 0:
			_open_actor_card(world.get_person(nearest_id), true)
	elif nearest_beast_id > 0:
		selected_beast_id = nearest_beast_id
		selected_person_id = 0
		selected_town_id = 0
		if controlled_id==0:
			var animal:Dictionary=world.get_beast(nearest_beast_id)
			if not animal.is_empty(): _show_animal_card(animal)
	else:
		if controlled_id==0 and _inspect_building(point-Vector2(0.5,0.5)): return
		# Um toque na casa deve abrir sua ficha, mesmo quando um personagem ja esta sob controle.
		var near_town: Dictionary = {}
		for t in world.towns:
			if Vector2(float(t["x"]) + 0.5, float(t["y"]) + 0.5).distance_to(point) < 0.90:
				near_town = t
				break
		if not near_town.is_empty():
			selected_person_id = 0
			selected_beast_id = 0
			selected_town_id = int(near_town["id"])
		elif controlled_id > 0:
			var actor: Dictionary = world.get_actor(controlled_id)
			if not actor.is_empty():
				actor["target_x"] = clampf(point.x - 0.5, 1.0, World.WIDTH - 2.0)
				actor["target_y"] = clampf(point.y - 0.5, 1.0, World.SIZE - 2.0)
		else:
			selected_person_id = 0
			selected_beast_id = 0
			selected_town_id = 0
	_refresh_ui()

func _move_controlled(delta: float) -> void:
	if controlled_id <= 0 or world.speed <= 0.0:
		return
	var actor: Dictionary = world.get_actor(controlled_id)
	if actor.is_empty() or not bool(actor["alive"]):
		controlled_id = 0
		character_view = false
		_sync_character_ui()
		return
	if character_view:
		var direction := joystick_direction
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			direction.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			direction.y += 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			direction.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			direction.x += 1.0
		if direction.length_squared() > 0.01:
			direction = direction.normalized() * minf(direction.length(), 1.0)
			var forward := Vector2(-sin(look_yaw), -cos(look_yaw))
			var right := Vector2(cos(look_yaw), -sin(look_yaw))
			var movement: Vector2 = (right * direction.x - forward * direction.y) * delta * 2.25 * world.life_speed(actor)
			var nx: float = clampf(float(actor["x"]) + movement.x, 1.0, float(World.WIDTH - 2))
			var ny: float = clampf(float(actor["y"]) + movement.y, 1.0, float(World.SIZE - 2))
			var kind: String = str(world.tiles[clampi(int(ny), 0, World.SIZE - 1)][clampi(int(nx), 0, World.WIDTH - 1)])
			if kind != "mountain":
				world.move_actor(actor,movement,delta)
				actor["target_x"] = actor["x"]
				actor["target_y"] = actor["y"]
		return
	var toward := Vector2(float(actor["target_x"]) - float(actor["x"]), float(actor["target_y"]) - float(actor["y"]))
	if toward.length() > 0.04:
		var step := toward.limit_length(delta * world.speed * 2.4)
		world.move_actor(actor,step,delta*world.speed)

func _clamp_map() -> void:
	zoom = maxf(zoom, maxf(MAP_AREA.size.x / (float(World.WIDTH) * TILE_SIZE), MAP_AREA.size.y / (float(World.SIZE) * TILE_SIZE)))
	var side: float = float(World.WIDTH) * TILE_SIZE * zoom
	if side <= MAP_AREA.size.x:
		map_offset.x = MAP_AREA.get_center().x - MAP_ORIGIN.x - side * 0.5
	else:
		var minimum_x: float = MAP_AREA.end.x - MAP_ORIGIN.x - side
		var maximum_x: float = MAP_AREA.position.x - MAP_ORIGIN.x
		map_offset.x = clampf(map_offset.x, minimum_x, maximum_x)
	side = float(World.SIZE) * TILE_SIZE * zoom
	if side <= MAP_AREA.size.y:
		map_offset.y = MAP_AREA.get_center().y - MAP_ORIGIN.y - side * 0.5
	else:
		var minimum_y: float = MAP_AREA.end.y - MAP_ORIGIN.y - side
		var maximum_y: float = MAP_AREA.position.y - MAP_ORIGIN.y
		map_offset.y = clampf(map_offset.y, minimum_y, maximum_y)

func _toggle_pause() -> void:
	if world.speed == 0.0:
		world.speed = resume_speed
	else:
		resume_speed = world.speed
		world.speed = 0.0
	_refresh_ui()

func _change_speed() -> void:
	var current_speed: float = resume_speed if world.speed == 0.0 else world.speed
	if current_speed < 1.0:
		current_speed = 1.0
	elif current_speed < 2.0:
		current_speed = 2.0
	elif current_speed < 4.0:
		current_speed = 4.0
	else:
		current_speed = 0.5
	resume_speed = current_speed
	if world.speed > 0.0:
		world.speed = current_speed
	_refresh_ui()

func _zoom_in() -> void:
	_zoom_around(MAP_AREA.get_center(), zoom * 1.25)

func _zoom_out() -> void:
	_zoom_around(MAP_AREA.get_center(), zoom / 1.25)

func _sync_character_ui() -> void:
	action_button.visible = controlled_id > 0
	inventory_button.visible = controlled_id > 0

func _toggle_view() -> void:
	_close_actor_card()
	if controlled_id>0:
		controlled_id=0
		world.news="Observando o mundo."
	else:
		var candidate_id:int=selected_person_id if selected_person_id>0 else selected_beast_id
		if candidate_id<=0:
			for p in world.people:
				if bool(p["alive"]) and float(p["age"])>=16:
					candidate_id=int(p["id"])
					selected_person_id=candidate_id
					break
		var candidate:Dictionary=world.get_actor(candidate_id)
		if not candidate.is_empty() and bool(candidate["alive"]):
			controlled_id=candidate_id
			candidate["target_x"]=candidate["x"]
			candidate["target_y"]=candidate["y"]
			_focus_at(Vector2(float(candidate["x"])+0.5,float(candidate["y"])+0.5))
			world.news="Toque no mapa para andar. Use Coletar e Inventario."
	_sync_character_ui()
	_refresh_ui()

func _focus_at(point: Vector2) -> void:
	map_offset = MAP_AREA.get_center() - MAP_ORIGIN - point * TILE_SIZE * zoom
	_clamp_map()

func _focus_biome(kind: String) -> void:
	character_view = false
	_sync_character_ui()
	var found := false
	for y in range(world.tiles.size()):
		var row: Array = world.tiles[y]
		for x in range(row.size()):
			if str(row[x]) == kind:
				var point := Vector2(float(x) + 0.5, float(y) + 0.5)
				_focus_at(point)
				found = true
				break
		if found:
			break
	world.news = "Explorando " + kind + "." if found else "Nenhum terreno deste tipo neste mundo."
	_refresh_ui()

func _toggle_control() -> void:
	if controlled_id > 0:
		controlled_id = 0
		character_view = false
		_sync_character_ui()
		world.news = "Voce voltou a observar o mundo."
	elif selected_person_id > 0 or selected_beast_id > 0:
		var target_id := selected_person_id if selected_person_id > 0 else selected_beast_id
		var actor: Dictionary = world.get_actor(target_id)
		if not actor.is_empty() and bool(actor["alive"]):
			controlled_id = target_id
			world.news = "Agora voce controla " + str(actor["name"]) + ". Toque no mapa para andar."
	_sync_character_ui()
	_refresh_ui()

func _toggle_war() -> void:
	world.wars = not world.wars
	world.news = "Guerras habilitadas." if world.wars else "Guerras desabilitadas."
	_refresh_ui()

func _toggle_rivals() -> void:
	world.toggle_rivals()
	_refresh_ui()

func _toggle_predators() -> void:
	world.toggle_predators()
	_refresh_ui()

func _preferred_town_id() -> int:
	if selected_town_id > 0:
		return selected_town_id
	if selected_person_id > 0:
		var person: Dictionary = world.get_person(selected_person_id)
		if not person.is_empty():
			return int(person["town"])
	if controlled_id > 0:
		var actor: Dictionary = world.get_person(controlled_id)
		if not actor.is_empty():
			return int(actor["town"])
	if world.towns.is_empty():
		return 0
	# A aldeia que ocupa o centro da camera e o alvo padrao.
	var focus: Vector2 = _screen_to_world(MAP_AREA.get_center())
	var nearest_id: int = int(world.towns[0]["id"])
	var best_distance: float = INF
	for town in world.towns:
		var distance: float = Vector2(float(town["x"]) + 0.5, float(town["y"]) + 0.5).distance_to(focus)
		if distance < best_distance:
			best_distance = distance
			nearest_id = int(town["id"])
	return nearest_id

func _show_construction() -> void:
	if world.towns.is_empty():
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Construir na aldeia"
	dialog.dialog_text = "As construcoes usam madeira e demoram alguns segundos de jogo."
	dialog.ok_button_text = "Iniciar obra"
	dialog.cancel_button_text = "Voltar"
	var body := VBoxContainer.new()
	body.position = Vector2(20, 102)
	body.size = Vector2(510, 192)
	body.add_theme_constant_override("separation", 8)
	dialog.add_child(body)
	var town_picker := OptionButton.new()
	var build_picker := OptionButton.new()
	for town in world.towns:
		town_picker.add_item(str(town["name"]), int(town["id"]))
	build_picker.add_item("Casa (14 madeira)", 0)
	build_picker.add_item("Fazenda (18 madeira)", 1)
	build_picker.add_item("Fogueira (10 madeira)", 2)
	var prefer_id := _preferred_town_id()
	for i in range(town_picker.item_count):
		if town_picker.get_item_id(i) == prefer_id:
			town_picker.select(i)
			break
	var label := Label.new()
	label.text = "Aldeia"
	body.add_child(label)
	body.add_child(town_picker)
	var build_label := Label.new()
	build_label.text = "Projeto"
	body.add_child(build_label)
	body.add_child(build_picker)
	var stock_label := Label.new()
	body.add_child(stock_label)
	var refresh_stock := func(_index: int) -> void:
		var t: Dictionary = world.get_town(town_picker.get_selected_id())
		if t.is_empty():
			return
		var site: Dictionary = t.get("construction", {})
		var status: String = " | Obra em andamento" if not site.is_empty() else ""
		stock_label.text = "Madeira: %d | Casas: %d | Fazendas: %d%s" % [int(float(t["wood"])), int(t.get("houses", 2)), int(t.get("farms", 1)), status]
	town_picker.item_selected.connect(refresh_stock)
	refresh_stock.call(0)
	dialog.confirmed.connect(func() -> void:
		var kind: String = ["house","farm","campfire"][build_picker.get_selected_id()]
		var target: int = town_picker.get_selected_id()
		if world.start_construction(target, kind):
			selected_town_id = target
			selected_person_id = 0
			selected_beast_id = 0
			world.save_world()
		_refresh_ui()
		queue_redraw()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(560, 430))

func _show_diplomacy() -> void:
	if world.towns.size() < 2:
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Diplomacia entre aldeias"
	dialog.dialog_text = "Escolha duas aldeias e o tipo de acordo:"
	dialog.ok_button_text = "Confirmar"
	dialog.cancel_button_text = "Cancelar"
	var body := VBoxContainer.new()
	body.position = Vector2(24, 116)
	body.size = Vector2(540, 320)
	body.add_theme_constant_override("separation", 9)
	dialog.add_child(body)
	var first_picker := OptionButton.new()
	var second_picker := OptionButton.new()
	var action_picker := OptionButton.new()
	for town in world.towns:
		first_picker.add_item(str(town["name"]), int(town["id"]))
		second_picker.add_item(str(town["name"]), int(town["id"]))
	if selected_town_id > 0:
		for i in range(first_picker.item_count):
			if first_picker.get_item_id(i) == selected_town_id:
				first_picker.select(i)
				break
	second_picker.select(1 if first_picker.selected == 0 else 0)
	action_picker.add_item("Propor paz", 0)
	action_picker.add_item("Formar alianca", 1)
	action_picker.add_item("Declarar guerra", 2)
	action_picker.add_item("Manter cerco", 3)
	action_picker.add_item("Atacar diretamente", 4)
	for label_text in ["Aldeia de origem", "Aldeia de destino", "Acao diplomatica"]:
		var label := Label.new()
		label.text = label_text
		body.add_child(label)
		match label_text:
			"Aldeia de origem": body.add_child(first_picker)
			"Aldeia de destino": body.add_child(second_picker)
			"Acao diplomatica": body.add_child(action_picker)
	dialog.confirmed.connect(func() -> void:
		var from_id := first_picker.get_selected_id()
		var to_id := second_picker.get_selected_id()
		if from_id == to_id:
			world.news = "Escolha duas aldeias diferentes para negociar."
		else:
			var action := "peace"
			var choice:int=action_picker.get_selected_id()
			match choice:
				1: action = "alliance"
				2,3,4: action = "war"
			if action == "war":
				world.wars = true
				if not world.rivals:
					world.toggle_rivals()
			var accepted:bool=world.politics.set_treaty(world, from_id, to_id, action)
			if accepted and choice in [3,4]:
				var attacker:Dictionary=world.get_town(from_id)
				var defender:Dictionary=world.get_town(to_id)
				var mode:String="blockade" if choice==3 else "assault"
				if int(attacker.get("raid_target",0))==to_id:
					attacker["campaign_mode"]=mode
					world.news="Estratégia militar alterada."
				elif not world.begin_campaign(attacker,defender,mode):
					world.news="Não foi possível iniciar a campanha. Verifique o exército e as guerras ativas."
			elif not accepted: world.news="A guerra só termina por rendição ou derrota."
			world.save_world()
		_refresh_ui()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(600, 580))

func _show_options() -> void:
	var popup := PopupMenu.new()
	popup.add_item("Criar humanos e animais", 14)
	popup.add_item("Construir casas / fazendas", 5)
	popup.add_item("Controlar personagem / Soltar", 11)
	popup.add_item("Inventario do personagem", 12)
	popup.add_separator()
	popup.add_item("Ver biomas", 10)
	popup.add_item("Ciclo da vida e evolucao", 13)
	popup.add_item("Ficha da pessoa / aldeia", 4)
	popup.add_item("Diplomacia", 6)
	popup.add_item("Ativar / desativar guerras", 7)
	popup.add_item("Ativar / desativar tribos rivais", 8)
	popup.add_item("Ataques de animais: "+("ATIVOS" if world.predators else "DESATIVADOS"), 9)
	popup.add_separator()
	popup.add_item("Ir para primeira vila", 3)
	popup.add_item("Salvar mundo", 2)
	popup.add_item("Verificar atualizacoes", 0)
	popup.add_item("Configurar som", 15)
	popup.add_item("Criar novo mundo", 1)
	popup.add_item("Salvar e voltar ao menu inicial", 16)
	popup.add_item("Reiniciar este mundo", 17)
	popup.add_item("Apagar este mundo", 18)
	popup.id_pressed.connect(func(which: int) -> void:
		match which:
			0: _check_updates()
			1: _new_world()
			2: _save_now()
			3:
				if not world.towns.is_empty():
					var t: Dictionary = world.towns[0]
					character_view = false
					_sync_character_ui()
					_focus_at(Vector2(float(t["x"]) + 0.5, float(t["y"]) + 0.5))
			4: _show_details()
			5: _show_construction()
			6: _show_diplomacy()
			7: _toggle_war()
			8: _toggle_rivals()
			9: _toggle_predators()
			10: _show_biomes()
			11: _toggle_view()
			12: _show_inventory()
			13: _show_world_cycle()
			14: _show_spawn_menu()
			15: soundscape.show_settings()
			16: _open_home(true)
			17: _confirm_world_action(world.save_path,world.world_name,true)
			18: _confirm_world_action(world.save_path,world.world_name,false)
		popup.queue_free()
	)
	add_child(popup)
	popup.popup_centered(Vector2i(430, 650))

func _show_biomes() -> void:
	var popup := PopupMenu.new()
	for option in [["Deserto", "sand"], ["Floresta", "forest"], ["Neve", "snow"], ["Montanhas", "mountain"], ["Pantano", "swamp"]]:
		popup.add_item(str(option[0]))
	popup.id_pressed.connect(func(which: int) -> void:
		var kinds := ["sand", "forest", "snow", "mountain", "swamp"]
		if which >= 0 and which < kinds.size():
			_focus_biome(kinds[which])
		popup.queue_free()
	)
	add_child(popup)
	popup.popup_centered(Vector2i(360, 360))

func _show_world_cycle() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "A vida continua"
	dialog.dialog_text = "Ano: %d  |  %s\nCriancas crescem, adultos trabalham, familias se formam e lideres sao sucedidos.\n\nAs aldeias produzem alimentos e madeira, abrem fazendas, constroem casas e desenvolvem novas tecnicas.\n\nOs biomas mudam o que cada aldeia consegue produzir. O frio e a seca tornam a sobrevivencia mais dificil.\n\nUse o mapa para observar geracoes e o menu para tomar decisoes." % [int(world.day / 365.0) + 1, _season_name()]
	add_child(dialog)
	dialog.popup_centered(Vector2i(610, 390))
	dialog.confirmed.connect(dialog.queue_free)

func _character_action() -> void:
	var actor: Dictionary = world.get_actor(controlled_id)
	if actor.is_empty():
		world.news = "Escolha um personagem para agir."
		return
	var px: int = clampi(int(float(actor["x"])), 0, World.WIDTH - 1)
	var py: int = clampi(int(float(actor["y"])), 0, World.SIZE - 1)
	var biome: String = str(world.tiles[py][px])
	var facing := Vector2(-sin(look_yaw),-cos(look_yaw))
	var origin := Vector2(float(actor["x"]),float(actor["y"]))
	if world.collect_nearby_drop(actor) or world.cast_staff(actor) or world.strike_witch(actor) or world.strike_ancestral(actor):
		world.save_world()
		_refresh_ui()
		return
	if world.is_military(actor):
		world.news="Militares defendem a aldeia; os civis recolhem recursos."
		_refresh_ui()
		return
	var chosen: Dictionary = {}
	var best: float = 1.65
	for tree in world.trees.values():
		if str(tree["state"])!="live" or world.tree_scale(tree)<0.65: continue
		var d: Vector2 = Vector2(float(tree["x"])+float(tree["ox"]),float(tree["y"])+float(tree["oy"]))-origin
		if d.length()<best and (not character_view or d.length()<0.35 or facing.dot(d.normalized())>0.25):
			best=d.length()
			chosen=tree
	if not chosen.is_empty():
		world.cut_tree(actor,int(chosen["x"]),int(chosen["y"]))
		world.save_world()
		_refresh_ui()
		return
	if biome == "forest":
		world.news = "Aproxime-se de uma arvore adulta para cortar."
	elif biome == "grass":
		if not world.add_resource(actor,"wood",1):
			_refresh_ui()
			return
		world.news = str(actor["name"]) + " coletou galhos no campo."
	elif biome == "sand":
		if not world.add_resource(actor,"food",1):
			_refresh_ui()
			return
		world.news = str(actor["name"]) + " encontrou mantimentos no deserto."
	elif biome == "mountain":
		if not world.add_resource(actor,"stone",2):
			_refresh_ui()
			return
		world.news = str(actor["name"]) + " coletou 2 pedras."
	elif biome == "water":
		if not world.add_resource(actor,"water",2):
			_refresh_ui()
			return
		world.news = str(actor["name"]) + " coletou 2 unidades de agua."
	elif biome == "snow":
		if not world.add_resource(actor,"wood",1):
			_refresh_ui()
			return
		world.news = str(actor["name"]) + " guardou lenha para o frio."
	else:
		world.news = "Aqui nao ha recursos faceis de recolher."
	world.save_world()
	_refresh_ui()

func _show_inventory() -> void:
	var actor: Dictionary = world.get_actor(controlled_id)
	if actor.is_empty() and selected_person_id > 0:
		actor = world.get_person(selected_person_id)
	var dialog := AcceptDialog.new()
	dialog.title = "Inventario"
	dialog.ok_button_text = "Fechar"
	if actor.is_empty():
		dialog.dialog_text = "Selecione um habitante para abrir a mochila."
	else:
		var content := VBoxContainer.new()
		content.custom_minimum_size = Vector2(520, 280)
		var header := Label.new()
		header.text = "%s | Vida: %d/%d | Carga: %.1f/%.0f kg" % [str(actor.get("name", "Habitante")), int(float(actor.get("health", 100.0))),int(world.max_hp(actor)),world.carried_weight(actor),world.load_capacity(actor)]
		header.add_theme_font_size_override("font_size", 23)
		content.add_child(header)
		var grid := GridContainer.new()
		grid.columns = 4
		content.add_child(grid)
		for item in [["Madeira", "wood", Color("#ad8052")], ["Comida", "food", Color("#a8bb65")], ["Pedra", "stone", Color("#a2aaa8")], ["Agua", "water", Color("#56aace")]]:
			var slot := PanelContainer.new()
			slot.custom_minimum_size = Vector2(124, 84)
			var style := StyleBoxFlat.new()
			style.bg_color = Color("#2e3027")
			style.border_color = item[2]
			style.set_border_width_all(2)
			slot.add_theme_stylebox_override("panel", style)
			var label := Label.new()
			label.text = "%s\n%d" % [str(item[0]), int(actor.get(str(item[1]), 0))]
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 20)
			slot.add_child(label)
			grid.add_child(slot)
		if actor.has("town"):
			var town: Dictionary = world.get_town(int(actor["town"]))
			var stock := Label.new()
			stock.text = "Estoque da aldeia (separado da mochila)\nMadeira: %d   Comida: %d   Agua: %d" % [int(town.get("wood", 0)), int(town.get("food", 0)), int(town.get("water", 0))]
			content.add_child(stock)
			var extra:=Label.new()
			var extra_lines:Array[String]=[]
			for key in ["meat","hide","croc_hide","feather","bone","shell"]:
				if float(actor.get(key,0))>0: extra_lines.append(str(World.RESOURCE_NAMES[key])+": "+str(actor[key]))
			var cargo:Dictionary=actor.get("cargo",{})
			if not cargo.is_empty(): extra_lines.append("Carga: "+str(World.RESOURCE_NAMES.get(cargo["kind"],cargo["kind"]))+" "+str(cargo["amount"]))
			extra.text=" | ".join(extra_lines)
			content.add_child(extra)
			var transport:=Label.new()
			transport.text="Transporte: "+str({"hands":"Maos","basket":"Cesta","cart":"Carrinho"}.get(str(actor.get("transport","hands")),"Maos"))
			content.add_child(transport)
			var unload:=Button.new()
			unload.text="Depositar recursos na aldeia"
			content.add_child(unload)
			unload.pressed.connect(func() -> void:
				world.deposit_inventory(actor)
				world.save_world()
				_refresh_ui()
				dialog.queue_free()
			)
		dialog.add_child(content)
	add_child(dialog)
	dialog.popup_centered(Vector2i(570, 350))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)

func _show_details() -> void:
	if selected_beast_id>0:
		var beast:Dictionary=world.get_beast(selected_beast_id)
		if not beast.is_empty():
			_show_animal_card(beast)
			return
	var lines: Array[String] = []
	if selected_person_id > 0:
		var p: Dictionary = world.get_person(selected_person_id)
		if not p.is_empty():
			var home: Dictionary = world.get_town(int(p["town"]))
			lines.append("%s • %d anos" % [p["name"], int(float(p["age"]))])
			lines.append("Aldeia: %s  |  Profissao: %s" % [home.get("name", "?"), p.get("profession", "?")])
			world.init_traits(p)
			lines.append("Nivel %d  |  XP %.0f / %.0f" % [int(p["level"]),float(p["xp"]),world.xp_required(p)])
			lines.append("Vida: %d / %d  |  Funcao: %s" % [int(float(p["health"])),int(world.max_hp(p)),p["role"]])
			if float(p.get("poison_remaining",0))>0: lines.append("Envenenado: %.1f s restantes"%float(p["poison_remaining"]))
			lines.append("Forca: %.0f | Dano: %.1f | Defesa: %.0f" % [world.strength(p),world.attack_damage(p),world.defense(p)])
			lines.append("Diplomacia: %d | Inteligencia: %d | Agressividade: %d" % [int(p["diplomacy"]),int(p["intelligence"]),int(p["aggression"])])
			lines.append("Armadura: nivel %d | Arma: nivel %d | Ferramenta: nivel %d" % [int(p.get("armor",0)),int(p.get("weapon",0)),int(p.get("tool",0))])
			if p.has("armor_material"): lines.append("Material: "+str(World.RESOURCE_NAMES.get(str(p["armor_material"]),p["armor_material"])))
			if world.is_military(p): lines.append("Experiencia de guerra: %.0f / 250"%float(p.get("war_xp",0)))
			if p.has("shield_kind"): lines.append("Escudo: "+str(World.RESOURCE_NAMES.get(p["shield_kind"],p["shield_kind"])))
			if p.has("weapon_kind"): lines.append("Arma: "+str(World.RESOURCE_NAMES.get(p["weapon_kind"],p["weapon_kind"])))
			if p.has("tool_kind"): lines.append("Ferramenta: "+str(World.RESOURCE_NAMES.get(p["tool_kind"],p["tool_kind"])))
			if str(p.get("weapon_kind",""))=="bow": lines.append("Flechas: "+str(int(p.get("ammo",0))))
			lines.append("Saciedade: %d%%" % int(100-float(p.get("needs",{}).get("hunger",0))))
			if bool(p.get("witch_staff",false)): lines.append("Artefato unico: Cajado do brejo | Magia 24 | Recarga 4,5s")
			var father: Dictionary = world.get_person(int(p["father"]))
			var mother: Dictionary = world.get_person(int(p["mother"]))
			lines.append("Pai: %s  |  Mae: %s" % [father.get("name", "?"), mother.get("name", "?")])
			var mind: Dictionary = p.get("mind", {})
			if not mind.is_empty():
				lines.append("Coragem %d%%  |  Curiosidade %d%%  |  Lealdade %d%%" % [int(float(mind.get("bravery", 0.0)) * 100.0), int(float(mind.get("curiosity", 0.0)) * 100.0), int(float(mind.get("loyalty", 0.0)) * 100.0)])
			var memories: Array = p.get("memories", [])
			for m in memories.slice(maxi(memories.size() - 3, 0)):
				lines.append("• " + str(m.get("event", "")))
	elif selected_town_id > 0:
		var town: Dictionary = world.get_town(selected_town_id)
		if not town.is_empty():
			lines.append(str(town["name"]) + " • Era " + str(town["level"]))
			lines.append("Populacao: %d / %d vagas" % [world.active_population(selected_town_id),world.housing_capacity(town)])
			var kingdom:Dictionary=world.get_town(world.kingdom_id(town))
			lines.append("Reino: "+str(kingdom.get("name",town["name"])))
			lines.append("Experiencia militar: %.0f | Vitorias: %d | Doutrina: %s"%[float(town.get("war_xp",0)),int(town.get("victories",0)),["Basica","Coordenada","Veterana"][world.army_tactics(town)]])
			var counts:Dictionary={"royal":0,"soldier":0,"archer":0,"general":0}
			for soldier in world.army_members(town): counts[soldier["military_role"]]+=1
			lines.append("Escolta: %d | Guerreiros: %d | Arqueiros: %d | Generais: %d"%[counts["royal"],counts["soldier"],counts["archer"],counts["general"]])
			lines.append("Alimentos %d  |  Madeira %d" % [int(float(town["food"])), int(float(town["wood"]))])
			lines.append("Colheita: %.0f%% | Peixe: %.0f | Moral: %.0f%%"%[world.harvest_factor(town)*100.0,float(town.get("fish",0)),float(town.get("morale",60))])
			if float(town["food"])<world.active_population(selected_town_id)*1.5: lines.append("Racionamento: prioridade à família real e ao exército")
			if world.blockade_active(town): lines.append("Cerco ativo: abastecimento externo interrompido")
			for event in town.get("historical_events", []):
				lines.append("• " + str(event.get("event", "")))
	else:
		lines.append("Toque em um habitante ou aldeia para ver suas informacoes.")
	var dialog := AcceptDialog.new()
	dialog.title = "Cronicas do Legado"
	if selected_person_id>0 and not world.get_person(selected_person_id).is_empty():
		var person:Dictionary=world.get_person(selected_person_id)
		var body:=VBoxContainer.new()
		body.custom_minimum_size=Vector2(620,420)
		body.add_theme_constant_override("separation",8)
		_add_stat_bar(body,"Vida",float(person["health"]),world.max_hp(person),Color("#b95850"))
		if float(person.get("poison_remaining",0))>0: _add_stat_bar(body,"Veneno (s)",float(person["poison_remaining"]),5.0,Color("#8eae4d"))
		_add_stat_bar(body,"Saciedade",100.0-float(person.get("needs",{}).get("hunger",0)),100.0,Color("#d5a455"))
		_add_stat_bar(body,"Experiencia",float(person.get("xp",0)),world.xp_required(person),Color("#6db7b3"))
		var description:=Label.new()
		description.text="\n".join(lines)
		description.add_theme_font_size_override("font_size",17)
		body.add_child(description)
		dialog.add_child(body)
	else: dialog.dialog_text="\n".join(lines)
	dialog.confirmed.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(620, 390))

func _check_updates() -> void:
	if is_instance_valid(update_manager):
		update_manager.check_now()

func _save_now() -> void:
	world.news = "Mundo salvo no aparelho." if world.save_world() else "Falha ao salvar o mundo."
	_refresh_ui()

func _new_world() -> void:
	var dialog:=ConfirmationDialog.new()
	dialog.title="Criar novo mundo"
	dialog.dialog_text="O mundo atual sera preservado. Escolha um nome para o novo mundo."
	dialog.ok_button_text="Criar e jogar"
	dialog.cancel_button_text="Cancelar"
	var name_input:=LineEdit.new()
	name_input.placeholder_text="Nome do mundo"
	name_input.text="Novo mundo"
	name_input.max_length=40
	name_input.custom_minimum_size=Vector2(420,48)
	dialog.add_child(name_input)
	add_child(dialog)
	dialog.confirmed.connect(func():
		var name:String=name_input.text.strip_edges()
		if name.is_empty(): name="Novo mundo"
		_create_saved_world(name)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(490,190))


func _draw_palisade(p:Vector2,u:float,axis:String,segment:Dictionary) -> void:
	if not MAP_AREA.grow(-u).has_point(p): return
	var step_dir:=Vector2.RIGHT if axis=="h" else Vector2.DOWN
	var a:Vector2=p-step_dir*u*0.5
	var b:Vector2=p+step_dir*u*0.5
	var gate:bool=bool(segment.get("gate",false))
	var max_hp:float=float(segment.get("max_health",100.0 if gate else 150.0))
	var hp:float=float(segment.get("health",max_hp))
	var ratio:float=clampf(hp/maxf(1.0,max_hp),0,1)
	if gate:
		for side in [-1.0,1.0]:
			var post:Vector2=p+step_dir*u*0.45*side
			draw_rect(Rect2(post-Vector2(u*0.08,u*0.72),Vector2(u*0.16,u*0.72)),Color("#563925"))
			draw_rect(Rect2(post-Vector2(u*0.04,u*0.70),Vector2(u*0.08,u*0.68)),Color("#b78b53"))
		for i in range(6):
			var q:Vector2=p+step_dir*u*(float(i)/6.0-0.42)
			draw_rect(Rect2(q-Vector2(u*0.06,u*0.52),Vector2(u*0.13,u*0.52)),Color("#9a6838" if i%2==0 else "#79512d"))
		draw_line(a-Vector2(0,u*0.18),b-Vector2(0,u*0.18),Color("#3b3833"),maxf(2,u*0.06))
		draw_line(a-Vector2(0,u*0.43),b-Vector2(0,u*0.43),Color("#3b3833"),maxf(2,u*0.06))
		_draw_wall_health(p,u,ratio,true)
		return
	draw_line(a-Vector2(0,u*0.18),b-Vector2(0,u*0.18),Color("#59412b"),maxf(2,u*0.09))
	draw_line(a-Vector2(0,u*0.40),b-Vector2(0,u*0.40),Color("#87572e"),maxf(2,u*0.08))
	for i in range(6):
		var q:Vector2=(p+step_dir*u*(float(i)/6.0-0.42)).round()
		var w:float=u*0.13
		var h:float=u*(0.58+float(i%2)*0.04)
		draw_rect(Rect2(q-Vector2(w*0.5,h),Vector2(w,h)),Color("#4a3324"))
		draw_rect(Rect2(q-Vector2(w*0.36,h),Vector2(w*0.70,h*0.94)),Color("#a16e3a"))
		draw_colored_polygon(PackedVector2Array([q-Vector2(w*0.5,h),q-Vector2(0,h+u*0.14),q+Vector2(w*0.5,-h)]),Color("#c6a06a"))
		draw_line(q-Vector2(w*0.25,h*0.9),q-Vector2(w*0.25,u*0.05),Color("#d1a66e"),1.0)
		if ratio<0.65 and i%2==0:
			draw_line(q-Vector2(w*0.25,h*0.56),q+Vector2(w*0.2,-h*0.37),Color("#402820"),maxf(1,u*0.025))
	_draw_wall_health(p,u,ratio,false)

func _draw_wall_health(p:Vector2,u:float,ratio:float,gate:bool) -> void:
	if ratio>=0.999: return
	var bar:=Rect2(p-Vector2(u*0.35,u*(0.85 if gate else 0.90)),Vector2(u*0.70,maxf(2.0,u*0.06)))
	draw_rect(bar,Color("#2c211c"))
	draw_rect(Rect2(bar.position,Vector2(bar.size.x*ratio,bar.size.y)),Color("#83ae53") if ratio>0.5 else Color("#df8050"))

func _draw_project_marker(site:Dictionary,p:Vector2,unit:float) -> void:
	var kind:String=str(site["kind"])
	var required:Dictionary=site.get("required",{})
	var delivered:Dictionary=site.get("delivered",{})
	var total:float=maxf(1.0,float(required.get("wood",0))+float(required.get("stone",0)))
	var received:float=float(delivered.get("wood",0))+float(delivered.get("stone",0))
	var portion:float=clampf(received/total,0,1)
	var ratio:float=clampf(float(site.get("progress",0))/maxf(1,float(site["duration"])),0,1)
	var icon:String={"castle":"castle","upgrade":"hut","house":"hut","farm":"farm","campfire":"fire","oven":"oven","forge":"forge","crossing":"bridge"}.get(kind,"hut")
	var badge_pos:Vector2=p-Vector2(0,unit*0.72)
	var icon_size:float=clampf(unit*0.20,8.0,16.0)
	var remaining_wood:int=maxi(0,ceili(float(required.get("wood",0))-float(delivered.get("wood",0))))
	var remaining_stone:int=maxi(0,ceili(float(required.get("stone",0))-float(delivered.get("stone",0))))
	if remaining_wood>0 or remaining_stone>0:
		var panel:=Rect2(badge_pos-Vector2(43,15),Vector2(86,18))
		draw_rect(panel,Color("#28241e",0.92))
		var q:Vector2=panel.position+Vector2(9,8)
		if remaining_wood>0:
			_draw_landscape_object("log_bundle",q,icon_size)
			draw_string(ThemeDB.fallback_font,q+Vector2(9,4),str(remaining_wood),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#ffe0aa"))
		if remaining_stone>0:
			q=panel.position+Vector2(50,8)
			_draw_landscape_object("rock",q,icon_size)
			draw_string(ThemeDB.fallback_font,q+Vector2(9,4),str(remaining_stone),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#dfe1d6"))
	for n in range(int(ceil(portion*6))):
		draw_rect(Rect2(p+Vector2((n%3-1)*unit*0.15,(n/3-0.3)*unit*0.12),Vector2(unit*0.13,unit*0.08)),Color("#ad8150"))
	var bar:=Rect2(p-Vector2(unit*0.30,unit*0.38),Vector2(unit*0.60,3.0))
	draw_rect(bar,Color("#362b23"))
	draw_rect(Rect2(bar.position,Vector2(bar.size.x*ratio,bar.size.y)),Color("#e8bd65"))
	draw_string(ThemeDB.fallback_font,p+Vector2(-unit*0.48,unit*0.36),"%d/%d"%[int(received),int(total)],HORIZONTAL_ALIGNMENT_CENTER,unit,12,Color("#ffedb8"))

const HELD_ATLAS := preload("res://assets/landscape/held_items.png")
const HELD_ITEM_TILE := {"wood_spear":0, "spear":1, "iron_spear":2, "sword":3, "steel_sword":4, "bow":5, "club":6, "wood_shield":7, "iron_shield":8, "pickaxe":9, "iron_pickaxe":10, "hoe":11, "axe":12, "rod":13}

func _draw_held_item(kind: String, hand: Vector2, scale_px: float, face: float, angle: float, grip_height: int = 22) -> void:
	if not HELD_ITEM_TILE.has(kind): return
	var tile := int(HELD_ITEM_TILE[kind])
	var source := Rect2(tile % 8 * 24, floori(tile / 8.0) * 32, 24, 32)
	draw_set_transform(hand, angle * face, Vector2(face, 1) * scale_px)
	draw_texture_rect_region(HELD_ATLAS, Rect2(-12, -grip_height, 24, 32), source)
	draw_set_transform(Vector2.ZERO)

func _draw_equipment(person: Dictionary, center: Vector2, size: float, bounce: float, face: float = 1.0) -> void:
	if float(person["age"]) < 16 or not MAP_AREA.grow(-size).has_point(center): return
	var action: String = world.visible_action(person)
	var hand := center + Vector2(face * size * 0.19, -size * 0.31 - bounce)
	var scale_px := size / 39.0
	var swing := sin(world.swamp_clock * 9.0 + int(person["id"]))
	if world.is_military(person) or action == "combat" or not str(person.get("weapon_kind", "")).is_empty() and action.is_empty():
		var shield_hand := center + Vector2(-face * size * 0.17, -size * 0.30 - bounce)
		_draw_held_item(str(person.get("shield_kind", "")), shield_hand, scale_px, face, 0.0, 17)
		var angle := 0.15 + swing * 0.95 if action == "combat" else 0.20
		_draw_held_item(str(person.get("weapon_kind", "")), hand, scale_px, face, angle)
		return
	var tool := str(person.get("tool_kind", ""))
	var angle := 0.18
	if action in ["mining", "chopping", "building", "farming", "fishing", "smithing"]:
		angle += swing * (0.12 if action == "fishing" else 0.78)
	elif not action.is_empty() or not person.get("cargo", {}).is_empty():
		return
	_draw_held_item(tool, hand, scale_px, face, angle)
	if action == "fishing" and tool == "rod":
		var tip := hand + Vector2(0, -22 * scale_px).rotated(angle * face)
		if person.has("fishing_water_x") and person.has("fishing_water_y"):
			var target:=_world_to_screen(Vector2(float(person["fishing_water_x"])+0.5,float(person["fishing_water_y"])+0.5))
			if MAP_AREA.has_point(target) and target.distance_to(center)<size*3.0:
				draw_line(tip,target,Color("#d4e0d5"),1.0)
				draw_rect(Rect2(target-Vector2(1.5,1.5)*zoom,Vector2(3,3)*zoom),Color("#d96f4d"))


func _toggle_spawn() -> void:
	if not spawn_species.is_empty():
		spawn_species=""
		world.news="Observando o mundo."
		_refresh_ui()
		return
	_show_spawn_menu()

func _show_spawn_menu() -> void:
	_close_actor_card()
	var dialog:=AcceptDialog.new()
	dialog.title="Criar vida"
	dialog.ok_button_text="Fechar"
	var body:=VBoxContainer.new()
	body.custom_minimum_size=Vector2(640,360)
	body.add_theme_constant_override("separation",9)
	var hint:=Label.new()
	hint.text="Escolha uma especie. Depois, cada toque no mapa cria um ser."
	body.add_child(hint)
	var grid:=GridContainer.new()
	grid.columns=3
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",8)
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(655,420)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	body.add_child(scroll)
	var ordered:Array=World.SPAWN_NAMES.keys()
	for key in World.ANCESTRAL_NAMES.keys(): ordered.erase(key)
	ordered.append_array(World.ANCESTRAL_NAMES.keys())
	for species in ordered:
		var key:String=str(species)
		if key=="witch":
			var section:=Label.new()
			section.text="Ancestrais"
			grid.add_child(section)
			grid.add_child(Control.new())
			grid.add_child(Control.new())
		var button:=Button.new()
		button.text=str(World.SPAWN_NAMES[key])
		button.custom_minimum_size=Vector2(200,47)
		button.add_theme_font_size_override("font_size",19)
		button.pressed.connect(func() -> void:
			spawn_species=key
			controlled_id=0
			character_view=false
			selected_person_id=0
			selected_beast_id=0
			selected_town_id=0
			_sync_character_ui()
			world.news="Escolha um terreno adequado."
			_refresh_ui()
			dialog.queue_free()
		)
		grid.add_child(button)
	dialog.add_child(body)
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(710,530))

func _draw_mosquitoes(p:Vector2,seed:int,u:float) -> void:
	if u<24.0: return
	for i in range(3):
		var a:float=world.swamp_clock*3.5+float(seed+i*17)
		var q:Vector2=(p+Vector2(sin(a*1.9)*u*0.25,cos(a*1.4)*u*0.15)).round()
		draw_rect(Rect2(q,Vector2(1.0,2.0)),Color("#302b20"))
		if int(a*18)%2==0: draw_rect(Rect2(q-Vector2(1,0),Vector2(3,1)),Color("#aab49a",0.75))

func _draw_swamp_creatures() -> void:
	var witch:Dictionary=world.swamp_witch
	if bool(witch.get("alive",false)):
		var p:Vector2=_world_to_screen(Vector2(float(witch["x"])+0.5,float(witch["y"])+0.5))
		var summon:float=float(witch.get("summon_anim",0))
		var lift:float=clampf(minf((1.2-summon)/0.30,summon/0.30),0,1) if summon>0 else 0.0
		var pose:int=2 if lift>=0.65 else (1 if lift>0.15 else 0)
		_draw_walk_sprite(WITCH_APPROVED,Rect2(pose*96,0,96,96),p,43.0*zoom,1.0,0.0,false,0.0)
		if MAP_AREA.grow(-30*zoom).has_point(p):
			var bar:=Rect2(p+Vector2(-16,-37)*zoom,Vector2(32,4)*zoom)
			draw_rect(bar,Color("#2a202d"))
			draw_rect(Rect2(bar.position,Vector2(bar.size.x*float(witch["health"])/500.0,bar.size.y)),Color("#a16dc7"))
	for kind in world.ancestrals:
		var ancient:Dictionary=world.ancestrals[kind]
		if not bool(ancient.get("alive",false)): continue
		var center:Vector2=_world_to_screen(Vector2(float(ancient["x"])+0.5,float(ancient["y"])+0.5))
		var size:float=(106.0 if kind=="golem" else 66.0)*zoom
		var moving:bool=bool(ancient.get("moving",false))
		var striking:bool=float(ancient.get("hit_anim_until",0))>world.swamp_clock
		var atlas:Texture2D=GOLEM_APPROVED if kind=="golem" else FENRIR_APPROVED
		var phase:float=float(ancient.get("walk_phase",0))
		var frame:int=2 if striking else (int(phase/TAU*4.0)%4 if moving else 0)
		_contact_shadow(center,size*0.28,size*0.07)
		_draw_walk_sprite(atlas,Rect2(frame*96,0,96,96),center,size,float(ancient.get("face",1.0)),phase,false,absf(sin(phase))*size*0.05 if kind=="fenrir" and moving else 0.0)
		if striking and MAP_AREA.grow(-20*zoom).has_point(center):
			var fade:float=clampf((float(ancient["hit_anim_until"])-world.swamp_clock)/0.35,0,1)
			for i in range(7):
				var angle:float=float(i)*TAU/7.0
				var particle:Vector2=center+Vector2(cos(angle),sin(angle)*0.45)*(12.0+18.0*(1.0-fade))*zoom
				draw_rect(Rect2(particle,Vector2.ONE*maxf(1.0,3.0*zoom*fade)),Color(0.65,0.55,0.42,fade) if kind=="golem" else Color(0.65,0.88,1.0,fade))
		if MAP_AREA.grow(-30*zoom).has_point(center):
			var life:=Rect2(center+Vector2(-size*0.31,-size*0.98),Vector2(size*0.62,maxf(2,zoom*2)))
			draw_rect(life,Color("#292b32"))
			draw_rect(Rect2(life.position,Vector2(life.size.x*clampf(float(ancient["health"])/float(ancient["max_health"]),0,1),life.size.y)),Color("#a3dce7" if kind=="fenrir" else "#c3874c"))
	for spider in world.swamp_spiders:
		var p:Vector2=_world_to_screen(Vector2(float(spider["x"])+0.5,float(spider["y"])+0.5))
		var emerge:float=float(spider.get("emerge",0))
		var s:float=12.5*zoom*(1.0-0.35*clampf(emerge/0.6,0,1))
		var frame:int=int(world.swamp_clock*5+float(spider["id"]))%3
		if emerge>0: frame=0
		_draw_walk_sprite(SPIDERS_APPROVED,Rect2(frame*48,0,48,48),p,s,1.0,0.0,false,0.0)
	for bolt in world.magic_bolts:
		var p:Vector2=_world_to_screen(Vector2(float(bolt["x"])+0.5,float(bolt["y"])+0.5))
		if MAP_AREA.grow(-12).has_point(p):
			if bool(bolt.get("arrow",false)):
				var target:Dictionary=world.get_person(int(bolt["target"]))
				if not target.is_empty():
					var direction:Vector2=(_world_to_screen(Vector2(float(target["x"])+0.5,float(target["y"])+0.5))-p).normalized()
					draw_line(p-direction*7*zoom,p+direction*3*zoom,Color("#c7a16b"),1.5)
			else:
				var direction:=Vector2.RIGHT
				var target:Dictionary=world.get_person(int(bolt.get("target",0))) if str(bolt.get("kind",""))=="human" else {}
				if not target.is_empty(): direction=(_world_to_screen(Vector2(float(target["x"])+0.5,float(target["y"])+0.5))-p).normalized()
				var normal:=Vector2(-direction.y,direction.x)
				for i in range(8):
					var f:float=float(i)/8.0
					var q:Vector2=(p-direction*f*18*zoom+normal*sin(world.swamp_clock*15.0+float(i))*2.0*zoom*f).round()
					var side:float=maxf(1.0,(3.0-f*2.0)*zoom)
					draw_rect(Rect2(q-Vector2.ONE*side*0.5,Vector2.ONE*side),Color(0.30,0.95,0.35,1.0-f) if bool(bolt.get("witch_magic",false)) else Color(0.66,0.28,0.94,1.0-f))
				draw_circle(p,5*zoom,Color(0.32,0.85,0.20,0.28) if bool(bolt.get("witch_magic",false)) else Color(0.49,0.16,0.8,0.28))
				draw_circle(p,3.3*zoom,Color("#88ff56") if bool(bolt.get("witch_magic",false)) else Color("#a95df3"))
				draw_rect(Rect2(p-Vector2.ONE*1.5*zoom,Vector2.ONE*3*zoom),Color("#fff0ff"))

func _draw_selected_life(person:Dictionary,center:Vector2) -> void:
	var bar:=Rect2(center+Vector2(-15,-29)*zoom,Vector2(30,4)*zoom)
	if not MAP_AREA.encloses(bar): return
	draw_rect(bar,Color("#3b2924"))
	draw_rect(Rect2(bar.position,Vector2(bar.size.x*clampf(float(person["health"])/world.max_hp(person),0,1),bar.size.y)),Color("#79b45b"))

func _add_stat_bar(body:VBoxContainer,label:String,value:float,maximum:float,color:Color) -> void:
	var title:=Label.new()
	title.text="%s   %d / %d"%[label,int(value),int(maximum)]
	body.add_child(title)
	var bar:=ProgressBar.new()
	bar.max_value=maxf(1,maximum)
	bar.value=value
	bar.show_percentage=false
	bar.custom_minimum_size=Vector2(0,12)
	var background:=StyleBoxFlat.new()
	background.bg_color=Color("#302d25")
	background.set_corner_radius_all(4)
	var fill:=StyleBoxFlat.new()
	fill.bg_color=color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background",background)
	bar.add_theme_stylebox_override("fill",fill)
	body.add_child(bar)

func _close_actor_card() -> void:
	if is_instance_valid(actor_card):
		actor_card.hide()
		actor_card.queue_free()
	actor_card = null

func _card_portrait(subject: Dictionary, human: bool) -> Texture2D:
	if human:
		return _human_portrait(subject)
	var key := str(subject["species"])
	var species: String = {"Urso": "bear", "Lobo": "wolf"}.get(key, key)
	var row := ANIMAL_ROWS.find(species)
	if row < 0: return null
	var portrait := AtlasTexture.new()
	portrait.atlas = FAUNA_APPROVED
	portrait.region = Rect2(0,row*48,48,48)
	return portrait

func _open_actor_card(subject: Dictionary, human: bool) -> void:
	_close_actor_card()
	actor_card = ActorCard.new()
	add_child(actor_card)
	actor_card.position = MAP_AREA.position + Vector2(12, 12)
	actor_card.display(world, subject, human, _card_portrait)
	actor_card.chronicles_requested.connect(_show_details)

func _show_animal_card(animal: Dictionary) -> void:
	_open_actor_card(animal, false)

func _draw_resource_drops() -> void:
	for drop in world.resource_drops:
		if drop["items"].is_empty(): continue
		var center:Vector2=_world_to_screen(Vector2(float(drop["x"])+0.5,float(drop["y"])+0.5))
		if not MAP_AREA.grow(-12*zoom).has_point(center): continue
		var i:int=0
		for key in drop["items"].keys():
			var color:Color=Color("#d8c9a3")
			match str(key):
				"meat": color=Color("#b85c50")
				"croc_hide": color=Color("#71894b")
				"hide": color=Color("#a17b4b")
				"feather": color=Color("#e4dbca")
				"shell": color=Color("#7c7750")
			var q:=center+Vector2(float(i%3)*5-5,float(i/3)*5)*zoom
			draw_rect(Rect2(q,Vector2(5,4)*zoom),Color("#48372a"))
			draw_rect(Rect2(q,Vector2(4,3)*zoom),color)
			i+=1

func _inspect_building(point:Vector2) -> bool:
	for town in world.towns:
		var stocks:Dictionary=world.building_stocks(town)
		for key in stocks.keys():
			if key=="camp": continue
			if point.distance_to(world.storage_position(town,str(key)))>(1.25 if key=="castle" else 0.60): continue
			var dialog:=AcceptDialog.new()
			dialog.title="Castelo nível "+str(world.castle_level(town)) if key=="castle" else "Casa "+str(int(str(key).trim_prefix("house_"))+1)
			var lines:Array[String]=[str(town["name"]),"Estoque desta construcao"]
			if key!="castle":
				var levels:Array=world.house_levels(town)
				lines.append("Nivel "+str(levels[int(str(key).trim_prefix("house_"))]))
			var stock:Dictionary=stocks[key]
			for kind in World.RESOURCE_NAMES.keys():
				if float(stock.get(kind,0))>0: lines.append(str(World.RESOURCE_NAMES[kind])+": "+str(snappedf(float(stock[kind]),0.1)))
			if lines.size()==(2 if key=="castle" else 3): lines.append("Estoque vazio")
			dialog.dialog_text="\n".join(lines)
			add_child(dialog)
			dialog.confirmed.connect(dialog.queue_free)
			dialog.canceled.connect(dialog.queue_free)
			dialog.popup_centered(Vector2i(440,400))
			return true
	return false

func _natural_tree_key(tree:Dictionary) -> String:
	var x:int=int(tree["x"])
	var y:int=int(tree["y"])
	if world.swamp_at(Vector2(x,y)): return "swamp_tree_"+str(posmod(x*13+y*7,3))
	var winter:bool=int(world.day/90.0)%4==3 or str(world.tiles[y][x])=="snow"
	if winter: return "pine_snow" if bool(tree["pine"]) else "tree_snow"
	return "pine" if bool(tree["pine"]) else "tree"

func _draw_natural_animal(animal:Dictionary,p:Vector2) -> void:
	var species:String=str(animal["species"])
	var s:float=zoom*float({"deer":27,"rabbit":17,"snow_hare":17,"chicken":16,"capybara":23,"duck":18,"crocodile":29,"frog":14,"camel":30,"heron":22,"boar":24,"fox":21,"turtle":17,"lizard":16,"cow":28,"sheep":23,"goat":24,"horse":30,"pig":22,"dog":21,"cat":17,"eagle":23,"owl":19,"crow":19,"bat":15,"penguin":19,"wolf":26,"bear":33}.get(species,19))
	_draw_fauna(animal,p,s,species)


func _track_visual_motion(delta:float) -> void:
	for group in [world.people,world.wildlife,world.beasts]:
		for actor in group:
			if not bool(actor.get("alive",true)): continue
			var id:int=int(actor["id"])
			var pos:=Vector2(float(actor["x"]),float(actor["y"]))
			var state:Dictionary=visual_motion.get(id,{"pos":pos,"phase":0.0,"face":1.0})
			var previous:Vector2=state["pos"]
			var moved:Vector2=pos-previous
			state["moving"]=moved.length()>0.0001 and delta>0
			if absf(moved.x)>0.0001: state["face"]=-1.0 if moved.x<0 else 1.0
			var gait:float=7.0 if actor.has("town") else (6.4 if str(actor.get("species","")) in ["boar","capybara","Urso","crocodile","camel","cow","horse"] else 11.0)
			state["phase"]=fposmod(float(state["phase"])+minf(moved.length()*gait,delta*7.0),TAU)
			state["pos"]=pos
			visual_motion[id]=state

func _contact_shadow(p:Vector2,rx:float,ry:float) -> void:
	if not MAP_AREA.grow(-rx).has_point(p): return
	draw_set_transform(p,0,Vector2(1.0,ry/maxf(0.1,rx)))
	draw_circle(Vector2.ZERO,rx,Color("#17251c",0.18))
	draw_circle(Vector2.ZERO,rx*0.73,Color("#17251c",0.15))
	draw_set_transform(Vector2.ZERO)

# Separa os pes do corpo para que a passada alterne com a distancia percorrida.
func _draw_walk_sprite(texture:Texture2D,source:Rect2,p:Vector2,s:float,face:float,phase:float,moving:bool,bounce:float) -> void:
	# Nao dividir pernas em blocos: a silhueta inteira permanece conectada.
	var tilt:float=sin(phase)*0.025 if moving else 0.0
	var dest:=Rect2(-s*0.5,-s*0.91-bounce,s,s)
	if not MAP_AREA.encloses(Rect2(p+dest.position,dest.size)): return
	draw_set_transform(p,tilt,Vector2(face,1))
	draw_texture_rect_region(texture,dest,source)
	draw_set_transform(Vector2.ZERO)


func _draw_animated_beast(b:Dictionary,p:Vector2,key:String) -> void:
	_draw_fauna(b,p,zoom*(33.0 if key=="bear" else 26.0),key)


func _prepare_people_variants() -> void:
	people_variants.clear()
	var base:Texture2D=landscape_objects["reference_characters"]
	people_variants.append(base)
	var original:Image=base.get_image()
	var palette:Array[Color]=[Color("#597a56"),Color("#546d91"),Color("#96654b"),Color("#887942"),Color("#866b82"),Color("#7a8c88"),Color("#ad854e"),Color("#6b6856"),Color("#705047")]
	for color in palette:
		var img:Image=original.duplicate()
		for index in range(4):
			var region:Image=original.get_region(Rect2i(index*48,0,48,48))
			var used:Rect2i=region.get_used_rect()
			for y in range(used.position.y,used.end.y):
				for x in range(used.position.x,used.end.x):
					var pixel:Color=region.get_pixel(x,y)
					if pixel.a<0.5: continue
					var fy:float=float(y-used.position.y)/maxf(1.0,float(used.size.y))
					var fx:float=float(x-used.position.x)/maxf(1.0,float(used.size.x))
					if fy<0.32 and pixel.v<0.47 and pixel.s>0.12:
						var hair_color:Color=palette[(people_variants.size()+index*2)%palette.size()].darkened(0.45)
						img.set_pixel(index*48+x,y,pixel.lerp(hair_color,0.45))
					elif fy<0.45 and pixel.r>pixel.g*1.08 and pixel.g>pixel.b*1.08 and pixel.v>0.48:
						var skin_shade:float=float(people_variants.size()%5)*0.075
						img.set_pixel(index*48+x,y,pixel.darkened(skin_shade))
					elif fy>0.43 and fy<0.76 and fx>0.20 and fx<0.80 and pixel.s>0.18 and pixel.v>0.23 and pixel.v<0.82:
						var changed:=Color.from_hsv(color.h,color.s,pixel.v,pixel.a)
						img.set_pixel(index*48+x,y,pixel.lerp(changed,0.72))
		people_variants.append(ImageTexture.create_from_image(img))

func _draw_animal_frames(species:String,p:Vector2,s:float,face:float,phase:float,moving:bool) -> void:
	var key:String=species+"_walk"
	if not landscape_objects.has(key):
		landscape_objects[key]=load("res://assets/landscape/"+key+".svg")
	var texture:Texture2D=landscape_objects[key]
	if texture==null: return
	var frame:int=int(fposmod(phase,TAU)/TAU*4) if moving else 0
	_draw_walk_sprite(texture,Rect2(frame*64,0,64,64),p,s,face,phase,false,0.0)

func _resize_map() -> void:
	var width:float=maxf(1280.0,get_viewport_rect().size.x)
	var previous:float=screen_width
	screen_width=width
	MAP_AREA=Rect2(12,78,width-24,626)
	for control in right_hud: control.position.x+=width-previous
	if is_instance_valid(action_button): action_button.position.x+=width-previous
	if is_instance_valid(inventory_button): inventory_button.position.x+=width-previous
	_clamp_map()
	if home_open: _layout_home()
	queue_redraw()

const BUILDINGS_APPROVED:Texture2D=preload("res://assets/landscape/construcoes_aprovadas.png")
func _draw_building_art(p:Vector2,size:float,stage:int,biome:String) -> void:
	var row:int=int({"snow":1,"sand":2,"swamp":3}.get(biome,0))
	var source:=Rect2(clampi(stage,0,4)*96,row*96,96,96)
	var dest:=Rect2(p-Vector2(size*0.5,size*0.87),Vector2.ONE*size)
	_contact_shadow(p+Vector2(size*0.03,size*0.075),size*0.42,size*0.095)
	var clipped:Rect2=dest.intersection(MAP_AREA)
	if clipped.has_area():
		draw_texture_rect_region(BUILDINGS_APPROVED,clipped,Rect2(source.position+(clipped.position-dest.position)/size*96.0,clipped.size/size*96.0))

func _draw_depth_entities() -> void:
	scene_depth.sort_custom(func(a,b): return float(a["y"])<float(b["y"]))
	for entry in scene_depth:
		var p:Vector2=entry["p"]
		match str(entry["kind"]):
			"house":
				var size:float=float(entry["size"])
				var era:int=int(entry["era"])
				# Dois desenhos distintos recortados da referencia de casas aprovada.
				var grown:float=size*(1.0+float(era-1)*0.045)
				_draw_building_art(p+Vector2(0,grown*0.28),grown,0 if era==1 else 1,str(entry.get("biome","grass")))
			"castle": _draw_building_art(p,float(entry["size"]),int(entry["stage"]),str(entry["biome"]))
			"tree": _draw_rooted_tree(str(entry["key"]),p,float(entry["size"]))
			"person": _draw_person_variant(entry["actor"],p)
			"animal": _draw_natural_animal(entry["actor"],p)
			"beast": _draw_animated_beast(entry["actor"],p,str(entry["key"]))

func prepare_update_restart() -> bool:
	if not home_open and not world.save_world(): return false
	update_previous_speed=world.speed
	world.speed=0
	update_restarting=true
	return true

func cancel_update_restart() -> void:
	update_restarting=false
	world.speed=update_previous_speed

func _draw_combat_feedback() -> void:
	for event in world.combat_feedback:
		var remaining:float=float(event["expires"])-world.swamp_clock
		if remaining<=0: continue
		var p:Vector2=_world_to_screen(Vector2(float(event["x"])+0.5,float(event["y"])+0.5))
		if not MAP_AREA.grow(-35).has_point(p): continue
		var age:float=1.1-remaining
		if remaining>0.85:
			var fade:float=clampf((remaining-0.85)/0.25,0,1)
			var impact:Vector2=p-Vector2(0,10*zoom)
			for i in range(5):
				var angle:float=float(i)*TAU/5.0+0.45
				var ray:=Vector2(cos(angle),sin(angle))
				var start:Vector2=impact+ray*(4+age*20)*zoom
				var finish:Vector2=start+ray*(3+fade*4)*zoom
				draw_line(start,finish,Color(1.0,0.38,0.22,fade),maxf(1,zoom*1.5))
		var amount:int=maxi(1,roundi(float(event["amount"])))
		var damage_text:String="-%d"%amount
		var font_size:int=maxi(12,int(15*zoom))
		var alpha:float=clampf(remaining*3,0,1)
		var width:float=ThemeDB.fallback_font.get_string_size(damage_text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		var label_pos:Vector2=p+Vector2(-width*0.5,-(24+age*19)*zoom)
		draw_string_outline(ThemeDB.fallback_font,label_pos,damage_text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,maxi(2,int(zoom*2)),Color(0.12,0.08,0.05,alpha))
		draw_string(ThemeDB.fallback_font,label_pos,damage_text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(1.0,0.94,0.76,alpha))

func _draw_swimming_animal(species:String,indices:Dictionary,p:Vector2,s:float,face:float,depth:float,moving:bool) -> void:
	var texture:Texture2D
	var source:Rect2
	var frame:int=int(world.swamp_clock*4.0)%4 if moving else 0
	if indices.has(species):
		texture=landscape_objects["reference_characters"]
		source=Rect2(int(indices[species])*48,0,48,48)
	else:
		var key:String=species+"_walk"
		if not landscape_objects.has(key): landscape_objects[key]=load("res://assets/landscape/"+key+".svg")
		texture=landscape_objects[key]
		source=Rect2(frame*64,0,64,64)
	if texture!=null: _draw_water_actor(texture,source,p,s,face,depth,species,moving)

func _draw_water_actor(texture:Texture2D,source:Rect2,p:Vector2,s:float,face:float,depth:float,species:String,moving:bool) -> void:
	if not MAP_AREA.grow(-s).has_point(p): return
	var cycle:float=world.swamp_clock*(4.8 if species in ["turtle","camel","bear"] else 7.5)
	var deep:bool=depth>=0.60
	# A altura visivel e a remada variam por especie; preserva o rosto e a roupa de cada humano.
	var fraction:float=0.78
	if deep:
		fraction=float({"human":0.51,"deer":0.65,"rabbit":0.72,"snow_hare":0.72,"chicken":0.75,"capybara":0.68,"duck":0.79,"crocodile":0.83,"frog":0.79,"heron":0.70,"camel":0.65,"boar":0.70,"fox":0.72,"turtle":0.79,"lizard":0.79,"wolf":0.68,"bear":0.69}.get(species,0.72))
	else: fraction=lerpf(0.91,0.76,depth)
	var bob:float=sin(cycle)*s*0.022 if moving and deep else 0.0
	var cut:Rect2=Rect2(source.position,Vector2(source.size.x,source.size.y*fraction))
	var dest:Rect2=Rect2(-s*0.5,-s*fraction+bob,s,s*fraction)
	draw_set_transform(p,0,Vector2(face,1))
	draw_texture_rect_region(texture,dest,cut)
	if deep and moving:
		var reach:float=sin(cycle)*s*0.16
		if species=="human":
			# Bracos alternados entram e saem da agua; sem arma ou ferramenta na mao.
			draw_line(Vector2(s*0.10,-s*0.13),Vector2(s*0.27+reach,-s*0.035),Color("#73523d"),maxf(2,s*0.085))
			draw_line(Vector2(-s*0.11,-s*0.07),Vector2(-s*0.25-reach,s*0.015),Color("#c39770"),maxf(1,s*0.052))
		elif species not in ["duck","crocodile","turtle","frog","lizard"]:
			var paddle:float=sin(cycle)*s*0.12
			draw_line(Vector2(-s*0.14,-s*0.055),Vector2(-s*0.18+paddle,s*0.07),Color(0.21,0.29,0.27,0.68),maxf(1,s*0.06))
			draw_line(Vector2(s*0.12,-s*0.055),Vector2(s*0.16-paddle,s*0.06),Color(0.21,0.29,0.27,0.68),maxf(1,s*0.06))
		elif species in ["crocodile","lizard","frog"]:
			draw_line(Vector2(-s*0.20,-s*0.025),Vector2(-s*0.45,sin(cycle)*s*0.08),Color("#58794d",0.75),maxf(1,s*0.05))
	draw_set_transform(Vector2.ZERO)
	_water_ripple(p,s*0.52,0.0)
	# Linha d'agua e ondulacoes cobrem as partes submersas, nunca os pes sobre a superficie.
	draw_line(p-Vector2(s*0.32,0),p+Vector2(s*0.32,0),Color("#80cbd1",0.82),maxf(1,s*0.04))
	var spread:float=0.5 if moving else 0.25
	for i in range(3):
		var f:float=fposmod(world.swamp_clock*1.25+float(i)*0.33,1.0)
		var width:float=s*(0.18+f*spread)
		var q:=p+Vector2(-face*f*s*0.16,f*s*0.13)
		draw_line(q-Vector2(width,0),q+Vector2(width,0),Color(0.70,0.91,0.90,(1-f)*0.56),maxf(1,s*0.026))

func _valid_world_path(path:String) -> bool:
	if path==LEGACY_WORLD: return true
	if not path.begins_with(WORLDS_DIR+"/") or not path.ends_with(".json"): return false
	var name:String=path.get_file().trim_suffix(".json")
	return name.is_valid_int() and path==WORLDS_DIR+"/"+name+".json"

func _remember_world() -> void:
	var config:=ConfigFile.new()
	config.load(MENU_CONFIG)
	config.set_value("game","last_world",world.save_path)
	config.set_value("game","startup_speed",startup_speed)
	config.save(MENU_CONFIG)

func _world_slots() -> Array:
	var result:Array=[]
	var candidates:Array[String]=[LEGACY_WORLD]
	var dir:=DirAccess.open(WORLDS_DIR)
	if dir!=null:
		for file in dir.get_files():
			var path:String=WORLDS_DIR+"/"+file.trim_suffix(".bak")
			if _valid_world_path(path) and not candidates.has(path): candidates.append(path)
	for path in candidates:
		var actual:String=path if FileAccess.file_exists(path) else path+".bak"
		if not FileAccess.file_exists(actual): continue
		var data=JSON.parse_string(FileAccess.get_file_as_string(actual))
		if not data is Dictionary or not data.get("tiles",[]) is Array or data.get("tiles",[]).size()!=World.SIZE: continue
		var population:int=0
		for person in data.get("people",[]):
			if person is Dictionary and bool(person.get("alive",false)): population+=1
		result.append({"path":path,"name":str(data.get("world_name","Meu mundo")),"day":float(data.get("day",0)),"population":population,"modified":FileAccess.get_modified_time(actual)})
	result.sort_custom(func(a,b): return int(a["modified"])>int(b["modified"]))
	return result

func _open_home(save_first:bool=true) -> void:
	if save_first and not home_open:
		if not world.save_world():
			_menu_notice("Nao foi possivel salvar o mundo. Tente novamente.")
			return
		_remember_world()
	if is_instance_valid(home_panel): return
	home_open=true
	_close_actor_card()
	world.speed=0.0
	active_touches.clear()
	dragging=false
	pinch_active=false
	for control in game_hud:
		if is_instance_valid(control): control.hide()
	home_panel=Control.new()
	home_panel.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(home_panel)
	home_art=null
	if ResourceLoader.exists(HOME_ART_PATH):
		var artwork:=load(HOME_ART_PATH) as Texture2D
		if artwork!=null:
			home_art=TextureRect.new()
			home_art.texture=artwork
			home_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			home_art.stretch_mode=TextureRect.STRETCH_SCALE
			home_art.mouse_filter=Control.MOUSE_FILTER_IGNORE
			home_art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
			var material := ShaderMaterial.new()
			material.shader = preload("res://assets/landscape/menu_vale_dourado.gdshader")
			home_art.material = material
			home_panel.add_child(home_art)
	home_buttons.clear()
	for item in [{"label":"Carregar mundo","action":Callable(self,"_continue_world")},{"label":"Mundos salvos","action":Callable(self,"_show_saved_worlds")},{"label":"Opções","action":Callable(self,"_show_home_options")}]:
		var button:Button=_button(str(item["label"]),Vector2.ZERO,Vector2(360,62),item["action"])
		button.reparent(home_panel,false)
		button.add_theme_font_size_override("font_size",24)
		if is_instance_valid(home_art):
			button.self_modulate = Color.TRANSPARENT
			button.clip_text = true
		home_buttons.append(button)
	_layout_home()
	queue_redraw()

func _layout_home() -> void:
	if not is_instance_valid(home_panel): return
	home_panel.position=Vector2.ZERO
	home_panel.size=Vector2(screen_width,720)
	if is_instance_valid(home_art):
		home_panel.size = get_viewport_rect().size
		var fit := minf(home_panel.size.x / HOME_ART_SIZE.x, home_panel.size.y / HOME_ART_SIZE.y)
		# A arte central conserva a proporcao; o shader prolonga apenas as bordas.
		var art_size := HOME_ART_SIZE * fit
		var art_position := (home_panel.size - art_size) * 0.5
		home_art.position = Vector2.ZERO
		home_art.size = home_panel.size
		var art_rect := Vector4(art_position.x / home_panel.size.x, art_position.y / home_panel.size.y, art_size.x / home_panel.size.x, art_size.y / home_panel.size.y)
		(home_art.material as ShaderMaterial).set_shader_parameter("art_rect", art_rect)
		for i in range(home_buttons.size()):
			home_buttons[i].position = art_position + Vector2(466, HOME_BUTTON_TOPS[i]) * fit
			home_buttons[i].size = HOME_BUTTON_SIZE * fit
		return
	for i in range(home_buttons.size()):
		home_buttons[i].position=Vector2(screen_width*0.5-184,320+i*77)
		home_buttons[i].size=Vector2(368,62)

func _continue_world() -> void:
	var slots:Array=_world_slots()
	if slots.is_empty():
		_new_world()
		return
	for slot in slots:
		if str(slot["path"])==world.save_path:
			_open_saved_world(str(slot["path"]))
			return
	_open_saved_world(str(slots[0]["path"]))

func _open_saved_world(path:String) -> void:
	if not _valid_world_path(path): return
	if not home_open and not world.save_world():
		_menu_notice("Nao foi possivel salvar o mundo atual.")
		return
	var chosen=World.new()
	chosen.save_path=path
	if not chosen.load_world():
		_menu_notice("Nao foi possivel abrir este mundo. O arquivo nao foi apagado.")
		return
	world=chosen
	_enter_world()

func _create_saved_world(name:String) -> void:
	if not home_open and not world.save_world():
		_menu_notice("Nao foi possivel salvar o mundo atual.")
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORLDS_DIR))!=OK:
		_menu_notice("Nao foi possivel criar a pasta de mundos.")
		return
	var id:int=int(Time.get_unix_time_from_system())
	var path:String=WORLDS_DIR+"/"+str(id)+".json"
	while FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak"):
		id+=1
		path=WORLDS_DIR+"/"+str(id)+".json"
	var chosen=World.new()
	chosen.save_path=path
	chosen.world_name=name
	chosen.generate_world()
	if not chosen.save_world():
		_menu_notice("Nao foi possivel salvar o novo mundo.")
		return
	world=chosen
	_enter_world()

func _enter_world() -> void:
	home_open=false
	if is_instance_valid(home_panel): home_panel.queue_free()
	home_panel=null
	home_art=null
	home_buttons.clear()
	world.speed=startup_speed
	resume_speed=startup_speed
	selected_person_id=0
	selected_beast_id=0
	selected_town_id=0
	controlled_id=0
	spawn_species=""
	character_view=false
	active_touches.clear()
	visual_motion.clear()
	landscape_texture=null
	map_offset=Vector2.ZERO
	zoom=1.05
	autosave_timer=0
	for control in game_hud:
		if is_instance_valid(control): control.show()
	_sync_character_ui()
	if not world.towns.is_empty():
		var town:Dictionary=world.towns[0]
		_focus_at(Vector2(float(town["x"])+0.5,float(town["y"])+0.5))
	_remember_world()
	_refresh_ui()
	queue_redraw()

func _show_saved_worlds() -> void:
	var dialog:=AcceptDialog.new()
	dialog.title="Mundos salvos"
	dialog.ok_button_text="Voltar"
	var layout:=VBoxContainer.new()
	layout.custom_minimum_size=Vector2(850,470)
	layout.add_theme_constant_override("separation",12)
	var create:=Button.new()
	create.text="+ Criar novo mundo"
	create.custom_minimum_size=Vector2(0,48)
	create.pressed.connect(func():
		dialog.hide()
		dialog.queue_free()
		_new_world.call_deferred()
	)
	layout.add_child(create)
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(840,390)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var list:=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",8)
	scroll.add_child(list)
	layout.add_child(scroll)
	var slots:Array=_world_slots()
	if slots.is_empty():
		var empty:=Label.new()
		empty.text="Nenhum mundo salvo. Crie sua primeira civilizacao."
		list.add_child(empty)
	for slot in slots:
		var path:String=str(slot["path"])
		var row:=HBoxContainer.new()
		row.add_theme_constant_override("separation",8)
		var button:=Button.new()
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var day:float=float(slot["day"])
		button.text="%s   |   Ano %d, dia %d   |   %d moradores"%[str(slot["name"]),int(day/365)+1,int(day)%365+1,int(slot["population"])]
		button.custom_minimum_size=Vector2(0,58)
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func():
			dialog.hide()
			dialog.queue_free()
			_open_saved_world.call_deferred(path)
		)
		row.add_child(button)
		for reset in [true,false]:
			var action:=Button.new()
			action.text="Reiniciar" if reset else "Apagar"
			action.custom_minimum_size=Vector2(100,58)
			action.pressed.connect(func():
				dialog.hide()
				dialog.queue_free()
				_confirm_world_action.call_deferred(path,str(slot["name"]),reset)
			)
			row.add_child(action)
		list.add_child(row)
	dialog.add_child(layout)
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(900,540))

func _show_home_options() -> void:
	var dialog:=AcceptDialog.new()
	dialog.title="Opcoes"
	dialog.ok_button_text="Voltar"
	var layout:=VBoxContainer.new()
	layout.custom_minimum_size=Vector2(480,275)
	layout.add_theme_constant_override("separation",12)
	var volume:=Button.new()
	volume.text="Som e volume"
	volume.custom_minimum_size=Vector2(0,52)
	volume.pressed.connect(func():
		dialog.hide()
		dialog.queue_free()
		soundscape.show_settings.call_deferred()
	)
	layout.add_child(volume)
	var label:=Label.new()
	label.text="Velocidade ao entrar no mundo"
	layout.add_child(label)
	var select_speed:=OptionButton.new()
	for speed in [0.5,1.0,2.0,4.0]:
		select_speed.add_item(str(speed)+"x")
		if is_equal_approx(startup_speed,speed): select_speed.select(select_speed.item_count-1)
	select_speed.item_selected.connect(func(index:int):
		startup_speed=[0.5,1.0,2.0,4.0][index]
		_remember_world()
	)
	select_speed.custom_minimum_size=Vector2(0,44)
	layout.add_child(select_speed)
	var update:=Button.new()
	update.text="Verificar atualizacoes"
	update.custom_minimum_size=Vector2(0,52)
	update.pressed.connect(func():
		dialog.hide()
		dialog.queue_free()
		_check_updates.call_deferred()
	)
	layout.add_child(update)
	var version:=Label.new()
	version.text="Versao "+str(update_manager.get("_installed_version_name"))
	layout.add_child(version)
	dialog.add_child(layout)
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(530,365))

func _menu_notice(message:String) -> void:
	var dialog:=AcceptDialog.new()
	dialog.title="Legado das Eras"
	dialog.dialog_text=message
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _draw_home_art() -> void:
	if is_instance_valid(home_art):
		draw_rect(get_viewport_rect(), Color("#0d1925"))
		return
	if not landscape_objects.has("title_landscape"): landscape_objects["title_landscape"]=load("res://assets/landscape/title_landscape_v2.svg")
	var art:Texture2D=landscape_objects["title_landscape"]
	var extent:Vector2=Vector2(screen_width,720)
	if art!=null:
		var scale:float=maxf(extent.x/art.get_width(),extent.y/art.get_height())
		var size:Vector2=art.get_size()*scale
		draw_texture_rect(art,Rect2((extent-size)*0.5,size),false)
	var middle:float=screen_width*0.5
	# Escurecimento suave no centro; a paisagem continua visivel em volta.
	for i in range(18):
		var half:float=400.0-float(i)*10.0
		draw_rect(Rect2(middle-half,0,half*2,720),Color(0.025,0.045,0.045,0.035))
	if title_font==null:
		title_font=SystemFont.new()
		title_font.font_names=PackedStringArray(["Noto Serif","serif","DejaVu Serif"])
		title_font.font_weight=800
	# Marca em duas linhas, dourado envelhecido com contorno escuro.
	var gold:=Color("#e8ce8e")
	var shade:=Color("#232d2a")
	for offset in [Vector2(-2,0),Vector2(2,0),Vector2(0,-2),Vector2(0,3),Vector2(0,6)]:
		draw_string(title_font,Vector2(middle-340,173)+offset,"LEGADO",HORIZONTAL_ALIGNMENT_CENTER,680,82,shade)
		draw_string(title_font,Vector2(middle-300,242)+offset,"DAS ERAS",HORIZONTAL_ALIGNMENT_CENTER,600,55,shade)
	draw_string(title_font,Vector2(middle-340,173),"LEGADO",HORIZONTAL_ALIGNMENT_CENTER,680,82,gold)
	draw_string(title_font,Vector2(middle-300,242),"DAS ERAS",HORIZONTAL_ALIGNMENT_CENTER,600,55,Color("#f5e2b3"))
	for side in [-1.0,1.0]:
		draw_line(Vector2(middle+side*18,276),Vector2(middle+side*187,276),Color("#b69b63"),2)
		draw_line(Vector2(middle+side*187,276),Vector2(middle+side*207,268),Color("#b69b63"),2)
	draw_set_transform(Vector2(middle,276),PI/4)
	draw_rect(Rect2(-6,-6,12,12),Color("#e8ce8e"))
	draw_set_transform(Vector2.ZERO)


func _confirm_world_action(path:String,name:String,restart:bool) -> void:
	if not _valid_world_path(path): return
	var dialog:=ConfirmationDialog.new()
	dialog.title="Reiniciar mundo?" if restart else "Apagar mundo?"
	dialog.dialog_text="O progresso de \""+name+"\" sera substituido por um mapa novo." if restart else "O mundo \""+name+"\" sera excluido deste aparelho. Esta acao nao pode ser desfeita."
	dialog.ok_button_text="Reiniciar" if restart else "Apagar"
	dialog.cancel_button_text="Cancelar"
	add_child(dialog)
	dialog.confirmed.connect(func():
		dialog.queue_free()
		if restart: _restart_saved_world(path,name)
		else: _delete_saved_world(path)
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(500,200))

func _restart_saved_world(path:String,name:String) -> void:
	if not _valid_world_path(path): return
	if not home_open and world.save_path!=path and not world.save_world():
		_menu_notice("Nao foi possivel salvar o mundo atual.")
		return
	var chosen=World.new()
	chosen.save_path=path
	chosen.world_name=name
	chosen.generate_world()
	if not chosen.save_world():
		_menu_notice("Nao foi possivel reiniciar o mundo.")
		return
	world=chosen
	_enter_world()

func _delete_saved_world(path:String) -> void:
	if not _valid_world_path(path): return
	# Remove copias auxiliares antes do arquivo principal; nao reabre um mundo excluido.
	for suffix in [".tmp",".bak",""]:
		var file:String=path+suffix
		if FileAccess.file_exists(file) and DirAccess.remove_absolute(ProjectSettings.globalize_path(file))!=OK:
			_menu_notice("Nao foi possivel apagar o mundo por completo.")
			return
	if world.save_path==path:
		world=World.new()
		world.generate_world()
		world.speed=0.0
		if not home_open: _open_home(false)
		_remember_world()
	if home_open: _show_saved_worlds.call_deferred()

const FAUNA_APPROVED:Texture2D=preload("res://assets/landscape/fauna_aprovada.png")
const WITCH_APPROVED:Texture2D=preload("res://assets/landscape/bruxa_nativa.svg")
const GOLEM_APPROVED:Texture2D=preload("res://assets/landscape/golem_nativo.svg")
const FENRIR_APPROVED:Texture2D=preload("res://assets/landscape/fenrir_nativo.svg")
const SPIDERS_APPROVED:Texture2D=preload("res://assets/landscape/aranhas_aprovadas.png")
func _draw_fauna(animal:Dictionary,p:Vector2,s:float,species:String) -> void:
	var row:int=ANIMAL_ROWS.find(species)
	if row<0: return
	var motion:Dictionary=visual_motion.get(int(animal["id"]),{})
	var phase:float=float(motion.get("phase",0))
	var moving:bool=bool(motion.get("moving",false)) and world.speed>0
	var face:float=float(motion.get("face",1.0))
	var cycle:int=int(fposmod(phase,TAU)/TAU*4)
	var frame:int=cycle if moving else 0
	var height:float=float(animal.get("flight_height",0))
	if species in ["deer","cow","cat","bear","chicken","heron"] and moving:
		frame=[0,1,2,1][cycle]
	if height>0.01:
		_contact_shadow(p,s*0.28,s*0.07)
		frame=1+int(world.swamp_clock*(7.0 if species=="bat" else 4.5))%3
		_draw_walk_sprite(FAUNA_APPROVED,Rect2(frame*48,row*48,48,48),p-Vector2(0,height*36*zoom),s,face,phase,false,0.0)
		return
	var depth:float=world.water_depth(Vector2(float(animal["x"]),float(animal["y"])))
	if depth>0:
		_draw_water_actor(FAUNA_APPROVED,Rect2(frame*48,row*48,48,48),p,s,face,depth,species,moving)
		return
	if not moving and str(animal.get("state","")) in ["Pastando","Fuçando","Bicando","Comendo","Pescando"]:
		frame=3 if int(world.swamp_clock*1.8)%2==0 else 0
	var bounce:float=absf(sin(phase))*s*0.06 if moving and species in ["frog","rabbit","snow_hare"] else 0.0
	_contact_shadow(p,s*0.28,s*0.07)
	_draw_walk_sprite(FAUNA_APPROVED,Rect2(frame*48,row*48,48,48),p,s,face,phase,false,bounce)

