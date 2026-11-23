extends Node2D
## Legado das Eras — tela jogavel. A simulacao permanece em world.gd.
const World = preload("res://scripts/world.gd")
const Updates = preload("res://scripts/update_manager.gd")
const TILE_SIZE := 28.0
const MAP_ORIGIN := Vector2(80.0, 294.0)
const MAP_AREA := Rect2(28.0, 276.0, 664.0, 595.0)
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
	_build_ui()
	add_child(Updates.new())
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

func _build_ui() -> void:
	var background := Color("#101b28")
	var top := ColorRect.new()
	top.color = background
	top.position = Vector2.ZERO
	top.size = Vector2(720, 274)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)

	var title := _label("LEGADO DAS ERAS", Vector2(24, 20), Vector2(670, 55), 34, Color("#f3d993"))
	title.add_theme_color_override("font_shadow_color", Color("#17222a"))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 2)
	stats_label = _label("", Vector2(24, 81), Vector2(672, 70), 21, Color("#e5e9e6"))
	news_label = _label("", Vector2(24, 158), Vector2(672, 36), 18, Color("#eac889"))
	news_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	pause_button = _button("Pausar", Vector2(24, 211), Vector2(159, 55), Callable(self, "_toggle_pause"))
	speed_button = _button("Velocidade 1x", Vector2(195, 211), Vector2(184, 55), Callable(self, "_change_speed"))
	_button("Zoom -", Vector2(391, 211), Vector2(139, 55), Callable(self, "_zoom_out"))
	_button("Zoom +", Vector2(542, 211), Vector2(154, 55), Callable(self, "_zoom_in"))

	var below := ColorRect.new()
	below.position = Vector2(0, 878)
	below.size = Vector2(720, 402)
	below.color = background
	below.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(below)

	info_label = _label("", Vector2(24, 891), Vector2(666, 98), 20, Color("#f4f5ed"))
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control_button = _button("Controlar pessoa", Vector2(24, 996), Vector2(216, 55), Callable(self, "_toggle_control"))
	war_button = _button("Guerras: nao", Vector2(252, 996), Vector2(210, 55), Callable(self, "_toggle_war"))
	_button("Salvar", Vector2(474, 996), Vector2(220, 55), Callable(self, "_save_now"))
	rival_button = _button("Rivais: nao", Vector2(24, 1065), Vector2(215, 55), Callable(self, "_toggle_rivals"))
	predator_button = _button("Feras: nao", Vector2(251, 1065), Vector2(211, 55), Callable(self, "_toggle_predators"))
	_button("Novo mundo", Vector2(474, 1065), Vector2(220, 55), Callable(self, "_new_world"))
	_button("Diplomacia", Vector2(474, 1134), Vector2(220, 55), Callable(self, "_show_diplomacy"))
	var tip := _label("Toque nas aldeias para negociar. Assuma personagens e animais para explorar.", Vector2(24, 1134), Vector2(438, 100), 18, Color("#a8c1c5"))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

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
	style.bg_color = Color("#274a51")
	style.corner_radius_top_left = 13
	style.corner_radius_top_right = 13
	style.corner_radius_bottom_left = 13
	style.corner_radius_bottom_right = 13
	style.border_width_bottom = 2
	style.border_color = Color("#6c948a")
	b.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color("#356b67")
	b.add_theme_stylebox_override("hover", hover)
	var pressed_style := style.duplicate()
	pressed_style.bg_color = Color("#183e40")
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
	stats_label.text = "Ano %d • Dia %d    |    %d habitantes    |    %d aldeias" % [years + 1, day_of_year, living, world.towns.size()]
	last_news = world.news
	news_label.text = "Crônica: " + world.news
	pause_button.text = "Retomar" if world.speed == 0.0 else "Pausar"
	speed_button.text = "Velocidade %dx" % int(maxf(1.0, world.speed))
	war_button.text = "Guerras: sim" if world.wars else "Guerras: nao"
	rival_button.text = "Rivais: sim" if world.rivals else "Rivais: nao"
	predator_button.text = "Feras: sim" if world.predators else "Feras: nao"
	control_button.text = "Soltar controle" if controlled_id > 0 else "Controlar personagem"
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

func _draw() -> void:
	draw_rect(MAP_AREA, Color("#112b36"), true)
	draw_rect(MAP_AREA, Color("#50726a"), false, 3.0)
	var palette := {
		"grass": Color("#53966d"), "water": Color("#2a7a9c"),
		"sand": Color("#d4be83"), "forest": Color("#285d45"),
		"snow": Color("#d5e6de"), "mountain": Color("#687d83")
	}
	var scale_size := TILE_SIZE * zoom
	for y in range(world.tiles.size()):
		var row: Array = world.tiles[y]
		for x in range(row.size()):
			var position := _world_to_screen(Vector2(x, y))
			var tile_rect := Rect2(position, Vector2(scale_size + 0.6, scale_size + 0.6))
			if not tile_rect.intersects(MAP_AREA):
				continue
			draw_rect(tile_rect, palette.get(str(row[x]), palette["grass"]), true)
			if str(row[x]) == "forest":
				draw_circle(position + Vector2.ONE * scale_size * 0.5, 2.6 * zoom, Color("#17392d"))
			elif str(row[x]) == "mountain":
				var peak := position + Vector2(scale_size * 0.5, scale_size * 0.23)
				draw_line(position + Vector2(2, scale_size - 3), peak, Color("#334d59"), 2.0)
				draw_line(peak, position + Vector2(scale_size - 2, scale_size - 3), Color("#334d59"), 2.0)
	for t in world.towns:
		var center := _world_to_screen(Vector2(float(t["x"]) + 0.5, float(t["y"]) + 0.5))
		if not MAP_AREA.has_point(center):
			continue
		var color := Color("#d18d75") if bool(t["hostile"]) else Color("#f9dc8c")
		draw_circle(center, 10 * zoom, Color("#18333c"))
		draw_rect(Rect2(center - Vector2(6, 7) * zoom, Vector2(12, 14) * zoom), color, true)
		draw_line(center + Vector2(-8, -7) * zoom, center + Vector2(0, -15) * zoom, color, 4.0 * zoom)
		draw_line(center + Vector2(0, -15) * zoom, center + Vector2(8, -7) * zoom, color, 4.0 * zoom)
		if int(t["id"]) == selected_town_id:
			draw_arc(center, 17 * zoom, 0, TAU, 24, Color.YELLOW, 3.0)
	for p in world.people:
		if not bool(p["alive"]):
			continue
		var center := _world_to_screen(Vector2(float(p["x"]) + 0.5, float(p["y"]) + 0.5))
		if not MAP_AREA.has_point(center):
			continue
		var skin := Color("#f4d6b1") if int(p["gender"]) == 0 else Color("#f3bcd2")
		var radius := maxf(2.5, 4.0 * zoom)
		draw_circle(center, radius + 1.0, Color("#253039"))
		draw_circle(center, radius, skin)
		if int(p["id"]) == selected_person_id:
			draw_arc(center, 9 * zoom, 0, TAU, 20, Color.YELLOW, 2.0)
		if int(p["id"]) == controlled_id:
			draw_arc(center, 13 * zoom, 0, TAU, 20, Color("#88f5e8"), 3.0)
	for b in world.beasts:
		if not bool(b["alive"]):
			continue
		var center := _world_to_screen(Vector2(float(b["x"]) + 0.5, float(b["y"]) + 0.5))
		if MAP_AREA.has_point(center):
			draw_circle(center, (7 if b["species"] == "Urso" else 5) * zoom, Color("#543633"))
			if int(b["id"]) == selected_beast_id:
				draw_arc(center, 10 * zoom, 0, TAU, 20, Color.YELLOW, 2.0)
			if int(b["id"]) == controlled_id:
				draw_arc(center, 14 * zoom, 0, TAU, 20, Color("#88f5e8"), 3.0)

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
	map_offset.x = clampf(map_offset.x, -map_size + 120.0, 530.0)
	map_offset.y = clampf(map_offset.y, -map_size + 100.0, 540.0)

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
		dialog.get_vbox().add_child(label)
		match label_text:
			"Aldeia de origem": dialog.get_vbox().add_child(first_picker)
			"Aldeia de destino": dialog.get_vbox().add_child(second_picker)
			"Acao diplomatica": dialog.get_vbox().add_child(action_picker)
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
