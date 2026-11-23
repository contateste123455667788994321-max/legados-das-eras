extends Node2D
## Legado das Eras — tela jogavel. A simulacao permanece em world.gd.
const World = preload("res://scripts/world.gd")
const Updates = preload("res://scripts/update_manager.gd")
const WorldVisual = preload("res://scripts/world_visual.gd")
const TILE_SIZE := 44.0
const MAP_ORIGIN := Vector2(38.0, 90.0)
const MAP_AREA := Rect2(17.0, 82.0, 838.0, 443.0)
const RIGHT_VIEW := Rect2(870.0, 80.0, 395.0, 221.0)
const AUTOSAVE_SECONDS := 20.0

var world = World.new()
var selected_person_id := 0
var selected_beast_id := 0
var selected_town_id := 0
var controlled_id := 0
var map_offset := Vector2.ZERO
var zoom := 1.0
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
var world_visual: Node2D
var preview_visual: Node2D
var character_clip: Control
var character_view := false
var view_button: Button

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
	_load_art()
	update_manager = Updates.new()
	add_child(update_manager)
	character_clip = Control.new()
	character_clip.position = MAP_AREA.position
	character_clip.size = MAP_AREA.size
	character_clip.clip_contents = true
	character_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(character_clip)
	world_visual = WorldVisual.new()
	world_visual.game = self
	world_visual.position = -MAP_AREA.position
	character_clip.add_child(world_visual)
	character_clip.visible = false
	var preview_clip := Control.new()
	preview_clip.position = RIGHT_VIEW.position
	preview_clip.size = RIGHT_VIEW.size
	preview_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_clip.clip_contents = true
	add_child(preview_clip)
	preview_visual = WorldVisual.new()
	preview_visual.game = self
	preview_visual.preview_mode = true
	preview_visual.position = -RIGHT_VIEW.position
	preview_clip.add_child(preview_visual)
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
	if character_view and is_instance_valid(world_visual):
		world_visual.queue_redraw()
	if is_instance_valid(preview_visual) and ui_timer == 0.0:
		preview_visual.queue_redraw()

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
	if texture_missing:
		push_warning("Alguns desenhos do mapa ainda nao foram carregados.")

func _build_ui() -> void:
	# Interface da primeira referencia: mapa grande, visao pessoal, ficha e quadros do mundo.
	var title := _label("LEGADO DAS ERAS", Vector2(25, 9), Vector2(315, 44), 29, Color("#f4d78d"))
	title.add_theme_color_override("font_shadow_color", Color("#121812"))
	title.add_theme_constant_override("shadow_offset_y", 2)
	stats_label = _label("", Vector2(315, 14), Vector2(420, 25), 16, Color("#e8dec1"))
	news_label = _label("", Vector2(26, 49), Vector2(478, 30), 16, Color("#f2c979"))
	news_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_button = _button("Pausar", Vector2(515, 43), Vector2(84, 34), Callable(self, "_toggle_pause"))
	speed_button = _button("1x", Vector2(604, 43), Vector2(80, 34), Callable(self, "_change_speed"))
	_button("Zoom -", Vector2(689, 43), Vector2(79, 34), Callable(self, "_zoom_out"))
	_button("Zoom +", Vector2(773, 43), Vector2(80, 34), Callable(self, "_zoom_in"))
	_button("Atualizar", Vector2(1134, 43), Vector2(120, 34), Callable(self, "_check_updates"))
	_label("VISAO DO PERSONAGEM", Vector2(885, 89), Vector2(330, 28), 17, Color("#f8df9c"))
	_label("Toque aqui para explorar", Vector2(883, 270), Vector2(341, 27), 15, Color("#f3e2bb"))
	_label("PERSONAGEM / TRIBO", Vector2(880, 310), Vector2(370, 27), 19, Color("#f3d293"))
	info_label = _label("", Vector2(947, 340), Vector2(309, 65), 16, Color("#f1e8cf"))
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control_button = _button("Controlar", Vector2(881, 405), Vector2(174, 40), Callable(self, "_toggle_control"))
	view_button = _button("Entrar no mundo", Vector2(1061, 405), Vector2(193, 40), Callable(self, "_toggle_view"))
	war_button = _button("Guerras", Vector2(881, 450), Vector2(119, 40), Callable(self, "_toggle_war"))
	rival_button = _button("Rivais", Vector2(1007, 450), Vector2(116, 40), Callable(self, "_toggle_rivals"))
	predator_button = _button("Animais", Vector2(1130, 450), Vector2(124, 40), Callable(self, "_toggle_predators"))
	_button("Diplomacia", Vector2(881, 496), Vector2(139, 36), Callable(self, "_show_diplomacy"))
	_button("Salvar", Vector2(1027, 496), Vector2(97, 36), Callable(self, "_save_now"))
	_button("Opcoes", Vector2(1131, 496), Vector2(123, 36), Callable(self, "_show_options"))
	_label("BIOMAS DO MUNDO", Vector2(30, 542), Vector2(286, 31), 19, Color("#f4d68f"))
	_label("ESTACOES DO ANO", Vector2(340, 542), Vector2(280, 31), 19, Color("#f4d68f"))
	_label("CICLO DA VIDA", Vector2(640, 542), Vector2(286, 31), 19, Color("#f4d68f"))
	_label("EVOLUCAO DAS ALDEIAS", Vector2(959, 542), Vector2(307, 31), 18, Color("#f4d68f"))
	for i in range(3):
		var kinds := ["sand", "forest", "snow"]
		_add_biome_touch(kinds[i], Vector2(34.0 + float(i) * 96.0, 578.0))
	_label("Deserto          Floresta          Neve", Vector2(25, 654), Vector2(298, 25), 14, Color("#e8d9b7"))
	_label("Primavera  Verao  Outono  Inverno", Vector2(327, 654), Vector2(306, 25), 14, Color("#e8d9b7"))
	_label("Nascer   Crescer   Adulto   Velhice", Vector2(627, 654), Vector2(315, 25), 14, Color("#e8d9b7"))
	_label("Tribo    Ferramentas    Cidade", Vector2(953, 654), Vector2(310, 25), 14, Color("#e8d9b7"))
	_label("Construir  •  Sobreviver  •  Evoluir", Vector2(24, 686), Vector2(460, 24), 15, Color("#d4c09a"))
	_label("Familias  •  Clima  •  Reinos  •  Geracoes", Vector2(576, 686), Vector2(680, 24), 15, Color("#d4c09a"))

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
	news_label.text = "Crônica: " + world.news
	pause_button.text = "Retomar" if world.speed == 0.0 else "Pausar"
	var display_speed: float = resume_speed if world.speed == 0.0 else world.speed
	speed_button.text = "0.5x" if display_speed == 0.5 else "%.0fx" % display_speed
	war_button.text = "Guerras: sim" if world.wars else "Guerras: nao"
	rival_button.text = "Rivais: sim" if world.rivals else "Rivais: nao"
	predator_button.text = "Animais: sim" if world.predators else "Animais: nao"
	control_button.text = "Soltar controle" if controlled_id > 0 else "Controlar"
	if is_instance_valid(view_button):
		view_button.text = "Voltar ao mapa" if character_view else "Entrar no mundo"
	if selected_beast_id > 0:
		var beast: Dictionary = world.get_beast(selected_beast_id)
		if not beast.is_empty():
			info_label.text = "%s • %s\nVida: %d\nAbra a ficha para detalhes." % [str(beast["name"]), str(beast["species"]), int(float(beast["health"]))]
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
			info_label.text = "%s • %d anos\n%s | %s\n%s" % [str(p["name"]), int(float(p["age"])), home, profession, str(p["role"])]
			return
	if selected_town_id > 0:
		var t: Dictionary = world.get_town(selected_town_id)
		if not t.is_empty():
			var ruler: Dictionary = world.get_person(int(t["leader"]))
			info_label.text = "%s • Era %d\n%d habitantes | %s\nComida %d • Madeira %d" % [str(t["name"]), int(t["level"]), world.active_population(int(t["id"])), str(ruler.get("name", "Sem lider")), int(float(t["food"])), int(float(t["wood"]))]
			return
	info_label.text = "Mundo vivo: observe aldeias, linhagens, sucessoes, crescimento e disputas.\nSelecione uma pessoa ou uma aldeia no mapa para descobrir sua historia."

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

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#151c18"), true)
	# Molduras de madeira e ouro inspiradas na referencia, sem esconder o mapa jogavel.
	_draw_panel(Rect2(9, 77, 853, 454), Color("#29362d"))
	_draw_panel(Rect2(865, 74, 408, 232), Color("#2e3027"))
	_draw_panel(Rect2(865, 305, 408, 231), Color("#33291e"))
	_draw_panel(Rect2(9, 534, 1264, 181), Color("#231f1a"))
	for rect in [Rect2(17, 539, 300, 139), Rect2(324, 539, 297, 139), Rect2(628, 539, 302, 139), Rect2(937, 539, 328, 139)]:
		_draw_panel(rect, Color("#403425"))
	draw_rect(MAP_AREA, Color("#426d47"), true)
	draw_rect(Rect2(874, 336, 390, 61), Color("#262821"), true)
	draw_rect(Rect2(874, 336, 390, 61), Color("#846b43"), false, 1.5)
	var scale_size := TILE_SIZE * zoom
	for y in range(world.tiles.size()):
		var row: Array = world.tiles[y]
		for x in range(row.size()):
			var position := _world_to_screen(Vector2(x, y))
			var tile_rect := Rect2(position, Vector2(scale_size + 0.5, scale_size + 0.5))
			if not tile_rect.intersects(MAP_AREA):
				continue
			var clipped_tile: Rect2 = tile_rect.intersection(MAP_AREA)
			if clipped_tile.size.x <= 0.0 or clipped_tile.size.y <= 0.0:
				continue
			var tile: String = _terrain_type(str(row[x]))
			if tile_textures.has(tile):
				var tile_texture: Texture2D = tile_textures[tile]
				var region := Rect2((clipped_tile.position - tile_rect.position) / tile_rect.size * tile_texture.get_size(), clipped_tile.size / tile_rect.size * tile_texture.get_size())
				draw_texture_rect_region(tile_texture, clipped_tile, region)
			else:
				draw_rect(clipped_tile, Color("#528c55"), true)
	# Vilarejos construidos com cabanas, hortas e fogueiras visiveis.
	for town in world.towns:
		var center := _world_to_screen(Vector2(float(town["x"]) + 0.5, float(town["y"]) + 0.5))
		if center.x < MAP_AREA.position.x - 100 or center.x > MAP_AREA.end.x + 100:
			continue
		if center.y < MAP_AREA.position.y - 100 or center.y > MAP_AREA.end.y + 100:
			continue
		var unit := TILE_SIZE * zoom
		_draw_sprite("farm", center + Vector2(-1.4, 1.15) * unit, Vector2(1.5, 1.5) * unit, true)
		_draw_sprite("hut", center + Vector2(0.0, -0.35) * unit, Vector2(1.85, 1.85) * unit, true)
		if int(town.get("houses", 2)) >= 2:
			_draw_sprite("hut", center + Vector2(1.6, 0.35) * unit, Vector2(1.45, 1.45) * unit, true)
		if int(town.get("houses", 2)) >= 3:
			_draw_sprite("hut", center + Vector2(-1.25, -0.75) * unit, Vector2(1.35, 1.35) * unit, true)
		_draw_sprite("fire", center + Vector2(0.7, 1.0) * unit, Vector2(1.2, 1.2) * unit, true)
		if int(town["id"]) == selected_town_id:
			draw_arc(center, 35.0 * zoom, 0, TAU, 32, Color("#fff0a0"), 3.0)
	# Personagens separados visualmente por idade e aparencia.
	for p in world.people:
		if not bool(p["alive"]):
			continue
		var center := _world_to_screen(Vector2(float(p["x"]) + 0.5, float(p["y"]) + 0.5))
		if not MAP_AREA.has_point(center):
			continue
		var key := "child" if float(p["age"]) < 16.0 else ("person_m" if int(p["gender"]) == 0 else "person_f")
		_draw_sprite(key, center, Vector2(30, 30) * zoom, true)
		if int(p["id"]) == selected_person_id:
			draw_arc(center, 14.0 * zoom, 0, TAU, 20, Color("#ffe890"), 2.0)
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
	# Miniaturas com arte do proprio mundo, estacoes, geracoes e eras.
	var biomes := ["sand", "forest", "snow"]
	for i in range(biomes.size()):
		_draw_tile_card(biomes[i], Rect2(31 + i * 96, 579, 86, 73))
	var seasons := ["grass_spring", "grass", "grass_autumn", "snow"]
	for i in range(seasons.size()):
		_draw_tile_card(seasons[i], Rect2(337 + i * 70, 580, 62, 73))
	var ages := ["child", "person_m", "person_f", "person_m"]
	for i in range(ages.size()):
		var p := Vector2(661 + i * 72, 619)
		draw_rect(Rect2(p - Vector2(29, 37), Vector2(61, 75)), Color("#756344"), true)
		_draw_sprite(ages[i], p, Vector2(43, 56))
		if i < 3:
			draw_line(p + Vector2(30, 0), p + Vector2(40, 0), Color("#f4d588"), 2.0)
	var upgrades := ["hut", "farm", "hut"]
	for i in range(upgrades.size()):
		var p := Vector2(979 + i * 88, 617)
		draw_rect(Rect2(p - Vector2(35, 36), Vector2(77, 73)), Color("#655136"), true)
		_draw_sprite(upgrades[i], p, Vector2(72, 67))
		if i < 2:
			draw_line(p + Vector2(39, 0), p + Vector2(51, 0), Color("#f4d588"), 2.0)
	draw_line(Vector2(15, 680), Vector2(1265, 680), Color("#9c824b"), 2.0)
	var portrait := "hut"
	if selected_beast_id > 0:
		var chosen_beast: Dictionary = world.get_beast(selected_beast_id)
		portrait = "bear" if str(chosen_beast.get("species", "")) == "Urso" else "wolf"
	elif selected_person_id > 0:
		var chosen_person: Dictionary = world.get_person(selected_person_id)
		if not chosen_person.is_empty():
			portrait = "child" if float(chosen_person["age"]) < 16.0 else ("person_m" if int(chosen_person["gender"]) == 0 else "person_f")
	_draw_sprite(portrait, Vector2(913, 370), Vector2(60, 60))

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
			elif RIGHT_VIEW.has_point(touch.position):
				_toggle_view()
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
			if mouse.pressed and (MAP_AREA.has_point(mouse.position) or RIGHT_VIEW.has_point(mouse.position)):
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
		zoom = clampf(zoom * (current_distance / pinch_distance), 0.55, 3.5)
		map_offset = center - MAP_ORIGIN - anchor * TILE_SIZE * zoom
		_clamp_map()
	pinch_distance = current_distance
	pinch_midpoint = center

func _zoom_around(screen_point: Vector2, desired_zoom: float) -> void:
	var anchor: Vector2 = _screen_to_world(screen_point)
	zoom = clampf(desired_zoom, 0.55, 3.5)
	map_offset = screen_point - MAP_ORIGIN - anchor * TILE_SIZE * zoom
	_clamp_map()

func _touch_map(position: Vector2) -> void:
	if RIGHT_VIEW.has_point(position):
		_toggle_view()
		return
	if character_view:
		if controlled_id > 0:
			var actor: Dictionary = world.get_actor(controlled_id)
			if not actor.is_empty():
				var d: Vector2 = (position - MAP_AREA.get_center()).normalized()
				actor["target_x"] = clampf(float(actor["x"]) + d.x * 2.4, 1.0, float(World.SIZE - 2))
				actor["target_y"] = clampf(float(actor["y"]) + d.y * 2.4, 1.0, float(World.SIZE - 2))
		return
	var point := _screen_to_world(position)
	if point.x < -0.5 or point.y < -0.5 or point.x > World.SIZE or point.y > World.SIZE:
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
				actor["target_x"] = clampf(point.x - 0.5, 1.0, World.SIZE - 2.0)
				actor["target_y"] = clampf(point.y - 0.5, 1.0, World.SIZE - 2.0)
		else:
			selected_person_id = 0
			selected_beast_id = 0
			selected_town_id = 0
	_refresh_ui()

func _move_controlled(delta: float) -> void:
	if controlled_id <= 0 or world.speed <= 0.0:
		return
	var p: Dictionary = world.get_actor(controlled_id)
	if p.is_empty() or not bool(p["alive"]):
		controlled_id = 0
		return
	var direction := Vector2(float(p["target_x"]) - float(p["x"]), float(p["target_y"]) - float(p["y"]))
	if direction.length() > 0.04:
		var step := direction.limit_length(delta * world.speed * 2.4)
		p["x"] = clampf(float(p["x"]) + step.x, 1.0, float(World.SIZE - 2))
		p["y"] = clampf(float(p["y"]) + step.y, 1.0, float(World.SIZE - 2))

func _clamp_map() -> void:
	var side: float = float(World.SIZE) * TILE_SIZE * zoom
	if side <= MAP_AREA.size.x:
		map_offset.x = MAP_AREA.get_center().x - MAP_ORIGIN.x - side * 0.5
	else:
		var minimum_x: float = MAP_AREA.end.x - MAP_ORIGIN.x - side
		var maximum_x: float = MAP_AREA.position.x - MAP_ORIGIN.x
		map_offset.x = clampf(map_offset.x, minimum_x, maximum_x)
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

func _toggle_view() -> void:
	if not character_view and controlled_id <= 0:
		var candidate_id: int = selected_person_id if selected_person_id > 0 else selected_beast_id
		if candidate_id <= 0:
			for p in world.people:
				if bool(p["alive"]) and float(p["age"]) >= 16.0:
					candidate_id = int(p["id"])
					selected_person_id = candidate_id
					break
		var actor: Dictionary = world.get_actor(candidate_id)
		if not actor.is_empty() and bool(actor["alive"]):
			controlled_id = candidate_id
	if controlled_id <= 0:
		world.news = "Escolha um habitante ou animal para entrar na visao de personagem."
		character_view = false
	else:
		character_view = not character_view
		world.news = "Toque na paisagem para caminhar." if character_view else "Observando a civilizacao."
	if is_instance_valid(character_clip):
		character_clip.visible = character_view
	_refresh_ui()

func _focus_at(point: Vector2) -> void:
	map_offset = MAP_AREA.get_center() - MAP_ORIGIN - point * TILE_SIZE * zoom
	_clamp_map()

func _focus_biome(kind: String) -> void:
	character_view = false
	if is_instance_valid(character_clip):
		character_clip.visible = false
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
		if is_instance_valid(character_clip):
			character_clip.visible = false
		world.news = "Voce voltou a observar o mundo."
	elif selected_person_id > 0 or selected_beast_id > 0:
		var target_id := selected_person_id if selected_person_id > 0 else selected_beast_id
		var actor: Dictionary = world.get_actor(target_id)
		if not actor.is_empty() and bool(actor["alive"]):
			controlled_id = target_id
			world.news = "Agora voce controla " + str(actor["name"]) + ". Toque no mapa para andar."
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
	popup.add_item("Verificar atualizacoes", 0)
	popup.add_item("Criar novo mundo", 1)
	popup.add_item("Salvar mundo", 2)
	popup.add_item("Ir para primeira vila", 3)
	popup.add_item("Ver ficha completa", 4)
	popup.id_pressed.connect(func(which: int) -> void:
		match which:
			0: _check_updates()
			1: _new_world()
			2: _save_now()
			3:
				if not world.towns.is_empty():
					var t: Dictionary = world.towns[0]
					character_view = false
					if is_instance_valid(character_clip):
						character_clip.visible = false
					_focus_at(Vector2(float(t["x"]) + 0.5, float(t["y"]) + 0.5))
			4: _show_details()
		popup.queue_free()
	)
	add_child(popup)
	popup.popup_centered(Vector2i(350, 260))

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
		if is_instance_valid(character_clip):
			character_clip.visible = false
		map_offset = Vector2.ZERO
		zoom = 1.0
		world.save_world()
		_refresh_ui()
	)
	dialog.popup_centered()
	dialog.close_requested.connect(dialog.queue_free)
