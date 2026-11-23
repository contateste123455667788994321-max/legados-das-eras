extends Node2D
## Legado das Eras — tela jogavel. A simulacao permanece em world.gd.
const World = preload("res://scripts/world.gd")
const Updates = preload("res://scripts/update_manager.gd")
const WorldVisual = preload("res://scripts/world_visual.gd")
const TILE_SIZE := 34.0
const MAP_ORIGIN := Vector2(38.0, 115.0)
const MAP_AREA := Rect2(17.0, 109.0, 870.0, 463.0)
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
var autosave_timer := 0.0
var ui_timer := 0.0
var last_news := ""
var tile_textures: Dictionary = {}
var actor_textures: Dictionary = {}
var texture_missing := false
var update_manager: Node
var world_visual: Node2D
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
	_build_ui()
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
	var background := Color("#141d1c")
	var entire := ColorRect.new()
	entire.color = background
	entire.position = Vector2.ZERO
	entire.size = Vector2(1280, 720)
	entire.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(entire)
	var title := _label("LEGADO DAS ERAS", Vector2(26, 13), Vector2(315, 42), 30, Color("#f1d99b"))
	title.add_theme_color_override("font_shadow_color", Color("#0e1411"))
	title.add_theme_constant_override("shadow_offset_y", 2)
	stats_label = _label("", Vector2(340, 15), Vector2(390, 32), 17, Color("#e1e5ce"))
	news_label = _label("", Vector2(27, 77), Vector2(856, 29), 17, Color("#efd59b"))
	news_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_button = _button("Pausar", Vector2(501, 53), Vector2(100, 47), Callable(self, "_toggle_pause"))
	speed_button = _button("1x", Vector2(610, 53), Vector2(87, 47), Callable(self, "_change_speed"))
	_button("Zoom -", Vector2(707, 53), Vector2(88, 47), Callable(self, "_zoom_out"))
	_button("Zoom +", Vector2(802, 53), Vector2(86, 47), Callable(self, "_zoom_in"))
	_label("PERSONAGEM / TRIBO", Vector2(916, 16), Vector2(338, 36), 24, Color("#f0d69b"))
	info_label = _label("", Vector2(911, 152), Vector2(350, 174), 19, Color("#f3e4c9"))
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control_button = _button("Controlar", Vector2(906, 332), Vector2(170, 47), Callable(self, "_toggle_control"))
	war_button = _button("Guerras", Vector2(1081, 332), Vector2(172, 47), Callable(self, "_toggle_war"))
	rival_button = _button("Rivais", Vector2(906, 390), Vector2(170, 47), Callable(self, "_toggle_rivals"))
	predator_button = _button("Animais", Vector2(1081, 390), Vector2(172, 47), Callable(self, "_toggle_predators"))
	_button("Diplomacia", Vector2(906, 449), Vector2(170, 47), Callable(self, "_show_diplomacy"))
	_button("Salvar", Vector2(1081, 449), Vector2(172, 47), Callable(self, "_save_now"))
	_button("Atualizar", Vector2(906, 509), Vector2(170, 47), Callable(self, "_check_updates"))
	_button("Novo mundo", Vector2(1081, 509), Vector2(172, 47), Callable(self, "_new_world"))
	_label("BIOMAS E ESTACOES", Vector2(26, 585), Vector2(520, 26), 20, Color("#f0dbad"))
	_label("FLORESTA", Vector2(110, 660), Vector2(132, 28), 17, Color("#e6d4ac"))
	_label("DESERTO", Vector2(316, 660), Vector2(132, 28), 17, Color("#e6d4ac"))
	_label("NEVE", Vector2(532, 660), Vector2(132, 28), 17, Color("#e6d4ac"))
	_label("MONTANHAS", Vector2(738, 660), Vector2(132, 28), 17, Color("#e6d4ac"))
	_label("MUNDO VIVO", Vector2(909, 583), Vector2(335, 29), 21, Color("#f0d69b"))
	_label("Aldeias • Familias • Estacoes • Evolucao", Vector2(908, 615), Vector2(352, 26), 16, Color("#e4d1b0"))
	_label("Toque nos habitantes e explore o mapa.", Vector2(908, 650), Vector2(352, 44), 15, Color("#a5b9a2"))

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
	speed_button.text = "Velocidade %dx" % int(maxf(1.0, world.speed))
	war_button.text = "Guerras: sim" if world.wars else "Guerras: nao"
	rival_button.text = "Rivais: sim" if world.rivals else "Rivais: nao"
	predator_button.text = "Animais: sim" if world.predators else "Animais: nao"
	control_button.text = "Soltar controle" if controlled_id > 0 else "Controlar"
	if selected_beast_id > 0:
		var beast: Dictionary = world.get_beast(selected_beast_id)
		if not beast.is_empty():
			info_label.text = "%s | %s | Vida: %d\nToque em Controlar para assumir este animal." % [str(beast["name"]), str(beast["species"]), int(float(beast["health"]))]
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
			info_label.text = "%s, %d anos (%s)\n%s • %s • %s%s\nMemoria: %s" % [str(p["name"]), int(float(p["age"])), state, home, str(p["role"]), profession, family, latest_event]
			return
	if selected_town_id > 0:
		var t: Dictionary = world.get_town(selected_town_id)
		if not t.is_empty():
			var ruler: Dictionary = world.get_person(int(t["leader"]))
			info_label.text = "%s | Era %d | %d habitantes\nLider: %s • Comida: %d • Madeira: %d" % [str(t["name"]), int(t["level"]), world.active_population(int(t["id"])), str(ruler.get("name", "Sem lider")), int(float(t["food"])), int(float(t["wood"]))]
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

func _draw_sprite(key: String, center: Vector2, dimensions: Vector2) -> void:
	if not actor_textures.has(key):
		return
	var texture: Texture2D = actor_textures[key]
	draw_texture_rect(texture, Rect2(center - dimensions * 0.5, dimensions), false)

func _draw() -> void:
	# Quadro principal e moldura em tons de madeira, inspirados no estilo pixel art aprovado.
	draw_rect(Rect2(9, 104, 889, 478), Color("#9b773e"), true)
	draw_rect(MAP_AREA, Color("#325b3e"), true)
	draw_rect(Rect2(901, 7, 369, 567), Color("#2c251d"), true)
	draw_rect(Rect2(905, 10, 359, 560), Color("#765a37"), false, 4.0)
	draw_rect(Rect2(904, 48, 362, 106), Color("#382f24"), true)
	draw_rect(Rect2(900, 577, 368, 133), Color("#262a22"), true)
	draw_rect(Rect2(9, 577, 889, 133), Color("#242b23"), true)
	draw_rect(Rect2(12, 580, 883, 126), Color("#876d46"), false, 3.0)
	var scale_size := TILE_SIZE * zoom
	for y in range(world.tiles.size()):
		var row: Array = world.tiles[y]
		for x in range(row.size()):
			var position := _world_to_screen(Vector2(x, y))
			var tile_rect := Rect2(position, Vector2(scale_size + 0.5, scale_size + 0.5))
			if not tile_rect.intersects(MAP_AREA):
				continue
			var tile: String = _terrain_type(str(row[x]))
			if tile_textures.has(tile):
				draw_texture_rect(tile_textures[tile] as Texture2D, tile_rect, false)
			else:
				draw_rect(tile_rect, Color("#528c55"), true)
	# Vilarejos construidos com cabanas, hortas e fogueiras visiveis.
	for town in world.towns:
		var center := _world_to_screen(Vector2(float(town["x"]) + 0.5, float(town["y"]) + 0.5))
		if center.x < MAP_AREA.position.x - 100 or center.x > MAP_AREA.end.x + 100:
			continue
		if center.y < MAP_AREA.position.y - 100 or center.y > MAP_AREA.end.y + 100:
			continue
		var unit := TILE_SIZE * zoom
		_draw_sprite("farm", center + Vector2(-1.4, 1.15) * unit, Vector2(1.5, 1.5) * unit)
		_draw_sprite("hut", center + Vector2(0.0, -0.35) * unit, Vector2(1.85, 1.85) * unit)
		if int(town.get("houses", 2)) >= 2:
			_draw_sprite("hut", center + Vector2(1.6, 0.35) * unit, Vector2(1.45, 1.45) * unit)
		if int(town.get("houses", 2)) >= 3:
			_draw_sprite("hut", center + Vector2(-1.25, -0.75) * unit, Vector2(1.35, 1.35) * unit)
		_draw_sprite("fire", center + Vector2(0.7, 1.0) * unit, Vector2(1.2, 1.2) * unit)
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
		_draw_sprite(key, center, Vector2(30, 30) * zoom)
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
		_draw_sprite(key, center, Vector2(38, 38) * zoom)
		if int(b["id"]) == selected_beast_id:
			draw_arc(center, 15.0 * zoom, 0, TAU, 20, Color("#ffe890"), 2.0)
		if int(b["id"]) == controlled_id:
			draw_arc(center, 19.0 * zoom, 0, TAU, 20, Color("#6cffda"), 3.0)
	# Quatro miniaturas de biomas geradas a partir da mesma arte do mundo.
	var biome_keys := ["forest", "sand", "snow", "mountain"]
	for i in range(biome_keys.size()):
		var x := 22 + i * 212
		draw_rect(Rect2(x, 613, 190, 85), Color("#6d5638"), true)
		var key: String = biome_keys[i]
		if tile_textures.has(key):
			draw_texture_rect(tile_textures[key] as Texture2D, Rect2(x + 5, 618, 180, 38), false)
	# Retrato do personagem ou aldeia selecionados, usando sprites reais.
	var portrait_key := "hut"
	if selected_beast_id > 0:
		portrait_key = "bear" if str(world.get_beast(selected_beast_id).get("species", "")) == "Urso" else "wolf"
	elif selected_person_id > 0:
		var person: Dictionary = world.get_person(selected_person_id)
		if not person.is_empty():
			portrait_key = "child" if float(person["age"]) < 16.0 else ("person_m" if int(person["gender"]) == 0 else "person_f")
	_draw_sprite(portrait_key, Vector2(1063, 100), Vector2(86, 86))

func _world_to_screen(world_pos: Vector2) -> Vector2:
	return MAP_ORIGIN + map_offset + world_pos * TILE_SIZE * zoom

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return (screen_pos - MAP_ORIGIN - map_offset) / (TILE_SIZE * zoom)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and MAP_AREA.has_point(event.position):
			drag_started = event.position
			dragging = true
		elif not event.pressed and dragging:
			if drag_started.distance_to(event.position) < 12.0:
				_touch_map(event.position)
			dragging = false
	elif event is InputEventScreenDrag and dragging:
		if MAP_AREA.has_point(event.position):
			map_offset += event.relative
			_clamp_map()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and MAP_AREA.has_point(event.position):
			drag_started = event.position
			dragging = true
		elif not event.pressed and dragging:
			if drag_started.distance_to(event.position) < 12.0:
				_touch_map(event.position)
			dragging = false
	elif event is InputEventMouseMotion and dragging and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		map_offset += event.relative
		_clamp_map()

func _touch_map(position: Vector2) -> void:
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
	elif controlled_id > 0:
		var actor: Dictionary = world.get_actor(controlled_id)
		if not actor.is_empty():
			actor["target_x"] = clampf(point.x - 0.5, 1.0, World.SIZE - 2.0)
			actor["target_y"] = clampf(point.y - 0.5, 1.0, World.SIZE - 2.0)
	else:
		selected_person_id = 0
		selected_beast_id = 0
		selected_town_id = 0
		for t in world.towns:
			if Vector2(float(t["x"]) + 0.5, float(t["y"]) + 0.5).distance_to(point) < 1.1:
				selected_town_id = int(t["id"])
				break
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
	var map_size := World.SIZE * TILE_SIZE * zoom
	map_offset.x = clampf(map_offset.x, -map_size + 150.0, 790.0)
	map_offset.y = clampf(map_offset.y, -map_size + 90.0, 500.0)

func _toggle_pause() -> void:
	world.speed = 1.0 if world.speed == 0.0 else 0.0
	_refresh_ui()

func _change_speed() -> void:
	if world.speed <= 1.0:
		world.speed = 2.0
	elif world.speed <= 2.0:
		world.speed = 4.0
	else:
		world.speed = 1.0
	_refresh_ui()

func _zoom_in() -> void:
	zoom = minf(zoom + 0.25, 2.0)
	_clamp_map()

func _zoom_out() -> void:
	zoom = maxf(zoom - 0.25, 0.65)
	_clamp_map()

func _toggle_control() -> void:
	if controlled_id > 0:
		controlled_id = 0
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
		map_offset = Vector2.ZERO
		zoom = 1.0
		world.save_world()
		_refresh_ui()
	)
	dialog.popup_centered()
	dialog.close_requested.connect(dialog.queue_free)
