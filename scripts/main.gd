extends Node2D
## Legado das Eras — tela jogavel. A simulacao permanece em world.gd.
const World = preload("res://scripts/world.gd")
const Updates = preload("res://scripts/update_manager.gd")
const CharacterWorld3D = preload("res://scripts/character_3d.gd")
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
var zoom := 1.43
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
var character_world: Node3D
var character_view := false
var look_yaw := 0.0
var joystick_touch := -1
var look_touch := -1
var joystick_center := Vector2.ZERO
var joystick_direction := Vector2.ZERO
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
	viewport_3d = SubViewport.new()
	viewport_3d.size = Vector2i(int(MAP_AREA.size.x), int(MAP_AREA.size.y))
	viewport_3d.own_world_3d = true
	viewport_3d.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport_3d.disable_3d = false
	viewport_3d.transparent_bg = false
	add_child(viewport_3d)
	character_world = CharacterWorld3D.new()
	character_world.game = self
	viewport_3d.add_child(character_world)
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
	if character_view and is_instance_valid(character_world):
		var actor: Dictionary = world.get_actor(controlled_id)
		if not actor.is_empty():
			character_world.follow(actor, look_yaw)
		if character_world.last_build_signature != character_world._build_signature():
			character_world.rebuild()

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
	# Um unico mapa imersivo; todas as mecanicas ficam no menu do mundo.
	_label("LEGADO DAS ERAS", Vector2(22, 7), Vector2(260, 40), 25, Color("#f4d48b"))
	stats_label = _label("", Vector2(277, 14), Vector2(382, 27), 16, Color("#ecdec1"))
	news_label = _label("", Vector2(22, 48), Vector2(1040, 24), 15, Color("#edd0a0"))
	news_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	speed_button = _button("1x", Vector2(737, 15), Vector2(72, 38), Callable(self, "_change_speed"))
	pause_button = _button("Pausar", Vector2(813, 15), Vector2(82, 38), Callable(self, "_toggle_pause"))
	_button("Construir", Vector2(899, 15), Vector2(112, 38), Callable(self, "_show_construction"))
	view_button = _button("Explorar", Vector2(1015, 15), Vector2(100, 38), Callable(self, "_toggle_view"))
	_button("Mundo", Vector2(1119, 15), Vector2(73, 38), Callable(self, "_show_options"))
	_button("Atualizar", Vector2(1196, 15), Vector2(80, 38), Callable(self, "_check_updates"))
	info_label = _label("", Vector2(32, 660), Vector2(1150, 26), 16, Color("#fff0bb"))
	info_label.visible = false

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
		view_button.text = "Mapa" if character_view else "Explorar"
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

func _draw() -> void:
	# Interface discreta: mapa em quase toda a area util do aparelho.
	draw_rect(Rect2(0, 0, 1280, 720), Color("#141e1a"), true)
	draw_rect(Rect2(0, 0, 1280, 75), Color("#211e19"), true)
	draw_line(Vector2(0, 74), Vector2(1280, 74), Color("#ae8c54"), 2.0)
	_draw_clock()
	draw_rect(MAP_AREA, Color("#355943"), true)
	if character_view:
		if is_instance_valid(viewport_3d):
			draw_texture_rect(viewport_3d.get_texture(), MAP_AREA, false)
		draw_rect(MAP_AREA, Color("#af986c", 0.28), false, 2.0)
		_draw_character_hud()
		return
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
		# A terra cultivada cresce quando uma fazenda fica pronta.
		for i in range(mini(int(town.get("farms", 1)), farm_spots.size())):
			var spot: Vector2 = farm_spots[i]
			_draw_sprite("farm", center + spot * unit, Vector2(1.32, 1.32) * unit, true)
		for i in range(mini(int(town.get("houses", 2)), house_spots.size())):
			var spot: Vector2 = house_spots[i]
			var house_size: float = 1.62 if i == 0 else 1.35
			_draw_sprite("hut", center + spot * unit, Vector2(house_size, house_size) * unit, true)
		_draw_sprite("fire", center + Vector2(0.7, 1.0) * unit, Vector2(1.2, 1.2) * unit, true)
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
			var scaffold: Vector2 = center + build_spot * unit
			if MAP_AREA.has_point(scaffold):
				draw_line(scaffold + Vector2(-15, 10) * zoom, scaffold + Vector2(15, -21) * zoom, Color("#ddbe7e"), maxf(1.0, 3.0 * zoom))
				draw_line(scaffold + Vector2(15, 10) * zoom, scaffold + Vector2(-15, -21) * zoom, Color("#b78c5d"), maxf(1.0, 3.0 * zoom))
		if int(town["id"]) == selected_town_id and MAP_AREA.has_point(center):
			draw_arc(center, 35.0 * zoom, 0.0, TAU, 32, Color("#fff0a0"), 3.0)
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

func _draw_clock() -> void:
	var c := Vector2(705, 34)
	draw_circle(c, 24.0, Color("#4a3829"))
	draw_circle(c, 19.0, Color("#d9c38c"))
	draw_circle(c, 16.5, Color("#423b2c"))
	for hour in range(12):
		var a: float = float(hour) * TAU / 12.0 - PI * 0.5
		draw_line(c + Vector2(cos(a), sin(a)) * 13.0, c + Vector2(cos(a), sin(a)) * 16.0, Color("#f7dfa4"), 1.5)
	var minutes: float = fposmod(world.day, 1.0)
	var angle: float = minutes * TAU - PI * 0.5
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
	draw_rect(Rect2(840, 643, 405, 42), Color("#1c2a21", 0.8), true)
	draw_string(ThemeDB.fallback_font, Vector2(854, 670), "Analógico: andar  •  lado direito: olhar", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#f8e0b3"))


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
