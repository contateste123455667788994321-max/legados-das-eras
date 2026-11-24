extends Node3D
## Cena tridimensional exploravel, construida a partir do mesmo mundo da simulacao.
## Sem download de texturas: objetos de baixa geometria, materiais e luz dinamica.
const SPACING := 3.0
var game
var camera: Camera3D
var root_mesh: Node3D
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var materials: Dictionary = {}
var last_build_signature := ""
var last_world_id := 0
var actors_3d: Dictionary = {}

func _ready() -> void:
	root_mesh = Node3D.new()
	add_child(root_mesh)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 79.0
	camera.near = 0.08
	camera.far = 125.0
	add_child(camera)
	# Machado em primeiro plano: modelo 3D acompanha a camera, como no conceito visual.
	var grip := _box(camera, Vector3(0.62, -0.54, -0.96), Vector3(0.11, 0.90, 0.11), "#75462e")
	grip.rotation.z = 0.28
	var wood_stripe := _box(camera, Vector3(0.60, -0.54, -0.86), Vector3(0.035, 0.77, 0.04), "#c79557")
	wood_stripe.rotation.z = 0.28
	var head := _box(camera, Vector3(0.49, -0.13, -0.98), Vector3(0.42, 0.24, 0.14), "#718381")
	head.rotation.z = -0.10
	_box(camera, Vector3(0.30, -0.11, -0.97), Vector3(0.11, 0.20, 0.13), "#d4dfd6")

	sun = DirectionalLight3D.new()
	sun.light_energy = 1.15
	sun.light_color = Color("#fff0cf")
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-53.0, -34.0, 0.0)
	add_child(sun)
	world_env = WorldEnvironment.new()
	var env := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#397cae")
	sky_material.sky_horizon_color = Color("#b8d9df")
	sky_material.ground_horizon_color = Color("#a7b9a0")
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.fog_enabled = true
	env.fog_light_color = Color("#b5cbd0")
	env.fog_density = 0.008
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#afc8bf")
	env.ambient_light_energy = 0.58
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.environment = env
	add_child(world_env)

func _mat(hex_color: String) -> StandardMaterial3D:
	if materials.has(hex_color):
		return materials[hex_color]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex_color)
	m.roughness = 0.92
	m.metallic = 0.0
	materials[hex_color] = m
	return m

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	instance.mesh = shape
	instance.material_override = _mat(color)
	instance.position = pos
	parent.add_child(instance)
	return instance

func _cone(parent: Node3D, pos: Vector3, height: float, width: float, color: String, sides: int = 7) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = width
	mesh.height = height
	mesh.radial_segments = maxi(4, sides)
	instance.mesh = mesh
	instance.material_override = _mat(color)
	instance.position = pos
	parent.add_child(instance)
	return instance

func _cylinder(parent: Node3D, pos: Vector3, height: float, radius: float, color: String, sides: int = 7) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = maxi(5, sides)
	instance.mesh = mesh
	instance.material_override = _mat(color)
	instance.position = pos
	parent.add_child(instance)
	return instance

func _sphere(parent: Node3D, pos: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.9
	mesh.height = 1.8
	mesh.radial_segments = 16
	mesh.rings = 9
	instance.mesh = mesh
	instance.material_override = _mat(color)
	instance.position = pos
	instance.scale = size
	parent.add_child(instance)
	return instance

func _rng(x: int, y: int, salt: int) -> float:
	return float(posmod(x * 1567 + y * 4187 + salt * 3571, 997)) / 997.0

func _tree(parent: Node3D, p: Vector3, pine: bool, height: float, snowy: bool = false) -> void:
	_cylinder(parent, p + Vector3(0, height * 0.25, 0), height * 0.52, 0.12, "#624832")
	if pine:
		_cone(parent, p + Vector3(0, height * 0.68, 0), height * 0.70, height * 0.35, "#234b3b", 7)
		_cone(parent, p + Vector3(0, height * 0.97, 0), height * 0.55, height * 0.27, "#357451" if not snowy else "#b8d7cd", 7)
		_cone(parent, p + Vector3(0, height * 1.20, 0), height * 0.42, height * 0.18, "#4b9871" if not snowy else "#e7f4ed", 7)
	else:
		_sphere(parent, p + Vector3(0, height * 0.87, 0), Vector3(height * 0.44, height * 0.35, height * 0.42), "#285a38")
		_sphere(parent, p + Vector3(-height * 0.18, height * 0.98, 0.0), Vector3(height * 0.27, height * 0.30, height * 0.29), "#3c814d")
		_sphere(parent, p + Vector3(height * 0.13, height * 1.10, 0.06), Vector3(height * 0.28, height * 0.26, height * 0.31), "#5c9b53")

func _hut(parent: Node3D, p: Vector3, size: float = 1.0) -> void:
	_box(parent, p + Vector3(0.0, 0.6, 0.0) * size, Vector3(1.55, 1.2, 1.3) * size, "#95633f")
	_box(parent, p + Vector3(-0.56, 0.65, 0.665) * size, Vector3(0.16, 0.55, 0.065) * size, "#cba56d")
	_box(parent, p + Vector3(0.0, 0.39, 0.67) * size, Vector3(0.45, 0.78, 0.075) * size, "#372a22")
	_box(parent, p + Vector3(0.0, 1.26, 0.0) * size, Vector3(1.9, 0.16, 1.65) * size, "#5b3927")
	var roof := _cone(parent, p + Vector3(0.0, 1.63, 0.0) * size, 0.83 * size, 1.26 * size, "#c68c47", 4)
	roof.rotation.y = PI * 0.25
	_box(parent, p + Vector3(0.0, 1.82, 0.0) * size, Vector3(0.28, 0.15, 0.28) * size, "#efb956")

func _farm(parent: Node3D, p: Vector3) -> void:
	_box(parent, p, Vector3(1.9, 0.10, 1.65), "#674f32")
	for row in range(4):
		for col in range(5):
			var dx: float = -0.76 + float(col) * 0.38
			var dz: float = -0.6 + float(row) * 0.42
			_cone(parent, p + Vector3(dx, 0.25, dz), 0.33, 0.12, "#86a549", 5)
	for edge in [-0.98, 0.98]:
		_box(parent, p + Vector3(edge, 0.12, 0), Vector3(0.09, 0.25, 1.8), "#b58b57")

func _fire(parent: Node3D, p: Vector3) -> void:
	for i in range(6):
		var angle: float = float(i) * TAU / 6.0
		var q := p + Vector3(cos(angle) * 0.33, 0.12, sin(angle) * 0.33)
		_sphere(parent, q, Vector3(0.2, 0.12, 0.20), "#777a70")
	_cone(parent, p + Vector3(0, 0.37, 0), 0.74, 0.23, "#ff9036", 6)
	_cone(parent, p + Vector3(0, 0.36, 0), 0.45, 0.12, "#ffde65", 6)

func _settlement(town: Dictionary) -> void:
	var p := Vector3((float(town["x"]) + 0.5) * SPACING, 0.0, (float(town["y"]) + 0.5) * SPACING)
	var houses: int = mini(int(town.get("houses", 2)), 8)
	var farms: int = mini(int(town.get("farms", 1)), 6)
	var offsets: Array[Vector2] = [
		Vector2(0, 0), Vector2(2.1, 1.0), Vector2(-2.0, -1.4),
		Vector2(2.6, -1.4), Vector2(-2.8, 1.7), Vector2(0, -3.0),
		Vector2(-0.6, 3.0), Vector2(3.5, 2.9)
	]
	for i in range(houses):
		var v: Vector2 = offsets[i]
		_hut(root_mesh, p + Vector3(v.x, 0, v.y), 0.89 if i > 0 else 1.08)
	for i in range(farms):
		_farm(root_mesh, p + Vector3(-2.0 + float(i % 3) * 2.8, 0.04, 3.2 + float(i / 3) * 2.2))
	_fire(root_mesh, p + Vector3(1.4, 0.0, 2.4))

func _make_person_3d(person: Dictionary) -> Node3D:
	var figure := Node3D.new()
	root_mesh.add_child(figure)
	var is_child: bool = float(person.get("age", 20.0)) < 16.0
	var scale_factor: float = 0.68 if is_child else 1.0
	figure.scale = Vector3.ONE * scale_factor
	var female: bool = int(person.get("gender", 0)) == 1
	var outfit: String = "#a06c4e" if female else "#517550"
	if str(person.get("profession", "")) == "Guarda":
		outfit = "#667581"
	elif str(person.get("profession", "")) == "Agricultor":
		outfit = "#a98b4b"
	elif str(person.get("profession", "")) == "Construtor":
		outfit = "#6e7555"
	_box(figure, Vector3(0.0, 0.91, 0.0), Vector3(0.48, 0.68, 0.30), outfit)
	_box(figure, Vector3(0.0, 1.43, 0.0), Vector3(0.39, 0.43, 0.38), "#d8a67d")
	_box(figure, Vector3(0.0, 1.67, -0.01), Vector3(0.43, 0.12, 0.40), "#533d30")
	for side in [-1, 1]:
		_box(figure, Vector3(float(side) * 0.35, 0.85, 0.0), Vector3(0.20, 0.68, 0.22), "#cb9871")
		_box(figure, Vector3(float(side) * 0.14, 0.35, 0.0), Vector3(0.22, 0.64, 0.27), "#584c3b")
		_box(figure, Vector3(float(side) * 0.14, 0.08, -0.045), Vector3(0.25, 0.17, 0.33), "#392e25")
	_box(figure, Vector3(-0.10, 1.47, -0.20), Vector3(0.065, 0.067, 0.02), "#2b2a27")
	_box(figure, Vector3(0.10, 1.47, -0.20), Vector3(0.065, 0.067, 0.02), "#2b2a27")
	return figure

func _refresh_people_models() -> void:
	for person in game.world.people:
		if not bool(person.get("alive", false)):
			continue
		var id: int = int(person["id"])
		if actors_3d.has(id):
			continue
		actors_3d[id] = _make_person_3d(person)
	update_people()

func update_people() -> void:
	for person in game.world.people:
		var id: int = int(person["id"])
		if not actors_3d.has(id):
			continue
		var figure: Node3D = actors_3d[id]
		if not is_instance_valid(figure):
			continue
		figure.visible = bool(person.get("alive", false)) and id != game.controlled_id
		figure.position = Vector3((float(person["x"]) + 0.5) * SPACING, 0.0, (float(person["y"]) + 0.5) * SPACING)
		var d := Vector2(float(person.get("target_x", person["x"])) - float(person["x"]), float(person.get("target_y", person["y"])) - float(person["y"]))
		if d.length_squared() > 0.04:
			figure.rotation.y = atan2(-d.x, -d.y)

func _build_signature() -> String:
	var parts: Array[String] = []
	for town in game.world.towns:
		parts.append("%d:%d:%d" % [int(town["id"]), int(town.get("houses", 2)), int(town.get("farms", 1))])
	return "|".join(parts)

func rebuild() -> void:
	if game == null or game.world.tiles.is_empty() or root_mesh == null:
		return
	for child in root_mesh.get_children():
		root_mesh.remove_child(child)
		child.queue_free()
	actors_3d.clear()
	var season: int = int(game.world.day / 90.0) % 4
	for y in range(game.world.tiles.size()):
		var row: Array = game.world.tiles[y]
		for x in range(row.size()):
			var biome: String = str(row[x])
			var px: float = (float(x) + 0.5) * SPACING
			var pz: float = (float(y) + 0.5) * SPACING
			var base_color := "#638d51"
			match biome:
				"water": base_color = "#327f9d"
				"forest": base_color = "#366c42"
				"sand": base_color = "#d3b476"
				"snow": base_color = "#cfddd5"
				"mountain": base_color = "#687d76"
				_: base_color = "#8e994e" if season == 2 else "#638d51"
			_box(root_mesh, Vector3(px, -0.13, pz), Vector3(SPACING + 0.025, 0.26, SPACING + 0.025), base_color)
			if biome == "mountain":
				_cone(root_mesh, Vector3(px, 1.12, pz), 2.5, 1.5, "#56675f", 5)
				_cone(root_mesh, Vector3(px, 2.15, pz), 1.25, 0.75, "#bfcbc5", 5)
			elif biome == "forest" and _rng(x, y, 1) > 0.27:
				_tree(root_mesh, Vector3(px - 0.50, 0.0, pz - 0.35), _rng(x,y,2)>0.50, 2.0 + _rng(x,y,3) * 1.5)
				if _rng(x, y, 4) > 0.73:
					_tree(root_mesh, Vector3(px + 0.8, 0.0, pz + 0.72), true, 1.7)
			elif biome == "snow" and _rng(x, y, 5) > 0.35:
				_tree(root_mesh, Vector3(px - 0.3, 0.0, pz + 0.25), true, 2.6, true)
			elif biome == "sand" and _rng(x, y, 6) > 0.69:
				_cylinder(root_mesh, Vector3(px, 0.37, pz), 0.75, 0.13, "#4a8260")
				_box(root_mesh, Vector3(px + 0.22, 0.52, pz), Vector3(0.36, 0.1, 0.13), "#4a8260")
			elif biome == "grass" and _rng(x, y, 7) > 0.93:
				_tree(root_mesh, Vector3(px - 0.15, 0.0, pz + 0.2), false, 2.35)
	for town in game.world.towns:
		_settlement(town)
	_refresh_people_models()
	last_build_signature = _build_signature()

func follow(actor: Dictionary, yaw: float, pitch: float = 0.0) -> void:
	if camera == null or actor.is_empty():
		return
	camera.position = Vector3((float(actor["x"]) + 0.5) * SPACING, 1.7, (float(actor["y"]) + 0.5) * SPACING)
	camera.rotation = Vector3(pitch, yaw, 0.0)
