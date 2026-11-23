extends Node2D
## Cenografia procedural: aldeias e biomas desenhados em camadas.
## Sem imagens externas, funciona offline e escala em aparelhos mais simples.
var game
var preview_mode := false

const INK := Color("#182725")
const GOLD := Color("#eed08b")
const SHADOW := Color(0.05, 0.10, 0.09, 0.32)

func _draw() -> void:
	if game == null or game.world.tiles.is_empty():
		return
	var season_id: int = int(game.world.day / 90.0) % 4
	if preview_mode:
		var panel: Rect2 = game.RIGHT_VIEW
		_draw_eyes_view(panel, season_id)
		draw_rect(panel, Color("#d6b376"), false, 3.0)
		draw_rect(Rect2(panel.position.x + 7, panel.position.y + 7, panel.size.x - 14, 24), Color("#1c1b14", 0.77), true)
		return
	var area: Rect2 = game.MAP_AREA
	draw_rect(area, Color("#1a2929"), true)
	if game.character_view:
		_draw_eyes_view(area, season_id)
	else:
		_draw_biome_world(season_id)
		draw_rect(area, GOLD.darkened(0.38), false, 3.0)
		_draw_ornaments(area)

func _screen(p: Vector2) -> Vector2:
	return game._world_to_screen(p)

func _hash(x: int, y: int, salt: int) -> float:
	var n: int = absi((x * 73856093 + y * 19349663 + salt * 83492791) % 9973)
	return float(n) / 9973.0

func _poly(points: Array[Vector2], fill: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), fill)

func _draw_biome_world(season_id: int) -> void:
	var world = game.world
	var side: float = game.TILE_SIZE * game.zoom
	for y in range(world.tiles.size()):
		var row: Array = world.tiles[y]
		for x in range(row.size()):
			var p: Vector2 = _screen(Vector2(x, y))
			if not Rect2(p, Vector2(side, side)).intersects(game.MAP_AREA):
				continue
			var kind: String = str(row[x])
			_ground(p, side, kind, season_id, x, y)
	# Segunda camada: vegetacao, rochas e formas naturais.
	if game.zoom >= 0.72:
		for y in range(world.tiles.size()):
			var row: Array = world.tiles[y]
			for x in range(row.size()):
				var p: Vector2 = _screen(Vector2(x, y))
				if not Rect2(p - Vector2(side, side), Vector2(side * 3.0, side * 3.0)).intersects(game.MAP_AREA):
					continue
				var kind: String = str(row[x])
				var c: Vector2 = p + Vector2(side * 0.5, side * 0.62)
				var rand: float = _hash(x, y, 3)
				match kind:
					"forest":
						_tree(c + Vector2(side * 0.13, side * 0.03), side * 0.53, season_id, rand > 0.45)
						if rand > 0.48:
							_tree(c + Vector2(-side * 0.26, -side * 0.26), side * 0.37, season_id, true)
					"grass":
						if rand > 0.76:
							_tree(c, side * 0.44, season_id, false)
						elif rand > 0.55:
							_flowers(c, side)
					"sand":
						if rand > 0.68:
							_cactus(c, side * 0.54)
						elif rand < 0.16:
							_rock(c, side * 0.48, Color("#aa8259"))
					"snow":
						_tree(c, side * 0.55, 3, true)
						if rand > 0.63:
							_rock(c + Vector2(side * 0.24, side * 0.15), side * 0.30, Color("#96b0b6"))
					"mountain":
						_mountain(c, side * 0.95, season_id)
	# Terceira camada: casas, hortas, paliçadas, fogueiras.
	for town in world.towns:
		_village(town, season_id)
	# Animais e habitantes têm seu próprio desenho, sem pontos coloridos genéricos.
	for person in world.people:
		if bool(person["alive"]):
			var c: Vector2 = _screen(Vector2(float(person["x"]) + 0.5, float(person["y"]) + 0.5))
			if game.MAP_AREA.grow(15).has_point(c):
				_human(c, maxf(0.70, game.zoom), int(person["gender"]), int(person["id"]) == game.controlled_id, int(person["id"]) == game.selected_person_id, float(person["age"]) < 16.0)
	for beast in world.beasts:
		if bool(beast["alive"]):
			var c: Vector2 = _screen(Vector2(float(beast["x"]) + 0.5, float(beast["y"]) + 0.5))
			if game.MAP_AREA.grow(15).has_point(c):
				_animal(c, game.zoom, str(beast["species"]), int(beast["id"]) == game.selected_beast_id or int(beast["id"]) == game.controlled_id)

func _ground(p: Vector2, side: float, kind: String, season_id: int, x: int, y: int) -> void:
	var base: Color
	match kind:
		"water": base = Color("#26779a")
		"sand": base = Color("#ccb174")
		"forest": base = Color("#245d45")
		"snow": base = Color("#cadfdc")
		"mountain": base = Color("#74898b")
		_: base = Color("#65a16c")
	if kind == "grass" or kind == "forest":
		match season_id:
			0: base = base.lightened(0.10)
			2: base = base.lerp(Color("#b07840"), 0.44)
			3: base = base.lerp(Color("#cadbd7"), 0.58)
	draw_rect(Rect2(p, Vector2(side + 0.8, side + 0.8)), base, true)
	if kind == "water":
		for i in range(2):
			var shift: float = (_hash(x, y, i + 10) - 0.5) * side * 0.50
			var off: Vector2 = Vector2(side * 0.15, side * (0.30 + i * 0.30))
			draw_line(p + off + Vector2(shift, 0), p + off + Vector2(side * 0.46 + shift, 0), Color("#87b9bd", 0.62), maxf(1.0, side * 0.065))
	elif kind == "sand":
		var off: float = _hash(x, y, 11)
		draw_line(p + Vector2(side * off * 0.48, side * 0.68), p + Vector2(side * (off * 0.48 + 0.43), side * 0.68), Color("#e9d199", 0.8), maxf(1.0, side * 0.065))
	elif kind == "grass" or kind == "forest":
		for i in range(3):
			var fx: float = _hash(x, y, i + 14)
			var fy: float = _hash(x, y, i + 18)
			var plant: Vector2 = p + Vector2(fx * side, fy * side)
			draw_line(plant, plant + Vector2(-side * 0.075, -side * 0.17), Color("#3c7748", 0.68), maxf(1, side * 0.045))
			draw_line(plant, plant + Vector2(side * 0.075, -side * 0.13), Color("#9fb95c", 0.76), maxf(1, side * 0.035))
	elif kind == "snow":
		var dot: Vector2 = p + Vector2(side * _hash(x, y, 7), side * _hash(x, y, 8))
		draw_circle(dot, maxf(1.0, side * 0.07), Color("#f6faf4", 0.85))

func _tree(c: Vector2, size: float, season_id: int, pine: bool) -> void:
	var trunk: Color = Color("#705039")
	draw_ellipse(c + Vector2(0, size * 0.20), Vector2(size * 0.36, size * 0.14), SHADOW)
	draw_rect(Rect2(c - Vector2(size * 0.09, size * 0.42), Vector2(size * 0.19, size * 0.57)), trunk, true)
	draw_rect(Rect2(c - Vector2(size * 0.04, size * 0.40), Vector2(size * 0.07, size * 0.46)), Color("#ad7951"), true)
	if pine:
		var leaf: Color = Color("#174f40")
		if season_id == 3:
			leaf = Color("#305d58")
		for i in range(3):
			var h: float = size * (0.80 - 0.20 * i)
			var yy: float = c.y + size * 0.08 - i * size * 0.27
			var xx: float = size * (0.41 - i * 0.08)
			_poly([Vector2(c.x, yy - h * 0.46), Vector2(c.x - xx, yy + size * 0.19), Vector2(c.x + xx, yy + size * 0.19)], leaf.lightened(i * 0.08))
			draw_line(Vector2(c.x - xx * 0.38, yy + size * 0.08), Vector2(c.x - xx * 0.11, yy - size * 0.16), Color("#79a78a", 0.5), maxf(1.0, size * 0.055))
		if season_id == 3:
			draw_line(c - Vector2(size * 0.20, size * 0.37), c + Vector2(size * 0.13, -size * 0.37), Color("#eef7f1", 0.86), maxf(1.0, size * 0.10))
	else:
		var foliage: Color = Color("#367d43")
		match season_id:
			0: foliage = Color("#55a35c")
			2: foliage = Color("#c18a3d")
			3: foliage = Color("#6b8880")
		draw_circle(c - Vector2(size * 0.16, size * 0.56), size * 0.36, foliage.darkened(0.22))
		draw_circle(c + Vector2(size * 0.19, size * 0.61), size * 0.34, foliage)
		draw_circle(c - Vector2(size * 0.02, size * 0.87), size * 0.39, foliage.lightened(0.11))
		draw_circle(c - Vector2(size * 0.18, size * 1.01), size * 0.13, Color("#9ac274", 0.48))
		if season_id == 3:
			draw_circle(c - Vector2(size * 0.05, size * 0.95), size * 0.12, Color("#dbe9e5"))

func _draw_ornaments(area: Rect2) -> void:
	for yy in [area.position.y + 5.0, area.end.y - 5.0]:
		draw_line(Vector2(area.position.x + 6, yy), Vector2(area.end.x - 6, yy), Color("#d0aa66", 0.8), 2.0)
	for xx in [area.position.x + 5.0, area.end.x - 5.0]:
		draw_line(Vector2(xx, area.position.y + 5), Vector2(xx, area.end.y - 5), Color("#d0aa66", 0.7), 2.0)

func _mountain(c: Vector2, size: float, season_id: int) -> void:
	draw_ellipse(c + Vector2(0, size * 0.19), Vector2(size * 0.88, size * 0.21), SHADOW)
	_poly([c + Vector2(-size * 0.52, size * 0.17), c + Vector2(size * 0.07, -size * 0.80), c + Vector2(size * 0.52, size * 0.17)], Color("#5b6d71"))
	_poly([c + Vector2(size * 0.07, -size * 0.80), c + Vector2(size * 0.52, size * 0.17), c + Vector2(0, size * 0.04)], Color("#97a4a0"))
	_poly([c + Vector2(-size * 0.16, -size * 0.45), c + Vector2(size * 0.07, -size * 0.80), c + Vector2(size * 0.26, -size * 0.37), c + Vector2(size * 0.04, -size * 0.48)], Color("#e2e8de") if season_id == 3 else Color("#c2c6bf"))

func _cactus(c: Vector2, s: float) -> void:
	draw_ellipse(c + Vector2(0, s * 0.26), Vector2(s * 0.30, s * 0.12), SHADOW)
	draw_line(c + Vector2(0, s * 0.18), c - Vector2(0, s * 0.78), Color("#286e51"), maxf(2.0, s * 0.23))
	draw_line(c - Vector2(s * 0.10, 0), c - Vector2(s * 0.36, s * 0.18), Color("#318364"), maxf(2, s * 0.13))
	draw_line(c - Vector2(s * 0.36, s * 0.18), c - Vector2(s * 0.36, s * 0.44), Color("#318364"), maxf(2, s * 0.13))
	draw_line(c + Vector2(s * 0.10, -s * 0.15), c + Vector2(s * 0.33, -s * 0.23), Color("#318364"), maxf(2, s * 0.13))
	draw_line(c + Vector2(s * 0.33, -s * 0.23), c + Vector2(s * 0.33, -s * 0.48), Color("#318364"), maxf(2, s * 0.13))

func _rock(c: Vector2, s: float, color: Color) -> void:
	_poly([c + Vector2(-s * 0.6, 0), c + Vector2(-s * 0.25, -s * 0.55), c + Vector2(s * 0.35, -s * 0.45), c + Vector2(s * 0.6, s * 0.10)], color)
	_poly([c + Vector2(-s * 0.25, -s * 0.55), c + Vector2(s * 0.35, -s * 0.45), c + Vector2(s * 0.09, -s * 0.23)], color.lightened(0.28))

func _flowers(c: Vector2, s: float) -> void:
	for i in range(3):
		var p: Vector2 = c + Vector2((i - 1) * s * 0.22, float(i % 2) * s * 0.16)
		draw_line(p + Vector2(0, 3), p - Vector2(0, s * 0.11), Color("#3c7e49"), maxf(1.0, s * 0.055))
		draw_circle(p - Vector2(0, s * 0.12), maxf(1.1, s * 0.06), Color("#f4d76a") if i == 0 else Color("#f1a9ad"))

func _village(town: Dictionary, season_id: int) -> void:
	var center: Vector2 = _screen(Vector2(float(town["x"]) + 0.5, float(town["y"]) + 0.5))
	if not game.MAP_AREA.grow(95.0).has_point(center):
		return
	var k: float = game.zoom
	var hostile: bool = bool(town["hostile"])
	var base: Color = Color("#765137") if hostile else Color("#88613d")
	# Clareira, caminhos de terra, cercas e campos cultivados.
	draw_ellipse(center + Vector2(0, 10 * k), Vector2(53, 31) * k, Color("#b39e67", 0.76))
	draw_line(center + Vector2(-44, 18) * k, center + Vector2(58, 26) * k, Color("#a8885b"), 9.0 * k)
	draw_line(center + Vector2(12, -30) * k, center + Vector2(-8, 35) * k, Color("#ccb58a"), 8.0 * k)
	_field(center + Vector2(-38, 24) * k, 24 * k, season_id)
	_house(center + Vector2(-27, -12) * k, 19.0 * k, base, int(town["level"]))
	_house(center + Vector2(30, -10) * k, 23.0 * k, base, int(town["level"]))
	_house(center + Vector2(22, 28) * k, 17.0 * k, base, int(town["level"]))
	_fire(center + Vector2(-4, 8) * k, 14.0 * k)
	for i in range(6):
		var a: float = float(i) * TAU / 6.0
		var c: Vector2 = center + Vector2(cos(a) * 45.0, sin(a) * 26.0) * k
		_fence(c, k)
	# Bandeira e aro de selecao.
	draw_line(center + Vector2(-6, -40) * k, center + Vector2(-6, -65) * k, Color("#55442d"), 2.6 * k)
	_poly([center + Vector2(-6, -63) * k, center + Vector2(17, -58) * k, center + Vector2(-6, -51) * k], Color("#af4d40") if hostile else Color("#e4c66e"))
	if int(town["id"]) == game.selected_town_id:
		draw_arc(center, 54 * k, 0.0, TAU, 36, Color("#ffe1a1"), 3.0)

func _house(c: Vector2, size: float, wood: Color, level: int) -> void:
	var w: float = size * 0.97
	var h: float = size * 0.65
	draw_ellipse(c + Vector2(0, h * 0.44), Vector2(w * 0.78, h * 0.28), SHADOW)
	draw_rect(Rect2(c + Vector2(-w * 0.52, -h * 0.35), Vector2(w * 1.04, h)), wood, true)
	draw_rect(Rect2(c + Vector2(-w * 0.36, -h * 0.17), Vector2(w * 0.72, h * 0.75)), wood.lightened(0.17), true)
	_poly([c + Vector2(-w * 0.66, -h * 0.37), c + Vector2(0, -h * 1.28), c + Vector2(w * 0.68, -h * 0.37)], Color("#382b25"))
	_poly([c + Vector2(-w * 0.50, -h * 0.45), c + Vector2(0, -h * 1.12), c + Vector2(w * 0.50, -h * 0.45)], Color("#c79b4e") if level < 3 else Color("#7c777b"))
	for i in range(4):
		var xx: float = c.x - w * 0.43 + i * w * 0.28
		draw_line(Vector2(xx, c.y - h * 0.56), Vector2(c.x, c.y - h * 1.11), Color("#f0cd73", 0.55), maxf(1.0, size * 0.038))
	draw_rect(Rect2(c + Vector2(-w * 0.12, h * 0.00), Vector2(w * 0.24, h * 0.65)), Color("#322d26"), true)
	draw_rect(Rect2(c + Vector2(-w * 0.37, -h * 0.05), Vector2(w * 0.15, h * 0.20)), Color("#e9c77d"), true)

func _field(c: Vector2, size: float, season_id: int) -> void:
	_poly([c + Vector2(-size * 0.54, -size * 0.30), c + Vector2(size * 0.51, -size * 0.28), c + Vector2(size * 0.71, size * 0.35), c + Vector2(-size * 0.35, size * 0.33)], Color("#5b412d"))
	for i in range(4):
		var crop: Color = Color("#e6b85a") if season_id == 2 else Color("#76ac50")
		draw_line(c + Vector2(-size * 0.40 + i * size * 0.27, -size * 0.22), c + Vector2(-size * 0.24 + i * size * 0.27, size * 0.26), crop, maxf(1.0, size * 0.11))

func _fire(c: Vector2, s: float) -> void:
	draw_ellipse(c + Vector2(0, s * 0.14), Vector2(s * 0.48, s * 0.25), Color("#352b24"))
	for i in range(5):
		var off: float = (i - 2) * s * 0.18
		draw_circle(c + Vector2(off, s * 0.13), s * 0.11, Color("#89918a"))
	_poly([c + Vector2(-s * 0.18, s * 0.07), c + Vector2(-s * 0.15, -s * 0.61), c + Vector2(0, -s * 0.27), c + Vector2(s * 0.10, -s * 0.84), c + Vector2(s * 0.22, s * 0.06)], Color("#ed873b"))
	_poly([c + Vector2(-s * 0.08, s * 0.04), c + Vector2(0, -s * 0.51), c + Vector2(s * 0.10, s * 0.03)], Color("#f9df7d"))

func _fence(c: Vector2, k: float) -> void:
	draw_line(c + Vector2(-7, -3) * k, c + Vector2(7, -3) * k, Color("#5e4331"), 3.0 * k)
	draw_line(c + Vector2(-7, 2) * k, c + Vector2(7, 2) * k, Color("#ab8258"), 2.5 * k)
	for dx in [-6, 0, 6]:
		draw_line(c + Vector2(dx, -7) * k, c + Vector2(dx, 6) * k, Color("#755036"), 2.8 * k)

func _human(c: Vector2, size: float, gender: int, controlled: bool, selected: bool, child: bool) -> void:
	var s: float = size * (0.70 if child else 1.0)
	if selected or controlled:
		draw_arc(c + Vector2(0, -3.0 * s), 12.0 * s, 0.0, TAU, 18, Color("#f5da75") if selected else Color("#70e6db"), 2.0)
	draw_ellipse(c + Vector2(0, 4 * s), Vector2(6, 2.5) * s, SHADOW)
	var cloak: Color = Color("#485b79") if gender == 0 else Color("#9c563f")
	draw_rect(Rect2(c + Vector2(-3.4, -8.0) * s, Vector2(6.8, 9.0) * s), cloak, true)
	draw_line(c + Vector2(-2, 1) * s, c + Vector2(-2, 6.0) * s, Color("#4a3b30"), 2.6 * s)
	draw_line(c + Vector2(2, 1) * s, c + Vector2(2, 6.0) * s, Color("#4a3b30"), 2.6 * s)
	draw_circle(c + Vector2(0, -10.8) * s, 3.5 * s, Color("#f3c79a"))
	draw_line(c + Vector2(-3, -13) * s, c + Vector2(2, -14) * s, Color("#583b2c"), 2.0 * s)
	draw_line(c + Vector2(-2.8, -6) * s, c + Vector2(-6, -1) * s, Color("#e5bd8b"), 2.3 * s)

func _animal(c: Vector2, size: float, species: String, selected: bool) -> void:
	var s: float = size
	if selected:
		draw_arc(c, 11.0 * s, 0.0, TAU, 18, GOLD, 2.2)
	var fur: Color = Color("#735642") if species == "Urso" else Color("#6b746f")
	var body: float = 6.4 if species == "Urso" else 4.5
	draw_ellipse(c + Vector2(0, 4) * s, Vector2(9, 2.4) * s, SHADOW)
	draw_ellipse(c, Vector2(body * 1.6, body * 0.75) * s, fur)
	draw_circle(c + Vector2(6, -3.2) * s, body * 0.73 * s, fur.lightened(0.10))
	draw_circle(c + Vector2(8.5, -5) * s, 1.1 * s, Color("#262323"))
	for dx in [-4, 4]:
		draw_line(c + Vector2(dx, 0) * s, c + Vector2(dx, 7) * s, fur.darkened(0.24), 2.0 * s)

func _draw_eyes_view(area: Rect2, season_id: int) -> void:
	var pos: Vector2 = area.position
	var w: float = area.size.x
	var h: float = area.size.y
	var biome := "grass"
	var camera_shift := 0.0
	var subject: Dictionary = game.world.get_actor(game.controlled_id)
	if subject.is_empty():
		subject = game.world.get_actor(game.selected_person_id)
	if not subject.is_empty():
		var tile_x: int = clampi(int(float(subject["x"])), 0, game.world.SIZE - 1)
		var tile_y: int = clampi(int(float(subject["y"])), 0, game.world.SIZE - 1)
		var tile_row: Array = game.world.tiles[tile_y]
		biome = str(tile_row[tile_x])
		camera_shift = fmod(float(subject["x"]) * 15.0 + float(subject["y"]) * 9.0, 28.0)
	var near_village := false
	for town in game.world.towns:
		if not subject.is_empty():
			var distance := Vector2(float(town["x"]), float(town["y"])).distance_to(Vector2(float(subject["x"]), float(subject["y"])))
			if distance < 3.5:
				near_village = true
				break
	else:
		near_village = true
	var sky: Color = Color("#d9c18d") if biome == "sand" else (Color("#b8d7e3") if biome == "snow" or season_id == 3 else Color("#9cd0d9"))
	draw_rect(area, sky, true)
	for i in range(8):
		var yy: float = pos.y + float(i) * h * 0.052
		draw_rect(Rect2(pos.x, yy, w, h * 0.052), sky.lerp(Color("#e9dfb3"), float(i) / 14.0))
	# Montanhas, nuvens, linha das arvores e o solo.
	for i in range(4):
		var cx: float = pos.x + w * (0.18 + i * 0.28)
		var cy: float = pos.y + h * 0.42
		_poly([Vector2(cx - w * 0.24, cy), Vector2(cx, cy - h * (0.32 + i * 0.018)), Vector2(cx + w * 0.29, cy)], Color("#788e87") if season_id != 3 else Color("#9fb8b8"))
		_poly([Vector2(cx - 25, cy - h * 0.20), Vector2(cx, cy - h * (0.32 + i * 0.018)), Vector2(cx + 34, cy - h * 0.18)], Color("#dae8e0"))
	draw_rect(Rect2(pos.x, pos.y + h * 0.42, w, h * 0.58), Color("#6b9b62") if season_id != 3 else Color("#cadbd6"))
	var ground: Color = Color("#d7ba7b") if biome == "sand" else (Color("#c3d6d6") if biome == "snow" else Color("#609361"))
	if biome != "sand" and biome != "snow" and season_id == 2:
		ground = Color("#a18e56")
	elif season_id == 3 or biome == "snow":
		ground = Color("#b7cdca")
	draw_rect(Rect2(pos.x, pos.y + h * 0.56, w, h * 0.44), ground)
	_poly([Vector2(pos.x + w * 0.50, pos.y + h * 0.51), Vector2(pos.x + w * 0.57, pos.y + h * 0.51), Vector2(pos.x + w * 0.90, area.end.y), Vector2(pos.x + w * 0.08, area.end.y)], Color("#ad9b72"))
	_poly([Vector2(pos.x + w * 0.50, pos.y + h * 0.51), Vector2(pos.x + w * 0.53, pos.y + h * 0.51), Vector2(pos.x + w * 0.70, area.end.y), Vector2(pos.x + w * 0.34, area.end.y)], Color("#cbb78c"))
	for i in range(6):
		var depth: float = float(i) / 6.0
		var height: float = 40.0 + 65.0 * depth
		var left: Vector2 = Vector2(pos.x + 30.0 + i * 65.0 - camera_shift, pos.y + h * (0.52 + depth * 0.14))
		var right: Vector2 = Vector2(pos.x + w - 15.0 - i * 48.0 + camera_shift, pos.y + h * (0.58 + depth * 0.14))
		if biome == "sand":
			_cactus(left, height * 0.65)
			_rock(right, height * 0.36, Color("#ac885e"))
		elif biome == "mountain":
			_mountain(left, height * 1.12, season_id)
			_tree(right, height * 0.55, season_id, true)
		else:
			var local_season: int = 3 if biome == "snow" else season_id
			_tree(left, height, local_season, true)
			_tree(right, height * 0.73, local_season, i % 2 == 0)
	if near_village:
		_house(Vector2(pos.x + w * 0.74, pos.y + h * 0.58), w * 0.20, Color("#93673e"), 1)
		_house(Vector2(pos.x + w * 0.20, pos.y + h * 0.57), w * 0.17, Color("#836039"), 1)
		_fire(Vector2(pos.x + w * 0.47, pos.y + h * 0.68), 23)
	# Primeiro plano: ferramenta vista pela mao do personagem.
	var grip: Vector2 = Vector2(pos.x + w * 0.84, pos.y + h * 0.82)
	draw_line(grip + Vector2(0, h * 0.32), grip - Vector2(60, 140), Color("#4a3225"), 22.0)
	draw_line(grip + Vector2(1, h * 0.30), grip - Vector2(59, 140), Color("#986b42"), 11.0)
	_poly([grip + Vector2(-65, -149), grip + Vector2(-121, -171), grip + Vector2(-93, -212), grip + Vector2(-39, -177), grip + Vector2(-48, -148)], Color("#7a8788"))
	_poly([grip + Vector2(-65, -149), grip + Vector2(-121, -171), grip + Vector2(-93, -186), grip + Vector2(-48, -172)], Color("#c3cdca"))
	_ornamental_vignette(area)

func _ornamental_vignette(area: Rect2) -> void:
	draw_rect(area, Color("#273c35", 0.42), false, 7.0)
	draw_line(area.position + Vector2(12, 11), area.position + Vector2(65, 11), GOLD, 3.0)
	draw_line(area.end - Vector2(65, 11), area.end - Vector2(12, 11), GOLD, 3.0)

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts: Array[Vector2] = []
	for i in range(17):
		var angle: float = float(i) / 16.0 * TAU
		pts.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	_poly(pts, color)
