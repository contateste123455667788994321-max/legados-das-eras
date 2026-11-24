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
var material_grain: NoiseTexture2D
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
	# Ferramenta com silhueta de pedra lascada e mao segurando o cabo.
	var tool := Node3D.new()
	camera.add_child(tool)
	tool.position = Vector3(0.61, -0.43, -1.10)
	tool.rotation.z = 0.34
	var grip := _cylinder(tool, Vector3(0, -0.13, 0), 0.87, 0.055, "#775033", 9)
	grip.rotation.z = -0.10
	var blade := PackedVector2Array([Vector2(-0.28,0.24),Vector2(-0.38,0.10),Vector2(-0.31,-0.07),Vector2(-0.09,-0.13),Vector2(0.12,-0.05),Vector2(0.15,0.11),Vector2(-0.02,0.19)])
	_extruded_blade(tool, Vector3(0,0.27,0), blade)
	for band in range(4):
		_cylinder(tool, Vector3(0.01,0.17+band*0.032,0),0.025,0.079,"#a5885c",8)
	_sphere(tool, Vector3(0,-0.32,0.025),Vector3(0.09,0.13,0.09),"#bb8965")
	_box(tool,Vector3(0.035,-0.55,0.07),Vector3(0.14,0.36,0.15),"#976747")

	sun = DirectionalLight3D.new()
	sun.light_energy = 0.73
	sun.light_color = Color("#fff3dd")
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-53.0, -34.0, 0.0)
	add_child(sun)
	world_env = WorldEnvironment.new()
	var env := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#397eae")
	sky_material.sky_curve = 0.45
	sky_material.sun_angle_max = 12.0
	sky_material.sky_horizon_color = Color("#b8d9df")
	sky_material.ground_horizon_color = Color("#a7b9a0")
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.fog_enabled = true
	env.fog_light_color = Color("#b5cbd0")
	env.fog_density = 0.004
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9db6cb")
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world_env.environment = env
	add_child(world_env)

func _mat(hex_color: String) -> StandardMaterial3D:
	if materials.has(hex_color):
		return materials[hex_color]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex_color)
	if material_grain == null:
		var grain := FastNoiseLite.new()
		grain.frequency = 0.15
		material_grain = NoiseTexture2D.new()
		material_grain.width = 128
		material_grain.height = 128
		material_grain.seamless = true
		material_grain.noise = grain
		var ramp := Gradient.new()
		ramp.set_color(0, Color("#9a9a9a"))
		ramp.set_color(1, Color.WHITE)
		material_grain.color_ramp = ramp
	m.albedo_texture = material_grain
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
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

# Um unico mesh colorido por arvore: folhagem irregular, galhos e sombras,
# em vez de tres esferas gigantes. As faces menores criam textura pixelada.
func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
	st.set_color(tint)
	st.add_vertex(a)
	st.set_color(tint)
	st.add_vertex(b)
	st.set_color(tint)
	st.add_vertex(c)

func _colored_mesh(parent: Node3D, p: Vector3, st: SurfaceTool) -> MeshInstance3D:
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = mat
	instance.position = p
	parent.add_child(instance)
	return instance

func _irregular_cluster(st: SurfaceTool, center: Vector3, radii: Vector3, rng: RandomNumberGenerator, tint: Color, segments: int = 8) -> void:
	var rings: Array[PackedVector3Array] = []
	for j in range(5):
		var lat: float = -PI*0.5 + PI*float(j)/4.0
		var ring := PackedVector3Array()
		for i in range(segments):
			var angle: float = TAU*float(i)/float(segments)
			var jitter: float = rng.randf_range(0.75,1.15)
			ring.append(center + Vector3(cos(angle)*cos(lat)*radii.x*jitter, sin(lat)*radii.y, sin(angle)*cos(lat)*radii.z*jitter))
		rings.append(ring)
	for j in range(4):
		for i in range(segments):
			var n: int = (i+1)%segments
			var shade: float = rng.randf_range(-0.16,0.18) + float(j-1)*0.025
			var col: Color = tint.lightened(shade) if shade > 0 else tint.darkened(-shade)
			_triangle(st, rings[j][i], rings[j+1][i], rings[j+1][n],col)
			_triangle(st, rings[j][i], rings[j+1][n], rings[j][n],col)

func _branch(parent: Node3D, start: Vector3, end: Vector3, radius: float) -> void:
	var d: Vector3 = end-start
	var branch := _cylinder(parent,(start+end)*0.5,d.length(),radius,"#6d4d32",7)
	branch.quaternion = Quaternion(Vector3.UP,d.normalized())

func _tree(parent: Node3D, p: Vector3, pine: bool, height: float, snowy: bool = false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(int(p.x*1138+p.z*7919))
	_cylinder(parent,p+Vector3(0,height*0.46,0),height*0.92,height*0.048,"#6b4930",9)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if pine:
		for tier in range(5):
			var y: float = height*(0.38+float(tier)*0.155)
			var radius: float = height*(0.32-float(tier)*0.045)
			for k in range(7):
				var angle: float = TAU*float(k)/7.0+float(tier)*0.6
				var off := Vector3(cos(angle)*radius*0.66,y,sin(angle)*radius*0.66)
				var tint := Color("#285940").lerp(Color("#5e8d4e"),float(tier)/5.0)
				_irregular_cluster(st,off,Vector3(radius*0.58,height*0.16,radius*0.58),rng,tint,6)
				if snowy:
					_irregular_cluster(st,off+Vector3(0,height*0.095,0),Vector3(radius*0.46,height*0.075,radius*0.46),rng,Color("#c4d6d6"),6)
	else:
		for k in range(7):
			var angle: float = TAU*float(k)/7.0+rng.randf_range(-0.2,0.2)
			var off := Vector3(cos(angle)*height*0.21,height*rng.randf_range(0.65,0.84),sin(angle)*height*0.21)
			_branch(parent,p+Vector3(0,height*0.4,0),p+off,height*0.024)
			for leaf in range(4):
				var q: Vector3 = off+Vector3(rng.randf_range(-0.13,0.13),rng.randf_range(-0.05,0.18),rng.randf_range(-0.13,0.13))*height
				var tint := Color("#305f2e").lerp(Color("#81a943"),rng.randf())
				_irregular_cluster(st,q,Vector3(height*0.14,height*0.12,height*0.14),rng,tint,7)
		for k in range(5):
			_irregular_cluster(st,Vector3(rng.randf_range(-0.1,0.1),rng.randf_range(0.84,1.02),rng.randf_range(-0.1,0.1))*height,Vector3(height*0.17,height*0.13,height*0.17),rng,Color("#5a8b39"),7)
	_colored_mesh(parent,p,st)

func _rock_mass(parent: Node3D,p: Vector3,height: float,width: float,snowy: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(int(p.x*431+p.z*1973))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(7):
		var off := Vector3(rng.randf_range(-0.5,0.5)*width,height*rng.randf_range(0.18,0.5),rng.randf_range(-0.5,0.5)*width)
		var scale_factor: float = rng.randf_range(0.45,0.8)
		_irregular_cluster(st,off,Vector3(width*scale_factor,height*scale_factor,width*scale_factor),rng,Color("#666c64").lerp(Color("#969b8c"),rng.randf()),7)
		if snowy and k%3==0:
			_irregular_cluster(st,off+Vector3(0,height*scale_factor*0.68,0),Vector3(width*scale_factor*0.72,height*0.15,width*scale_factor*0.72),rng,Color("#d1dedb"),7)
	_colored_mesh(parent,p,st)

func _extruded_blade(parent: Node3D,p: Vector3,points: PackedVector2Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()):
		var j: int = (i+1)%points.size()
		var a := Vector3(points[i].x,points[i].y,0.05)
		var b := Vector3(points[j].x,points[j].y,0.05)
		var c := Vector3(points[i].x,points[i].y,-0.05)
		var d := Vector3(points[j].x,points[j].y,-0.05)
		_triangle(st,Vector3(0,0.05,0.078),a,b,Color("#929c9d").darkened(float(i%3)*0.13))
		_triangle(st,Vector3(0,0.05,-0.078),d,c,Color("#727d80"))
		_triangle(st,a,c,d,Color("#b7c3c1"))
		_triangle(st,a,d,b,Color("#b7c3c1"))
	_colored_mesh(parent,p,st)

func _hut(parent: Node3D, p: Vector3, size: float = 1.0, era: int = 1) -> void:
	if era > 1:
		_evolved_house(parent, p, size, era)
		return
	_box(parent, p + Vector3(0.0, 0.6, 0.0) * size, Vector3(1.55, 1.2, 1.3) * size, "#95633f")
	_box(parent, p + Vector3(-0.56, 0.65, 0.665) * size, Vector3(0.16, 0.55, 0.065) * size, "#cba56d")
	_box(parent, p + Vector3(0.0, 0.39, 0.67) * size, Vector3(0.45, 0.78, 0.075) * size, "#372a22")
	_box(parent, p + Vector3(0.0, 1.26, 0.0) * size, Vector3(1.9, 0.16, 1.65) * size, "#5b3927")
	for plank in range(7):
		var yy: float = (0.12 + float(plank) * 0.16) * size
		_box(parent, p + Vector3(0, yy, -0.657 * size), Vector3(1.56 * size, 0.035 * size, 0.035 * size), "#68472e")
		for side in [-1, 1]:
			_box(parent, p + Vector3(float(side) * 0.78 * size, yy, 0), Vector3(0.035, 0.035, 1.31) * size, "#68472e")
	# Telhado de duas aguas com palha em faixas e caibros aparentes.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 781+absi(int(p.x*59+p.z*97))
	for side in [-1,1]:
		for row in range(9):
			for col in range(19):
				var u: float = float(row)/9.0
				var u2: float = float(row+1)/9.0
				var z: float = -0.93+float(col)*0.098
				var tint := Color("#8d622c").lerp(Color("#d6ae59"),rng.randf())
				var bump: float = rng.randf_range(-0.012,0.025)
				var a := Vector3(side*u*1.02,2.13-u*0.91+bump,z)
				var b := Vector3(side*u2*1.02,2.13-u2*0.91+bump,z)
				var cc := Vector3(side*u2*1.02,2.13-u2*0.91+bump,z+0.10)
				var d := Vector3(side*u*1.02,2.13-u*0.91+bump,z+0.10)
				_triangle(st,a*size,b*size,cc*size,tint)
				_triangle(st,a*size,cc*size,d*size,tint.lightened(0.08))
	for edge in [-1,1]:
		_triangle(st,Vector3(-0.82,1.22,edge*0.66)*size,Vector3(0,2.1,edge*0.66)*size,Vector3(0.82,1.22,edge*0.66)*size,Color("#755034"))
	_colored_mesh(parent,p,st)
	for side in [-1,1]:
		for edge in [-1,1]:
			var beam := _box(parent,p+Vector3(side*0.5,1.67,edge*0.95)*size,Vector3(1.4,0.09,0.09)*size,"#6a492e")
			beam.rotation.z = -float(side)*0.72
	_box(parent,p+Vector3(0,2.13,0)*size,Vector3(0.12,0.09,1.94)*size,"#a47d3e")
	for edge in [-1,1]:
		_box(parent,p+Vector3(edge*0.77,0.62,0.68)*size,Vector3(0.11,1.24,0.13)*size,"#65432a")
		_box(parent,p+Vector3(edge*0.52,0.77,-0.67)*size,Vector3(0.26,0.29,0.08)*size,"#342b23")
	_box(parent,p+Vector3(0,0.80,0.70)*size,Vector3(0.58,0.10,0.10)*size,"#5e3f29")

func _evolved_house(parent: Node3D, p: Vector3, size: float, era: int) -> void:
	var wall: String = ["#9e693e", "#9e693e", "#9b947f", "#a0a39a", "#c1c0ad"][clampi(era-1, 0, 4)]
	var roof_color: String = "#b88c4e" if era == 2 else ("#ad633f" if era == 3 else "#59676d")
	var h: float = 1.3 + float(era-2)*0.28
	_box(parent, p + Vector3(0, h*0.5, 0)*size, Vector3(1.7, h, 1.5)*size, wall)
	_box(parent, p + Vector3(0, 0.38, 0.76)*size, Vector3(0.48, 0.76, 0.08)*size, "#3e3026")
	for x in [-0.57, 0.57]:
		_box(parent, p + Vector3(x, h*0.69, 0.77)*size, Vector3(0.28, 0.36, 0.08)*size, "#654e36")
		_box(parent, p + Vector3(x, h*0.69, 0.82)*size, Vector3(0.19, 0.26, 0.02)*size, "#e8c17d")
	for row in range(int(h / 0.2)):
		_box(parent, p + Vector3(0, 0.1+row*0.2, -0.76)*size, Vector3(1.71, 0.022, 0.035)*size, "#706755")
		for side in [-1, 1]:
			_box(parent, p + Vector3(side*0.86, 0.1+row*0.2, 0)*size, Vector3(0.032, 0.025, 1.5)*size, "#706755")
	for side in [-1, 1]:
		var roof := _box(parent, p + Vector3(side*0.48, h+0.31, 0)*size, Vector3(1.2, 0.13, 1.85)*size, roof_color)
		roof.rotation.z = -float(side)*0.56
	if era >= 4:
		_box(parent, p + Vector3(0.52, h+0.51, -0.38)*size, Vector3(0.27, 0.91, 0.27)*size, wall)
	if era == 5:
		for side in [-1, 1]:
			_box(parent, p + Vector3(side*0.96, h*0.63, 0.14)*size, Vector3(0.52, h*1.26, 0.7)*size, wall)
			for k in range(4):
				_box(parent, p + Vector3(side*0.96 + (float(k%2)-0.5)*0.32, h*1.26+0.12, 0.14+(float(k/2)-0.5)*0.48)*size, Vector3(0.15, 0.24, 0.16)*size, wall)

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
		_hut(root_mesh, p + Vector3(v.x, 0, v.y), 0.89 if i > 0 else 1.08, int(town.get("level", 1)))
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
		parts.append("%d:%d:%d:%d" % [int(town["id"]), int(town.get("houses", 2)), int(town.get("farms", 1)), int(town.get("level", 1))])
	return "|".join(parts)

func rebuild() -> void:
	if game == null or game.world.tiles.is_empty() or root_mesh == null:
		return
	for child in root_mesh.get_children():
		root_mesh.remove_child(child)
		child.queue_free()
	actors_3d.clear()
	# O solo inteiro usa o mesmo desenho continuo do mapa, sem centenas de cubos.
	game._make_landscape()
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var length: float = float(game.world.SIZE) * SPACING
	plane.size = Vector2(length, length)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_texture = game.landscape_texture
	ground_material.albedo_color = Color("#c1c5b4")
	ground_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ground_material.roughness = 0.95
	ground.material_override = ground_material
	ground.position = Vector3(length * 0.5, -0.01, length * 0.5)
	root_mesh.add_child(ground)
	var season: int = int(game.world.day / 90.0) % 4
	for y in range(game.world.tiles.size()):
		var row: Array = game.world.tiles[y]
		for x in range(row.size()):
			var biome: String = str(row[x])
			var px: float = (float(x) + 0.5) * SPACING
			var pz: float = (float(y) + 0.5) * SPACING
			if biome == "mountain":
				_rock_mass(root_mesh,Vector3(px,0,pz),2.6+_rng(x,y,31)*1.6,1.25,season==3 or y<8)
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
			elif biome == "grass" and _rng(x, y, 8) > 0.55:
				for clump in range(3):
					var offset := Vector3(_rng(x, y, 11 + clump) * 1.8 - 0.9, 0.12, _rng(x, y, 18 + clump) * 1.8 - 0.9)
					_cone(root_mesh, Vector3(px, 0, pz) + offset, 0.28, 0.14, "#628a36", 4)
	for town in game.world.towns:
		_settlement(town)
	_refresh_people_models()
	last_build_signature = _build_signature()

func follow(actor: Dictionary, yaw: float, pitch: float = 0.0) -> void:
	if camera == null or actor.is_empty():
		return
	camera.position = Vector3((float(actor["x"]) + 0.5) * SPACING, 1.7, (float(actor["y"]) + 0.5) * SPACING)
	camera.rotation = Vector3(pitch, yaw, 0.0)
