extends PanelContainer
## Ficha de inspeção do mapa. O ator é o mesmo dicionário que a simulação atualiza.

signal chronicles_requested

const World = preload("res://scripts/world.gd")
const GOLD := Color("#c19c5b")
const INK := Color("#201c18")
const CREAM := Color("#ffedc4")

var actor: Dictionary
var world: World
var human: bool
var name_label: Label
var identity: Label
var age_level: Label
var health_text: Label
var health_bar: ProgressBar
var occupation: Label
var equipment: Label
var extra: Label
var portrait: TextureRect
var image_provider: Callable

func _draw() -> void:
	var inset := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	draw_rect(inset, Color("#66523a"), false, 1.0)
	for corner in [inset.position, Vector2(inset.end.x, inset.position.y), inset.end, Vector2(inset.position.x, inset.end.y)]:
		var point: Vector2 = corner
		draw_colored_polygon(PackedVector2Array([point + Vector2.UP * 3, point + Vector2.RIGHT * 3, point + Vector2.DOWN * 3, point + Vector2.LEFT * 3]), GOLD)

func _panel(fill: Color, edge: Color, border: int, inset: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(border)
	style.set_corner_radius_all(4)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, inset)
	return style

func _label(parent: Container, size_pt: int, tint: Color = CREAM) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size_pt)
	label.add_theme_color_override("font_color", tint)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(label)
	return label

func _action(parent: Container, caption: String) -> Button:
	var control := Button.new()
	control.text = caption
	control.custom_minimum_size = Vector2(44, 40)
	control.add_theme_font_size_override("font_size", 16)
	control.add_theme_color_override("font_color", CREAM)
	control.add_theme_stylebox_override("normal", _panel(Color("#392b20"), Color("#84673e"), 1, 7))
	control.add_theme_stylebox_override("hover", _panel(Color("#58412a"), GOLD, 1, 7))
	control.add_theme_stylebox_override("pressed", _panel(INK, GOLD, 1, 7))
	parent.add_child(control)
	return control

func _rule(parent: Container) -> void:
	var line := ColorRect.new()
	line.color = Color("#6f5839")
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

func display(sim: World, subject: Dictionary, is_human: bool, get_portrait: Callable) -> void:
	world = sim
	actor = subject
	human = is_human
	image_provider = get_portrait
	if human:
		world.init_traits(actor)
	else:
		world.init_animal_health(actor)
	name = "FichaDoMapa"
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _panel(INK, GOLD, 2, 14))
	custom_minimum_size.x = 354
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	add_child(body)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	body.add_child(top)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(84, 84)
	frame.add_theme_stylebox_override("panel", _panel(Color("#51402d") if human else Color("#36432d"), GOLD, 2, 3))
	top.add_child(frame)
	portrait = TextureRect.new()
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(portrait)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 1)
	top.add_child(heading)
	name_label = _label(heading, 23)
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Noto Serif", "Georgia", "serif"])
	serif.font_weight = 700
	name_label.add_theme_font_override("font", serif)
	identity = _label(heading, 15, GOLD)
	age_level = _label(heading, 16)
	var close := _action(top, "×")
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.tooltip_text = "Fechar ficha"
	close.pressed.connect(_dismiss)
	var hp := HBoxContainer.new()
	body.add_child(hp)
	var heart := _label(hp, 18, Color("#ed7664"))
	heart.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	heart.text = "♥"
	health_text = _label(hp, 17)
	health_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_bar = ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.custom_minimum_size.y = 9
	health_bar.add_theme_stylebox_override("background", _panel(Color("#3a3026"), Color("#6f5839"), 1, 0))
	health_bar.add_theme_stylebox_override("fill", _panel(Color("#89b859"), Color("#a9ca76"), 1, 0))
	body.add_child(health_bar)
	_rule(body)
	occupation = _label(body, 17)
	equipment = _label(body, 16)
	equipment.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	equipment.custom_minimum_size.y = 24
	equipment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	extra = _label(body, 15, Color("#d4c3a4"))
	if human:
		var details := _action(body, "Ver crônicas")
		details.pressed.connect(func() -> void: chronicles_requested.emit())
	refresh()
	reset_size()

func _age(years: float) -> String:
	if years < 1:
		var months := int(years * 12)
		return "< 1 mês" if months == 0 else ("%d mês" if months == 1 else "%d meses") % months
	return "%d ano" % int(years) if int(years) == 1 else "%d anos" % int(years)

func refresh() -> void:
	if not is_visible_in_tree(): return
	if human:
		var sex := "Homem" if int(actor.get("gender", 0)) == 0 else "Mulher"
		name_label.text = str(actor["name"])
		identity.text = "Humano · " + sex
		age_level.text = "%s · Nível %d" % [_age(float(actor["age"])), int(actor["level"])]
		occupation.text = "Profissão  " + str(actor.get("profession", "Habitante")).replace("Crianca", "Criança")
		var items := PackedStringArray()
		for key in ["weapon_kind", "tool_kind", "shield_kind"]:
			var kind := str(actor.get(key, ""))
			if not kind.is_empty(): items.append(str(World.RESOURCE_NAMES.get(kind, kind)))
		if actor.get("witch_staff", false): items.append("Cajado do brejo")
		equipment.text = "Equipamento  " + (" · ".join(items) if not items.is_empty() else "Nenhum")
		extra.visible = false
	else:
		var species := str(actor["species"])
		var translated := str(World.SPAWN_NAMES.get(species, species))
		name_label.text = str(actor.get("name", translated))
		identity.text = "Animal"
		if actor.has("gender"): identity.text += " · Fêmea" if int(actor["gender"]) == 1 else " · Macho"
		age_level.text = "%s · Nível %d" % [_age(world.animal_age(actor)), world.animal_level(actor)]
		occupation.text = "Espécie  " + translated
		equipment.text = "Saciedade  %d%%     Dano  %d" % [int(100.0 - float(actor.get("hunger", 0))), int(world.animal_damage(actor))]
		extra.text = str(actor.get("state", ""))
		extra.visible = not extra.text.is_empty()
	var hp := maxf(0.0, float(actor.get("health", 0)))
	var max_hp := world.max_hp(actor) if human else float(actor["max_health"])
	health_text.text = "Vida   %d / %d" % [ceili(hp), int(max_hp)]
	health_bar.max_value = max_hp
	health_bar.value = hp
	portrait.texture = image_provider.call(actor, human)

func _dismiss() -> void:
	hide()
	queue_free()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		_dismiss()
		get_viewport().set_input_as_handled()
