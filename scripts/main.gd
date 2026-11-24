extends Node2D
## Legado das Eras — tela jogavel. A simulacao permanece em world.gd.
const World = preload("res://scripts/world.gd")
const Updates = preload("res://scripts/update_manager.gd")
const TILE_SIZE := 44.0
const MAP_ORIGIN := Vector2(15.0, 79.0)
const MAP_AREA := Rect2(12.0, 78.0, 1256.0, 626.0)
const AUTOSAVE_SECONDS := 20.0

var world = World.new()
var selected_person_id := 0
var selected_beast_id := 0
var selected_town_id := 0
var controlled_id := 0
var map_offset := Vector2.ZERO
var zoom := 1.25
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
var view_button: Button
var action_button: Button
var inventory_button: Button

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
	if not world.load_world():
		world.generate_world()
	world.speed = 1.0
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	_load_art()
	update_manager = Updates.new()
	add_child(update_manager)
	_build_ui()
	if not world.towns.is_empty():
		var first_town: Dictionary = world.towns[0]
		_focus_at(Vector2(float(first_town["x"]) + 0.5, float(first_town["y"]) + 0.5))
	_refresh_ui()
	queue_redraw()

func _process(delta: float) -> void:
	_move_controlled(delta)
	world.update_world(delta, controlled_id)
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
		if world != null and not world.tiles.is_empty():
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
	for key in ["hut","farm"]:
		var new_art: Resource = load("res://assets/landscape/reference_"+key+".png")
		if new_art is Texture2D: actor_textures[key] = new_art
	landscape_objects["tree"] = load("res://assets/landscape/reference_tree.png")
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
	_button("Construir", Vector2(899, 15), Vector2(112, 38), Callable(self, "_show_construction"))
	view_button = _button("Controlar", Vector2(1015, 15), Vector2(100, 38), Callable(self, "_toggle_view"))
	_button("Mundo", Vector2(1119, 15), Vector2(73, 38), Callable(self, "_show_options"))
	_button("Atualizar", Vector2(1196, 15), Vector2(80, 38), Callable(self, "_check_updates"))
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
	b.pressed.connect(callback)
	add_child(b)
	return b

func _refresh_ui() -> void:
	var years := int(world.day / 365.0)
	var day_of_year := int(world.day) % 365 + 1
	var living := 0
	for p in world.people:
		if bool(p["alive"]):
			living += 1
	stats_label.text = "Ano %d · Dia %d · %s · %d moradores" % [years + 1, day_of_year, _season_name(), living]
	last_news = world.news
	news_label.text = world.news
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
	const DETAIL := 16
	var img := Image.create(World.WIDTH * DETAIL, World.SIZE * DETAIL, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 527
	noise.frequency = 0.055
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
			var shade: float = roundf((noise.get_noise_2d(px, py)*0.20+(grain-0.5)*0.20)*12.0)/12.0
			if water > 0.46:
				col = Color("#237c9e").lerp(Color("#52b6ca"), clampf((1.0-water)*1.5 + shade, 0.0, 0.85))
				if water < 0.60: col = Color("#6ebbc0")
				elif grain > 0.89 and py % 5 == 0: col = col.lightened(0.20)
			elif water > 0.28:
				col = Color("#b6a274")
			col = col.lightened(shade) if shade > 0.0 else col.darkened(-shade)
			img.set_pixel(px, py, col)
	landscape_texture = ImageTexture.create_from_image(img)

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
			if near_house: continue
			if kind == "water":
				var phase: float = fposmod(float(Time.get_ticks_msec())*0.00016+float(seed)*0.017,1.0)
				var wave: Vector2 = pos+Vector2((phase-0.5)*side*0.38,side*0.04)
				if MAP_AREA.grow(-side*0.2).has_point(wave):
					draw_rect(Rect2(wave,Vector2(side*0.12,maxf(1,side*0.018))),Color("#94e4eb",0.66))
			elif kind == "grass" or kind == "forest":
				for n in range(5):
					var k: int = posmod(seed*31+n*127,997)
					var q: Vector2 = pos+Vector2(float(k%23)/23.0-0.5,float(k%17)/17.0-0.5)*side*0.85
					if not MAP_AREA.grow(-side*0.08).has_point(q): continue
					var ss: float = maxf(1.0,side*0.026)
					draw_rect(Rect2(q,Vector2(ss,ss*2)),Color("#496c2c"))
					draw_rect(Rect2(q+Vector2(ss,ss),Vector2(ss,ss)),Color("#91a94e"))
					if k%7==0: draw_rect(Rect2(q-Vector2(0,ss),Vector2(ss,ss)),Color("#ead0a5"))
			elif kind == "swamp":
				_draw_landscape_object("marsh",pos,side*0.85)
			elif kind == "mountain":
				if seed%3!=0: _draw_landscape_object("rock", pos, side*(0.7+float(seed%5)*0.14))
			elif kind == "sand" and seed % 4 == 0:
				_draw_landscape_object("cactus", pos, side*0.66)

	for tree in world.trees.values():
		var p: Vector2 = _world_to_screen(Vector2(float(tree["x"])+0.5+float(tree["ox"]),float(tree["y"])+0.5+float(tree["oy"])))
		if not MAP_AREA.grow(-side*0.3).has_point(p): continue
		var s: float = side*1.12*world.tree_scale(tree)
		var state: String = str(tree["state"])
		if state == "stump":
			draw_ellipse_stump(p,s)
		elif state == "falling":
			var key: String = "pine" if bool(tree["pine"]) else "tree"
			if not landscape_objects.has(key):
				landscape_objects[key] = load("res://assets/landscape/"+key+".svg")
			if MAP_AREA.grow(-s*1.2).has_point(p):
				draw_set_transform(p,float(tree["fall"])*PI*0.5)
				draw_texture_rect(landscape_objects[key],Rect2(-s*0.5,-s*0.85,s,s),false)
				draw_set_transform(Vector2.ZERO)
			draw_ellipse_stump(p,s)
		else:
			_draw_landscape_object("pine" if bool(tree["pine"]) else "tree",p,s)

func draw_ellipse_stump(p: Vector2,s: float) -> void:
	draw_circle(p,s*0.11,Color("#513b25"))
	draw_circle(p-Vector2(0,s*0.055),s*0.10,Color("#b98a50"))
	draw_arc(p-Vector2(0,s*0.055),s*0.057,0,TAU,12,Color("#825a35"),1.0)

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
	# Interface discreta: mapa em quase toda a area util do aparelho.
	draw_rect(Rect2(0, 0, 1280, 720), Color("#141e1a"), true)
	draw_rect(Rect2(0, 0, 1280, 75), Color("#211e19"), true)
	draw_line(Vector2(0, 74), Vector2(1280, 74), Color("#ae8c54"), 2.0)
	_draw_clock()
	draw_rect(MAP_AREA, Color("#355943"), true)
	_draw_landscape()
	_draw_rivers()
	_draw_world_sites()
	# Quantidade real de casas e fazendas aparece no mapa, conforme o estoque da vila.
	var house_spots: Array[Vector2] = [
		Vector2(0.0, -0.35), Vector2(1.60, 0.35), Vector2(-1.25, -0.75),
		Vector2(2.15, -0.85), Vector2(-2.4, 0.15), Vector2(0.95, -1.65),
		Vector2(-1.35, 1.45), Vector2(2.9, 1.15)
	]
	var farm_spots: Array[Vector2] = [
		Vector2(-1.4, 1.15), Vector2(-2.2, 2.20), Vector2(1.3, 1.85),
		Vector2(2.9, 2.0), Vector2(-2.8, -1.1), Vector2(3.1, -1.4)
	]
	for town in world.towns:
		var center := _world_to_screen(Vector2(float(town["x"]) + 0.5, float(town["y"]) + 0.5))
		if not MAP_AREA.grow(140.0).has_point(center):
			continue
		var unit := TILE_SIZE * zoom
		_draw_village_paths(town, center, unit, house_spots, farm_spots)
		# A terra cultivada cresce quando uma fazenda fica pronta.
		for i in range(mini(int(town.get("farms", 1)), farm_spots.size())):
			var spot: Vector2 = farm_spots[i]
			_draw_sprite("farm", center + spot * unit, Vector2(1.45, 0.96) * unit, true)
		for i in range(mini(int(town.get("houses", 2)), house_spots.size())):
			var spot: Vector2 = house_spots[i]
			var house_size: float = 1.62 if i == 0 else 1.35
			var era: int = clampi(int(town.get("level", 1)), 1, 5)
			if era == 1:
				_draw_sprite("hut", center + spot * unit, Vector2(house_size, house_size*0.82) * unit, true)
			else:
				_draw_landscape_object("house_" + str(era), center + spot * unit + Vector2(0, house_size * unit * 0.27), house_size * unit * (1.0 + float(era-1)*0.10))
		_draw_sprite("fire", center + Vector2(0.7, 1.0) * unit, Vector2(0.70, 0.70) * unit, true)
		var site: Dictionary = town.get("construction", {})
		if not site.is_empty() and MAP_AREA.grow(-35.0).has_point(center):
			var kind: String = str(site.get("kind", "house"))
			var total: float = maxf(1.0, float(site.get("duration", 12.0)))
			var progress: float = clampf(float(site.get("progress", 0.0)) / total, 0.0, 1.0)
			var line_start: Vector2 = center + Vector2(-35.0, -58.0) * zoom
			var size: Vector2 = Vector2(70.0, 7.0) * zoom
			draw_rect(Rect2(line_start, size), Color("#392c20"), true)
			draw_rect(Rect2(line_start, Vector2(size.x * progress, size.y)), Color("#e6bd72"), true)
			draw_rect(Rect2(line_start, size), Color("#f4d8a1"), false, maxf(1.0, zoom))
			var build_spot: Vector2 = house_spots[mini(int(town.get("houses", 2)), house_spots.size()-1)] if kind == "house" else farm_spots[mini(int(town.get("farms", 1)), farm_spots.size()-1)]
			var scaffold: Vector2 = _world_to_screen(Vector2(float(site["x"])+0.5,float(site["y"])+0.5)) if site.has("x") else center + build_spot * unit
			if MAP_AREA.has_point(scaffold):
				draw_line(scaffold + Vector2(-15, 10) * zoom, scaffold + Vector2(15, -21) * zoom, Color("#ddbe7e"), maxf(1.0, 3.0 * zoom))
				draw_line(scaffold + Vector2(15, 10) * zoom, scaffold + Vector2(-15, -21) * zoom, Color("#b78c5d"), maxf(1.0, 3.0 * zoom))
		if int(town["id"]) == selected_town_id and MAP_AREA.has_point(center):
			draw_arc(center, 35.0 * zoom, 0.0, TAU, 32, Color("#fff0a0"), 3.0)
	for animal in world.wildlife:
		var p: Vector2 = _world_to_screen(Vector2(float(animal["x"])+0.5,float(animal["y"])+0.5))
		_draw_landscape_object(str(animal["species"]),p,zoom*(32.0 if str(animal["species"]) in ["deer","camel","crocodile"] else (24.0 if str(animal["species"]) in ["capybara","heron","boar","fox"] else 17.0)))
	# Personagens separados visualmente por idade e aparencia.
	for p in world.people:
		if not bool(p["alive"]):
			continue
		var center := _world_to_screen(Vector2(float(p["x"]) + 0.5, float(p["y"]) + 0.5))
		if not MAP_AREA.has_point(center):
			continue
		_draw_person_variant(p,center)
		if int(p["id"]) == selected_person_id:
			draw_arc(center, 14.0 * zoom, 0, TAU, 20, Color("#ffe890"), 2.0)
			var task_name: String = str(p.get("task", "Observando"))
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
		_draw_sprite(key, center, Vector2(38, 38) * zoom, true)
		if int(b["id"]) == selected_beast_id:
			draw_arc(center, 15.0 * zoom, 0, TAU, 20, Color("#ffe890"), 2.0)
		if int(b["id"]) == controlled_id:
			draw_arc(center, 19.0 * zoom, 0, TAU, 20, Color("#6cffda"), 3.0)
	draw_rect(MAP_AREA, Color("#bc985d", 0.70), false, 2.0)
	if info_label != null and info_label.visible:
		draw_rect(Rect2(17, 650, 1207, 41), Color("#172219", 0.86), true)
		draw_rect(Rect2(17, 650, 1207, 41), Color("#d1ab6c"), false, 1.0)

func _draw_village_paths(town: Dictionary, center: Vector2, unit: float, houses: Array[Vector2], farms: Array[Vector2]) -> void:
	for i in range(mini(int(town.get("houses",2)),houses.size())):
		_draw_dirt_path(center+Vector2(0.7,1.0)*unit,center+houses[i]*unit+Vector2(0,unit*0.30),unit)
	for i in range(mini(int(town.get("farms",1)),farms.size())):
		_draw_dirt_path(center+Vector2(0.7,1.0)*unit,center+farms[i]*unit,unit)

func _draw_dirt_path(a: Vector2,b: Vector2,unit: float) -> void:
	var count: int = maxi(2,int(a.distance_to(b)/(unit*0.07)))
	for i in range(count+1):
		var t: float = float(i)/float(count)
		var p: Vector2 = a.lerp(b,t)
		var size: float = unit*(0.19+0.04*sin(t*19.0))
		if not MAP_AREA.grow(-size).has_point(p): continue
		draw_rect(Rect2(p-Vector2.ONE*size*0.5,Vector2.ONE*size),Color("#a78a4f"))
		if i%3==0:
			draw_rect(Rect2(p-Vector2(size*0.2,size*0.25),Vector2(size*0.23,size*0.18)),Color("#d4b477"))


func _draw_world_sites() -> void:
	var unit:float=TILE_SIZE*zoom
	for site in world.sites:
		var p:Vector2=_world_to_screen(Vector2(float(site["x"])+0.5,float(site["y"])+0.5))
		var kind:String=str(site["kind"])
		if kind=="waterfall":
			_draw_waterfall(p,unit)
		elif kind=="crossing":
			_draw_landscape_object("bridge",p,unit*1.9)
		elif kind=="mine" and not bool(site.get("developed",false)):
			_draw_landscape_object("rock",p,unit*0.95)
		else:
			_draw_landscape_object(kind,p,unit*(1.45 if kind=="mine" else 0.95))

func _draw_rivers() -> void:
	var unit:float=TILE_SIZE*zoom
	var time:float=float(Time.get_ticks_msec())*0.00055
	for y in range(World.SIZE):
		for x in range(World.WIDTH):
			if str(world.tiles[y][x])!="water": continue
			var p:Vector2=_world_to_screen(Vector2(x+0.5,y+0.5))
			if not MAP_AREA.grow(-unit*0.65).has_point(p): continue
			var flow:Vector2=world.water_flow(Vector2(x,y))
			for i in range(4):
				var phase:float=fposmod(time+float(i)*0.25+float(x)*0.13,1.0)
				var q:Vector2=p+flow*(phase-0.5)*unit*0.8+Vector2(flow.y,-flow.x)*(float(i)-1.5)*unit*0.14
				draw_rect(Rect2(q,Vector2(unit*0.12, maxf(1.0,unit*0.027))),Color("#8edbe1",0.6))

func _draw_waterfall(p:Vector2,u:float) -> void:
	if not MAP_AREA.grow(-u).has_point(p): return
	for side in [-1,1]:
		_draw_landscape_object("rock",p+Vector2(float(side)*u*0.46,-u*0.16),u*0.83)
	var base:Vector2=p-Vector2(u*0.23,u*0.67)
	draw_rect(Rect2(base,Vector2(u*0.46,u*0.78)),Color("#248db1"))
	for i in range(7):
		var x:float=float(i)*u*0.065
		var f:float=fposmod(float(Time.get_ticks_msec())*0.0014+float(i)*0.19,1.0)
		draw_rect(Rect2(base+Vector2(x,f*u*0.56),Vector2(u*0.035,u*0.19)),Color("#b8f2f2" if i%2==0 else "#65c8dc"))
	for i in range(9):
		var f:float=fposmod(float(Time.get_ticks_msec())*0.0005+float(i)*0.12,1.0)
		var q:Vector2=p+Vector2((float(i%3)-1.0)*u*0.17,f*u*0.33)
		draw_rect(Rect2(q,Vector2(u*0.10,u*0.035)),Color("#def9f4",1.0-f))

func _draw_person_variant(p: Dictionary, center: Vector2) -> void:
	var stage: int = world.life_stage(p)
	var variant: int = posmod(int(p.get("appearance",p["id"])),10)
	var s: float = 29.0*zoom*[0.44,0.68,1.0,0.92][stage]
	if not landscape_objects.has("people_atlas"):
		landscape_objects["people_atlas"] = load("res://assets/landscape/people_atlas.svg")
	var atlas: Texture2D = landscape_objects["people_atlas"]
	var source := Rect2(float(variant%5)*64.0+16.0,float(int(p["gender"])*2+floori(float(variant)/5.0))*48.0,32.0,48.0)
	var target := Vector2(float(p.get("target_x",p["x"])),float(p.get("target_y",p["y"])))
	var moving: bool = target.distance_to(Vector2(float(p["x"]),float(p["y"])))>0.08 and world.speed>0.0
	var bounce: float = roundf(absf(sin(float(Time.get_ticks_msec())*0.014+float(p["id"])))) * 2.0*zoom if moving else 0.0
	var dest := Rect2(center-Vector2(s/3.0,s*0.7+bounce),Vector2(s*2.0/3.0,s))
	var clipped := dest.intersection(MAP_AREA)
	if clipped.has_area():
		draw_texture_rect_region(atlas,clipped,Rect2(source.position+(clipped.position-dest.position)/dest.size*source.size,clipped.size/dest.size*source.size))
	if str(p.get("profession",""))=="Pescador" and stage>=2:
		draw_rect(Rect2(dest.position+Vector2(s*0.12,s*0.05),Vector2(s*0.42,s*0.09)),Color("#c9a255"))
		if str(p.get("task",""))=="Pescando":
			draw_line(center,center+Vector2(s*0.9,-s*0.45),Color("#79522d"),maxf(1.0,zoom))
			draw_line(center+Vector2(s*0.9,-s*0.45),center+Vector2(s*0.9,s*0.3),Color("#c9d9d4"),1.0)
	if stage==3:
		draw_line(center+Vector2(-s*0.10,-s*0.21),center+Vector2(s*0.11,-s*0.21),Color("#e1ded2"),maxf(1,s*0.10))
		draw_line(center+Vector2(s*0.15,0),center+Vector2(s*0.25,s*0.25),Color("#795433"),maxf(1,s*0.055))
	elif stage==0:
		draw_circle(center+Vector2(0,s*0.08),s*0.11,Color("#d9c7a2"))

func _draw_clock() -> void:
	var c := Vector2(705, 34)
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
	if character_view:
		if controlled_id > 0:
			var actor: Dictionary = world.get_actor(controlled_id)
			if not actor.is_empty():
				var d: Vector2 = (position - MAP_AREA.get_center()).normalized()
				actor["target_x"] = clampf(float(actor["x"]) + d.x * 2.4, 1.0, float(World.WIDTH - 2))
				actor["target_y"] = clampf(float(actor["y"]) + d.y * 2.4, 1.0, float(World.SIZE - 2))
		return
	var point := _screen_to_world(position)
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
	if nearest_id > 0:
		selected_person_id = nearest_id
		selected_beast_id = 0
		selected_town_id = 0
	elif nearest_beast_id > 0:
		selected_beast_id = nearest_beast_id
		selected_person_id = 0
		selected_town_id = 0
	else:
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
			if kind == "water":
				movement *= 0.28
				nx = clampf(float(actor["x"])+movement.x,1.0,float(World.WIDTH-2))
				ny = clampf(float(actor["y"])+movement.y,1.0,float(World.SIZE-2))
			if kind != "mountain":
				actor["x"] = nx
				actor["y"] = ny
				actor["target_x"] = nx
				actor["target_y"] = ny
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
		var kind: String = "farm" if build_picker.get_selected_id() == 1 else "house"
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
			match action_picker.get_selected_id():
				1: action = "alliance"
				2: action = "war"
			if action == "war":
				world.wars = true
				if not world.rivals:
					world.toggle_rivals()
			world.politics.set_treaty(world, from_id, to_id, action)
			world.save_world()
		_refresh_ui()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(600, 580))

func _show_options() -> void:
	var popup := PopupMenu.new()
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
	popup.add_item("Ativar / desativar predadores", 9)
	popup.add_separator()
	popup.add_item("Ir para primeira vila", 3)
	popup.add_item("Salvar mundo", 2)
	popup.add_item("Verificar atualizacoes", 0)
	popup.add_item("Criar novo mundo", 1)
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
		actor["wood"] = int(actor.get("wood", 0)) + 1
		world.news = str(actor["name"]) + " coletou galhos no campo."
	elif biome == "sand":
		actor["food"] = int(actor.get("food", 0)) + 1
		world.news = str(actor["name"]) + " encontrou mantimentos no deserto."
	elif biome == "mountain":
		actor["stone"] = int(actor.get("stone", 0)) + 2
		world.news = str(actor["name"]) + " coletou 2 pedras."
	elif biome == "water":
		actor["water"] = int(actor.get("water", 0)) + 2
		world.news = str(actor["name"]) + " coletou 2 unidades de agua."
	elif biome == "snow":
		actor["wood"] = int(actor.get("wood", 0)) + 1
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
		header.text = "%s  |  Vida: %d" % [str(actor.get("name", "Habitante")), int(float(actor.get("health", 100.0)))]
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
		dialog.add_child(content)
	add_child(dialog)
	dialog.popup_centered(Vector2i(570, 350))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)

func _show_details() -> void:
	var lines: Array[String] = []
	if selected_person_id > 0:
		var p: Dictionary = world.get_person(selected_person_id)
		if not p.is_empty():
			var home: Dictionary = world.get_town(int(p["town"]))
			lines.append("%s • %d anos" % [p["name"], int(float(p["age"]))])
			lines.append("Aldeia: %s  |  Profissao: %s" % [home.get("name", "?"), p.get("profession", "?")])
			lines.append("Vida: %d  |  Funcao: %s" % [int(float(p["health"])), p["role"]])
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
			lines.append("Populacao: %d" % world.active_population(selected_town_id))
			lines.append("Alimentos %d  |  Madeira %d" % [int(float(town["food"])), int(float(town["wood"]))])
			for event in town.get("historical_events", []):
				lines.append("• " + str(event.get("event", "")))
	else:
		lines.append("Toque em um habitante ou aldeia para ver suas informacoes.")
	var dialog := AcceptDialog.new()
	dialog.title = "Cronicas do Legado"
	dialog.dialog_text = "\n".join(lines)
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
	# Exige pressao longa por meio da confirmacao incorporada, evitando apagar por acidente.
	var dialog := ConfirmationDialog.new()
	dialog.title = "Criar novo mundo?"
	dialog.dialog_text = "Isso substitui o mundo salvo. Seu mundo atual nao podera ser recuperado."
	dialog.ok_button_text = "Criar novo"
	dialog.cancel_button_text = "Cancelar"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		world.generate_world()
		selected_person_id = 0
		selected_beast_id = 0
		selected_town_id = 0
		controlled_id = 0
		character_view = false
		_sync_character_ui()
		map_offset = Vector2.ZERO
		zoom = 1.25
		world.save_world()
		_refresh_ui()
	)
	dialog.popup_centered()
	dialog.close_requested.connect(dialog.queue_free)
