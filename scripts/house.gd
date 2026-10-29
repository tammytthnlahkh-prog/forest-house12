extends Node3D
## البيت: ممر على شكل L يتكرر (على طريقة P.T.) — ست ليالٍ، في كل ليلة غرض يجب إيجاده
## لفتح الباب في نهاية الممر. كل ليلة يتغيّر البيت ويزداد الرعب.

const PlayerScript := preload("res://scripts/player.gd")
const EntityScript := preload("res://scripts/entity.gd")
const FONT := preload("res://fonts/DejaVuSans.ttf")
const FONT_BOLD := preload("res://fonts/DejaVuSans-Bold.ttf")

const H := 2.8
const T := 0.2
const LOOP_COUNT := 6
const START_POS := Vector3(0.0, 0.05, 0.7)
const DOOR_HINGE := Vector3(-9.95, 0.0, -9.4)

var loop_titles: Array = [
	["الليلة الأولى", "الصمت"],
	["الليلة الثانية", "الهمس"],
	["الليلة الثالثة", "الطَّرق"],
	["الليلة الرابعة", "الصرخة"],
	["الليلة الخامسة", "المطاردة"],
	["الليلة السادسة", "الفجر ما زال بعيدًا"],
]

var items_def: Array = [
	{"id": "photo", "name": "صورة العائلة", "pos": Vector3(-0.95, 0.85, -2.5),
		"where": "على الطاولة الخشبية قرب الجدار",
		"hint": "اضغط E — التقاط الصورة",
		"note": "صورة العائلة... كل الوجوه مخدوشة، إلا وجه طفلة واحدة."},
	{"id": "beads", "name": "مسبحة جدّي", "pos": Vector3(-3.6, 0.45, -5.0),
		"where": "في المجلس، على الطاولة الصغيرة",
		"hint": "اضغط E — التقاط المسبحة",
		"note": "مسبحة جدّي... ما زالت دافئة، كأن أحدًا كان يمسكها قبل لحظة."},
	{"id": "key", "name": "المفتاح الحديدي", "pos": Vector3(3.45, 0.52, -7.85),
		"where": "في غرفة الجدّ، بجانب السرير",
		"hint": "اضغط E — التقاط المفتاح",
		"note": "مفتاح قديم ثقيل... لا أعرف أي باب يفتح."},
	{"id": "lantern", "name": "الفانوس", "pos": Vector3(-7.0, 0.46, -9.25),
		"where": "على المقعد الصغير في آخر الممر",
		"hint": "اضغط E — التقاط الفانوس",
		"note": "فانوس جدّي... ما زال فيه زيت. يبدو أن الضوء يُبعدها قليلًا."},
	{"id": "dallah", "name": "دلّة القهوة", "pos": Vector3(-6.0, 0.36, -3.6),
		"where": "في المجلس، فوق الوسائد",
		"hint": "اضغط E — التقاط الدلّة",
		"note": "دلّة جدّي... ورائحة القهوة ما زالت فيها. من الذي صبّها؟"},
	{"id": "bead", "name": "الخرزة الزرقاء", "pos": Vector3(2.2, 0.07, -7.5),
		"where": "في غرفة الجدّ، على الأرض قرب السرير",
		"hint": "اضغط E — التقاط الخرزة",
		"note": "الخرزة الزرقاء... حِرز جدّي. تبرد في يدي كأنها تنظر إليّ."},
]

var intro_lines: Array = [
	"الباب أُغلق خلفي... لا طريق للعودة. اضغط F لإضاءة الكشاف.",
	"الراديو يعمل وحده... وعودٌ قديم يُعزَف في المجلس.",
	"شيء ما يطرق... من داخل الجدران.",
	"الأنوار تخفت. وهناك من يتنفّس في الممر.",
	"إنها تمشي في البيت. لا تُدِر ظهرك لها... واجعلها تراك.",
	"الليلة الأخيرة. اللعنة أو الفجر.",
]

var mats: Dictionary = {}
var player: Node3D
var entity: Node3D
var env: Environment
var lamps: Array = []
var door_pivot: Node3D
var door_body: StaticBody3D
var door_shape: CollisionShape3D
var vest_light: OmniLight3D
var radio_player: AudioStreamPlayer3D
var hb_player: AudioStreamPlayer
var item_node: Node3D
var carried_light: OmniLight3D
var frames: Array = []
var frame_labels: Array = []
var handprints: Array = []
var writings: Array = []   # {node, min_loop}
var events: Array = []

var loop_index: int = 0
var loop_time: float = 0.0
var door_locked: bool = true
var item_done: bool = false
var busy: bool = true
var player_zone: String = "A"
var lamp_power: float = 1.0
var _flicker: float = 0.0
var _amb_t: float = 25.0
var _guided: bool = false
var _lamp_base: Array = [1.1, 1.0, 0.95, 0.8, 0.65, 0.45]
var _lamp_colors: Array = [
	Color(1.0, 0.82, 0.55), Color(1.0, 0.8, 0.52), Color(0.98, 0.84, 0.6),
	Color(0.7, 0.9, 0.6), Color(1.0, 0.45, 0.3), Color(1.0, 0.25, 0.2)]
var _ambient_e: Array = [0.55, 0.5, 0.45, 0.4, 0.34, 0.28]


# ======================================================================
#  البناء
# ======================================================================
func _ready() -> void:
	randomize()
	_init_materials()
	_make_environment()
	_build_structure()
	_build_props()
	_build_lamps()
	_build_writing()
	_build_player_and_entity()
	_build_audio()
	Game.enter_game_mode()
	await _begin_loop(0, true)


func _tex_mat(tex: String, tiling: float = 0.5, tint: Color = Color.WHITE, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/%s.png" % tex)
	m.albedo_color = tint
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(tiling, tiling, tiling)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _mk_mat(color: Color, rough: float = 0.8, metal: float = 0.0, emit: Color = Color.BLACK, emit_e: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emit_e > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = emit_e
	return m


func _init_materials() -> void:
	mats["wall"] = _tex_mat("wall", 0.5, Color(0.95, 0.92, 0.88))
	mats["floor"] = _tex_mat("floor", 0.5, Color.WHITE, 0.6)
	mats["ceil"] = _tex_mat("ceiling", 0.5)
	mats["carpet"] = _tex_mat("carpet", 0.5, Color.WHITE, 1.0)
	var dm := StandardMaterial3D.new()
	dm.albedo_texture = load("res://textures/door.png")
	dm.roughness = 0.8
	mats["door"] = dm
	mats["wood"] = _mk_mat(Color(0.13, 0.075, 0.045), 0.7)
	mats["wood2"] = _mk_mat(Color(0.22, 0.13, 0.075), 0.6)
	mats["red"] = _mk_mat(Color(0.32, 0.05, 0.06), 1.0)
	mats["navy"] = _mk_mat(Color(0.07, 0.09, 0.2), 1.0)
	mats["brass"] = _mk_mat(Color(0.7, 0.48, 0.16), 0.35, 0.85)
	mats["iron"] = _mk_mat(Color(0.12, 0.12, 0.13), 0.5, 0.8)
	mats["white"] = _mk_mat(Color(0.8, 0.78, 0.7), 0.9)
	mats["dark"] = _mk_mat(Color(0.03, 0.03, 0.03), 1.0)


func _make_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.19, 0.17)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.05, 0.045)
	env.fog_density = 0.035
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _box(center: Vector3, size: Vector3, mat: Material, collide: bool = true, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = center
	(parent if parent else self).add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


func _add(parent: Node, mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _cyl(top: float, bottom: float, h: float, seg: int = 10) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m


func _sph(r: float, seg: int = 10) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = seg
	m.rings = maxi(3, seg / 2)
	return m


func _wx(x: float, za: float, zb: float) -> void:  # جدار على امتداد z
	var z0 := minf(za, zb)
	var z1 := maxf(za, zb)
	_box(Vector3(x, H * 0.5, (z0 + z1) * 0.5), Vector3(T, H, z1 - z0), mats["wall"])


func _wz(z: float, xa: float, xb: float) -> void:  # جدار على امتداد x
	var x0 := minf(xa, xb)
	var x1 := maxf(xa, xb)
	_box(Vector3((x0 + x1) * 0.5, H * 0.5, z), Vector3(x1 - x0, H, T), mats["wall"])


func _lintel_x(x: float, za: float, zb: float, y0: float = 2.2) -> void:
	var z0 := minf(za, zb)
	var z1 := maxf(za, zb)
	_box(Vector3(x, (y0 + H) * 0.5, (z0 + z1) * 0.5), Vector3(T, H - y0, z1 - z0), mats["wall"])


func _build_structure() -> void:
	_box(Vector3(-4.35, -0.05, -4.6), Vector3(16.9, 0.1, 13.8), mats["floor"])
	_box(Vector3(-4.35, H + 0.05, -4.6), Vector3(16.9, 0.1, 13.8), mats["ceil"])
	# الممر A
	_wz(2.0, -1.3, 1.3)
	_wx(-1.2, 2.0, -4.1)
	_wx(-1.2, -5.9, -8.8)
	_lintel_x(-1.2, -4.1, -5.9)
	_wx(1.2, 2.0, -6.0)
	_wx(1.2, -7.4, -11.3)
	_lintel_x(1.2, -6.0, -7.4)
	_wz(-11.2, -12.6, 1.3)
	# الممر B والمدخل الأخير
	_wz(-8.8, -12.6, -1.1)
	_wx(-10.0, -8.7, -9.4)
	_wx(-10.0, -10.6, -11.3)
	_lintel_x(-10.0, -9.4, -10.6)
	_wx(-12.5, -8.7, -11.3)
	# غرفة الجدّ (شرق)
	_wx(3.8, -8.3, -5.1)
	_wz(-8.2, 1.1, 3.9)
	_wz(-5.2, 1.1, 3.9)
	# المجلس (غرب)
	_wx(-6.4, -7.7, -2.3)
	_wz(-7.6, -6.5, -1.1)
	_wz(-2.4, -6.5, -1.1)
	# سجاد الممر
	_box(Vector3(0, 0.011, -4.5), Vector3(1.1, 0.02, 12.9), mats["carpet"], false)
	_box(Vector3(-5.55, 0.011, -10.0), Vector3(8.7, 0.02, 1.1), mats["carpet"], false)
	# كسوة خشبية سفلية
	for seg in [[Vector3(-1.09, 0.45, -1.1), Vector3(0.02, 0.9, 6.2)], [Vector3(1.09, 0.45, -2.0), Vector3(0.02, 0.9, 8.0)]]:
		_box(seg[0], seg[1], mats["wood"], false)
	_box(Vector3(-5.6, 0.45, -10.99), Vector3(8.9, 0.9, 0.02), mats["wood"], false)

	# الباب الأمامي (مغلق)
	var fd := _box(Vector3(0, 1.05, 1.93), Vector3(1.1, 2.1, 0.06), mats["door"], false)
	var fdb := StaticBody3D.new()
	fdb.collision_layer = 1 | 4
	var fcs := CollisionShape3D.new()
	var fbs := BoxShape3D.new()
	fbs.size = Vector3(1.1, 2.1, 0.1)
	fcs.shape = fbs
	fdb.add_child(fcs)
	fd.add_child(fdb)
	fdb.set_meta("prompt", "اضغط E — الباب")
	fdb.set_meta("interact", _on_front_door)

	# باب نهاية الممر
	door_pivot = Node3D.new()
	door_pivot.position = DOOR_HINGE
	add_child(door_pivot)
	_box(Vector3(0, 1.075, -0.6), Vector3(0.08, 2.15, 1.2), mats["door"], false, door_pivot)
	door_body = StaticBody3D.new()
	door_body.collision_layer = 1 | 4
	door_shape = CollisionShape3D.new()
	var dbs := BoxShape3D.new()
	dbs.size = Vector3(0.15, 2.15, 1.2)
	door_shape.shape = dbs
	door_shape.position = Vector3(0, 1.075, -0.6)
	door_body.add_child(door_shape)
	door_pivot.add_child(door_body)
	door_body.set_meta("prompt", "اضغط E — الباب")
	door_body.set_meta("interact", _on_end_door)

	vest_light = OmniLight3D.new()
	vest_light.position = Vector3(-11.3, 1.8, -10.0)
	vest_light.omni_range = 5.0
	vest_light.light_color = Color(1.0, 0.15, 0.1)
	vest_light.light_energy = 0.0
	add_child(vest_light)


func _build_lamps() -> void:
	for p in [Vector3(0, H - 0.04, -1.5), Vector3(0, H - 0.04, -5.2), Vector3(0, H - 0.04, -9.7), Vector3(-5.2, H - 0.04, -10.0)]:
		var m := _mk_mat(Color(1, 0.9, 0.7), 0.5, 0.0, Color(1.0, 0.78, 0.45), 2.5)
		_box(p, Vector3(0.6, 0.06, 0.22), m, false)
		var l := OmniLight3D.new()
		l.position = p + Vector3(0, -0.35, 0)
		l.omni_range = 7.5
		l.omni_attenuation = 1.3
		l.light_energy = 1.1
		l.light_color = _lamp_colors[0]
		add_child(l)
		lamps.append({"light": l, "mat": m, "base": 1.1})
	# مصباح المجلس
	var rl := OmniLight3D.new()
	rl.position = Vector3(-3.8, 2.1, -5.0)
	rl.omni_range = 5.5
	rl.light_energy = 0.55
	rl.light_color = Color(1.0, 0.7, 0.4)
	add_child(rl)
	lamps.append({"light": rl, "mat": null, "base": 0.55})
	# مصباح خافت في غرفة الجدّ
	var gl := OmniLight3D.new()
	gl.position = Vector3(2.5, 2.1, -6.7)
	gl.omni_range = 4.5
	gl.light_energy = 0.22
	gl.light_color = Color(1.0, 0.75, 0.5)
	add_child(gl)
	lamps.append({"light": gl, "mat": null, "base": 0.22})


# ------------------------------------------------------------------ الأثاث والزينة
func _build_props() -> void:
	# طاولة الممر (الصورة)
	_box(Vector3(-0.92, 0.4, -2.5), Vector3(0.4, 0.8, 1.3), mats["wood2"])
	_box(Vector3(-0.92, 0.82, -2.5), Vector3(0.44, 0.04, 1.36), mats["wood"], false)

	# لوحات الممر
	var fdef: Array = [
		[Vector3(1.09, 1.55, -1.0), -PI * 0.5],
		[Vector3(1.09, 1.55, -3.6), -PI * 0.5],
		[Vector3(-1.09, 1.6, -2.5), PI * 0.5],
	]
	for d in fdef:
		frames.append(_make_frame(d[0], d[1]))
	# لوحة خطّ عربي في الممر B
	_make_calligraphy(Vector3(-4.0, 1.6, -11.09), 0.0)
	# بصمات الأيدي
	var hp: Array = [
		[Vector3(1.095, 1.4, -0.2), -PI * 0.5], [Vector3(1.095, 1.2, -4.9), -PI * 0.5],
		[Vector3(-1.095, 1.1, -3.4), PI * 0.5], [Vector3(-1.095, 1.3, -7.0), PI * 0.5],
		[Vector3(-3.0, 1.3, -11.095), 0.0], [Vector3(-8.0, 1.0, -11.095), 0.0],
		[Vector3(1.095, 1.5, -9.0), -PI * 0.5], [Vector3(-9.895, 1.2, -9.0), PI * 0.5],
	]
	for d in hp:
		handprints.append(_make_handprint(d[0], d[1]))

	_build_majlis()
	_build_grandfather_room()

	# مقعد صغير في آخر الممر
	_box(Vector3(-7.0, 0.2, -9.25), Vector3(0.4, 0.4, 0.4), mats["wood2"])
	# مرآة/ظلّ ... خزانة صغيرة في الممر B
	_box(Vector3(-2.6, 0.5, -9.0), Vector3(0.9, 1.0, 0.4), mats["wood"])


func _make_frame(pos: Vector3, yaw: float) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation = Vector3(0, yaw, 0)
	add_child(root)
	_box(Vector3.ZERO, Vector3(0.62, 0.78, 0.04), mats["wood"], false, root)
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.66)
	var qm := StandardMaterial3D.new()
	qm.albedo_texture = load("res://textures/portrait.png")
	qm.roughness = 0.6
	var mi := _add(root, q, Vector3(0, 0, 0.022), qm)
	mi.set_meta("mat", qm)
	root.set_meta("quad", mi)
	return root


func _make_calligraphy(pos: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation = Vector3(0, yaw, 0)
	add_child(root)
	_box(Vector3.ZERO, Vector3(1.3, 0.55, 0.04), mats["wood2"], false, root)
	_box(Vector3(0, 0, 0.022), Vector3(1.2, 0.45, 0.01), mats["white"], false, root)
	var l := Label3D.new()
	l.text = "لا مكانَ كالبيت"
	l.font = FONT_BOLD
	l.font_size = 64
	l.pixel_size = 0.0045
	l.modulate = Color(0.15, 0.1, 0.05)
	l.outline_size = 0
	l.position = Vector3(0, 0, 0.032)
	root.add_child(l)
	frame_labels.append(l)


func _make_handprint(pos: Vector3, yaw: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 0.45)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/handprint.png")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.5
	var mi := _add(self, q, pos, m, Vector3(0, yaw, randf_range(-0.3, 0.3)))
	mi.visible = false
	return mi


func _build_majlis() -> void:
	# سجادة وفرش
	_box(Vector3(-3.8, 0.012, -5.0), Vector3(3.6, 0.024, 3.4), mats["carpet"], false)
	_box(Vector3(-6.0, 0.17, -5.0), Vector3(0.8, 0.34, 3.7), mats["red"], false)
	_box(Vector3(-3.8, 0.17, -7.2), Vector3(3.3, 0.34, 0.8), mats["red"], false)
	_box(Vector3(-6.26, 0.55, -5.0), Vector3(0.2, 0.55, 3.6), mats["navy"], false)
	_box(Vector3(-3.8, 0.55, -7.46), Vector3(3.2, 0.55, 0.2), mats["navy"], false)
	# طاولة قصيرة مستديرة + صينية + فناجين
	var tb := StaticBody3D.new()
	tb.collision_layer = 1
	tb.position = Vector3(-3.6, 0.0, -5.0)
	var tcs := CollisionShape3D.new()
	var tcyl := CylinderShape3D.new()
	tcyl.radius = 0.45
	tcyl.height = 0.4
	tcs.shape = tcyl
	tcs.position.y = 0.2
	tb.add_child(tcs)
	add_child(tb)
	_add(tb, _cyl(0.45, 0.4, 0.4, 16), Vector3(0, 0.2, 0), mats["wood2"])
	_add(tb, _cyl(0.3, 0.3, 0.015, 16), Vector3(0.1, 0.41, 0.1), mats["brass"])
	for k in 3:
		var a := TAU * k / 3.0
		_add(tb, _cyl(0.03, 0.022, 0.04, 8), Vector3(0.1 + cos(a) * 0.14, 0.44, 0.1 + sin(a) * 0.14), mats["white"])
	# رفّ الراديو
	_box(Vector3(-6.05, 0.5, -2.9), Vector3(0.5, 1.0, 0.7), mats["wood"])
	var radio := Node3D.new()
	radio.position = Vector3(-6.05, 1.1, -2.9)
	radio.rotation.y = PI * 0.5
	add_child(radio)
	_box(Vector3.ZERO, Vector3(0.38, 0.22, 0.16), mats["wood2"], false, radio)
	_box(Vector3(-0.08, 0.0, 0.082), Vector3(0.18, 0.15, 0.01), mats["dark"], false, radio)
	var dial := _mk_mat(Color(1, 0.7, 0.3), 0.5, 0.0, Color(1.0, 0.6, 0.2), 1.6)
	_box(Vector3(0.1, 0.03, 0.082), Vector3(0.09, 0.04, 0.01), dial, false, radio)
	_add(radio, _cyl(0.004, 0.004, 0.35, 4), Vector3(0.12, 0.27, 0.0), mats["iron"], Vector3(0, 0, -0.4))
	radio_player = AudioStreamPlayer3D.new()
	radio_player.stream = Sfx.get_stream("oud_radio_loop", true)
	radio_player.volume_db = -4.0
	radio_player.unit_size = 4.0
	radio_player.max_distance = 28.0
	radio_player.position = Vector3(0, 0, 0)
	radio.add_child(radio_player)


func _build_grandfather_room() -> void:
	# السرير
	_box(Vector3(3.2, 0.2, -7.0), Vector3(1.0, 0.4, 2.0), mats["wood"])
	_box(Vector3(3.2, 0.47, -7.0), Vector3(0.95, 0.14, 1.9), mats["white"], false)
	_box(Vector3(3.2, 0.58, -7.7), Vector3(0.7, 0.1, 0.35), mats["white"], false)
	_box(Vector3(3.2, 0.7, -8.05), Vector3(1.05, 1.0, 0.08), mats["wood"], false)
	# طاولة بجانب السرير
	_box(Vector3(3.45, 0.25, -7.85), Vector3(0.4, 0.5, 0.4), mats["wood2"])
	# خزانة
	_box(Vector3(3.5, 1.0, -5.75), Vector3(0.6, 2.0, 1.1), mats["wood"])
	# سجادة صغيرة
	_box(Vector3(2.4, 0.012, -6.7), Vector3(1.6, 0.024, 2.2), mats["carpet"], false)


func _build_writing() -> void:
	# [نص، موضع، دوران، الليلة الدنيا]
	var defs: Array = [
		["لا تلتفت", Vector3(-6.5, 1.5, -11.08), 0.0, 2, 0.0065],
		["هي هنا", Vector3(1.08, 1.55, -4.85), -PI * 0.5, 3, 0.0065],
		["ارجع", Vector3(-3.8, 1.5, -7.48), 0.0, 4, 0.0065],
		["سمعتُكَ", Vector3(-1.08, 1.55, -0.9), PI * 0.5, 5, 0.0065],
	]
	for d in defs:
		var l := Label3D.new()
		l.text = d[0]
		l.font = FONT_BOLD
		l.font_size = 96
		l.pixel_size = d[4]
		l.modulate = Color(0.5, 0.02, 0.02)
		l.outline_size = 0
		l.position = d[1]
		l.rotation.y = d[2]
		l.visible = false
		add_child(l)
		writings.append({"node": l, "min": d[3]})


func _build_player_and_entity() -> void:
	player = PlayerScript.new()
	player.position = START_POS
	add_child(player)
	player.step_sound = "step_wood"
	player.flashlight.visible = false

	entity = EntityScript.new()
	add_child(entity)
	entity.player = player
	entity.nav_pos = [
		Vector3(0, 0, 1.0), Vector3(0, 0, -2.0), Vector3(0, 0, -5.0), Vector3(0, 0, -6.7),
		Vector3(0, 0, -10.0), Vector3(-4.5, 0, -10.0), Vector3(-8.5, 0, -10.0),
		Vector3(-1.2, 0, -5.0), Vector3(-3.8, 0, -5.0), Vector3(1.2, 0, -6.7), Vector3(2.5, 0, -6.7)]
	entity.nav_zone = ["A", "A", "A", "A", "A", "B", "B", "R2", "R2", "R1", "R1"]
	entity.nav_adj = [[1], [0, 2], [1, 3, 7], [2, 4, 9], [3, 5], [4, 6], [5], [2, 8], [7], [3, 10], [9]]
	entity.zone_fn = zone_of
	entity.caught.connect(_on_caught)
	entity.first_seen.connect(_on_entity_seen)


func _build_audio() -> void:
	Sfx.stop_all_loops(0.5)
	Sfx.start_loop("drone_loop", -22.0, 3.0)
	Sfx.start_loop("hum_loop", -30.0, 3.0)
	Sfx.start_loop("wind_loop", -32.0, 3.0)
	hb_player = AudioStreamPlayer.new()
	hb_player.stream = Sfx.get_stream("heartbeat_loop", true)
	hb_player.volume_db = -80.0
	add_child(hb_player)
	hb_player.play()


# ======================================================================
#  الحلقات
# ======================================================================
func zone_of(p: Vector3) -> String:
	if p.x < -10.0:
		return "V"
	if p.x > 1.2:
		return "R1"
	if p.x < -1.2:
		return "B" if p.z < -8.8 else "R2"
	return "A"


func _wait(t: float) -> void:
	await get_tree().create_timer(t, false).timeout


func _begin_loop(n: int, first: bool = false) -> void:
	busy = true
	loop_index = n
	loop_time = 0.0
	item_done = false
	door_locked = true
	_guided = false
	_flicker = 0.0
	lamp_power = 1.0
	_amb_t = randf_range(18.0, 30.0)
	events.clear()
	Game.fear = 0.0
	entity.vanish()
	_reset_door()
	_clear_item()
	_clear_carried_light()
	_apply_loop_look(n)
	_spawn_item(n)
	player.teleport(START_POS, 0.0)
	player.locked = false
	_setup_events(n)
	if not first:
		await Game.fade(0.0, 1.2)
	else:
		await _wait(0.5)
	if not is_inside_tree():
		return
	busy = false
	Game.show_title(loop_titles[n][0], loop_titles[n][1], 2.2)
	await _wait(3.5)
	if not is_inside_tree():
		return
	Game.say(intro_lines[n], 5.5)


func _apply_loop_look(n: int) -> void:
	for l in lamps:
		var base: float = l["base"]
		var scale_e: float = _lamp_base[n] / 1.1
		l["cur_base"] = base * scale_e
		l["light"].light_color = _lamp_colors[n] if l["mat"] != null else Color(1.0, 0.7, 0.4)
	env.ambient_light_energy = _ambient_e[n]
	env.fog_density = 0.035 + 0.006 * n
	# اللوحات
	for f in frames:
		f.rotation.z = PI if n >= 2 else 0.0
		var mi: MeshInstance3D = f.get_meta("quad")
		var qm: StandardMaterial3D = mi.get_meta("mat")
		qm.albedo_texture = load("res://textures/portrait_bad.png" if n >= 3 else "res://textures/portrait.png")
	for l in frame_labels:
		if n >= 4:
			l.text = "لستَ وحدك"
		elif n >= 2:
			l.text = "لا مخرجَ من البيت"
		else:
			l.text = "لا مكانَ كالبيت"
	for i in handprints.size():
		handprints[i].visible = (n >= 4) or (n >= 3 and i < 4)
	for w in writings:
		w["node"].visible = n >= int(w["min"])
	# الراديو
	if n == 0:
		radio_player.stop()
	else:
		radio_player.stream_paused = false
		radio_player.pitch_scale = [1.0, 1.0, 0.95, 0.7, 0.6, 0.5][n]
		if not radio_player.playing:
			radio_player.play()
	Sfx.set_loop_volume("drone_loop", -23.0 + 2.2 * n, 3.0)


func _reset_door() -> void:
	door_pivot.rotation.y = 0.0
	door_shape.disabled = false
	door_body.set_meta("prompt", "اضغط E — الباب")
	door_body.set_meta("interact", _on_end_door)
	vest_light.light_energy = 0.0


func _clear_item() -> void:
	if item_node and is_instance_valid(item_node):
		item_node.queue_free()
	item_node = null
	Game.set_hint("")


func _clear_carried_light() -> void:
	if carried_light and is_instance_valid(carried_light):
		carried_light.queue_free()
	carried_light = null


func _complete_loop() -> void:
	if busy:
		return
	busy = true
	player.locked = true
	entity.vanish()
	Game.fear = 0.0
	Sfx.play("door_slam", -2.0)
	await Game.fade(1.0, 0.3)
	if not is_inside_tree():
		return
	if loop_index >= LOOP_COUNT - 1:
		Game.ending_mode = true
		Sfx.stop_all_loops(1.5)
		Game.goto_scene(Game.FOREST_SCENE)
		return
	await _wait(1.2)
	if not is_inside_tree():
		return
	_begin_loop(loop_index + 1)


func _on_caught() -> void:
	if busy:
		return
	busy = true
	player.locked = true
	Game.fear = 1.0
	var fwd: Vector3 = -player.camera.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	entity.appear(player.global_position + fwd * 0.95, player.global_position)
	player.look_at_point(entity.head_point(), 0.1)
	player.shake(1.2)
	Sfx.play("scare", 2.0)
	await _wait(1.0)
	if not is_inside_tree():
		return
	await Game.fade(1.0, 0.15)
	entity.vanish()
	Game.show_title("أمسكتْ بك", "", 1.5)
	await _wait(3.2)
	if not is_inside_tree():
		return
	Game.fear = 0.0
	_begin_loop(loop_index)


func _on_entity_seen() -> void:
	Game.fear = maxf(Game.fear, 0.5)
	player.shake(0.35)


# ------------------------------------------------------------------ الأغراض
func _spawn_item(n: int) -> void:
	var d: Dictionary = items_def[n]
	item_node = _build_item(d["id"])
	item_node.position = d["pos"]
	add_child(item_node)
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var ss := SphereShape3D.new()
	ss.radius = 0.26
	cs.shape = ss
	body.add_child(cs)
	item_node.add_child(body)
	body.set_meta("prompt", d["hint"])
	body.set_meta("interact", _collect_item)


func _glow(parent: Node, col: Color, energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.position = Vector3(0, 0.25, 0)
	parent.add_child(l)


func _build_item(id: String) -> Node3D:
	var r := Node3D.new()
	match id:
		"photo":
			_box(Vector3(0, 0.0125, 0), Vector3(0.26, 0.025, 0.34), mats["wood"], false, r)
			var q := QuadMesh.new()
			q.size = Vector2(0.22, 0.3)
			var qm := StandardMaterial3D.new()
			qm.albedo_texture = load("res://textures/portrait_bad.png")
			_add(r, q, Vector3(0, 0.027, 0), qm, Vector3(-PI * 0.5, 0, 0))
			_glow(r, Color(1.0, 0.85, 0.6), 0.35, 1.8)
		"beads":
			var bm := _mk_mat(Color(0.35, 0.18, 0.05), 0.35, 0.2, Color(0.5, 0.25, 0.05), 0.3)
			var bead := _sph(0.014, 6)
			for i in 33:
				var a := TAU * i / 33.0
				_add(r, bead, Vector3(cos(a) * 0.085, 0.015, sin(a) * 0.085 - 0.0), bm)
			_add(r, _sph(0.022, 6), Vector3(0.0, 0.02, 0.09), bm)
			_add(r, _cyl(0.004, 0.012, 0.09, 5), Vector3(0.0, 0.015, 0.14), bm, Vector3(PI * 0.5, 0, 0))
			_glow(r, Color(1.0, 0.7, 0.35), 0.4, 1.8)
		"key":
			_add(r, TorusMesh.new(), Vector3(-0.07, 0.015, 0), mats["iron"], Vector3(0, 0, 0))
			var shaft := _add(r, _cyl(0.007, 0.007, 0.16, 6), Vector3(0.02, 0.012, 0), mats["iron"], Vector3(0, 0, PI * 0.5))
			shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for k in 3:
				_box(Vector3(0.075 - k * 0.018, 0.012, 0.016), Vector3(0.01, 0.014, 0.03), mats["iron"], false, r)
			_glow(r, Color(1.0, 0.8, 0.5), 0.45, 2.0)
		"lantern":
			var gm := _mk_mat(Color(1.0, 0.8, 0.4), 0.3, 0.0, Color(1.0, 0.65, 0.25), 2.2)
			_add(r, _cyl(0.07, 0.07, 0.04, 6), Vector3(0, 0.02, 0), mats["brass"])
			_add(r, _cyl(0.075, 0.075, 0.2, 6), Vector3(0, 0.14, 0), gm)
			_add(r, _cyl(0.0, 0.085, 0.09, 6), Vector3(0, 0.285, 0), mats["brass"])
			_add(r, _cyl(0.085, 0.085, 0.015, 6), Vector3(0, 0.245, 0), mats["brass"])
			var tor := TorusMesh.new()
			tor.inner_radius = 0.045
			tor.outer_radius = 0.052
			_add(r, tor, Vector3(0, 0.34, 0), mats["brass"], Vector3(PI * 0.5, 0, 0))
			_glow(r, Color(1.0, 0.68, 0.3), 1.1, 4.0)
		"dallah":
			_add(r, _cyl(0.09, 0.14, 0.12, 12), Vector3(0, 0.06, 0), mats["brass"])
			_add(r, _cyl(0.055, 0.09, 0.12, 12), Vector3(0, 0.18, 0), mats["brass"])
			_add(r, _cyl(0.035, 0.055, 0.1, 12), Vector3(0, 0.29, 0), mats["brass"])
			var lid := _sph(0.04, 8)
			lid.is_hemisphere = true
			_add(r, lid, Vector3(0, 0.34, 0), mats["brass"])
			_add(r, _cyl(0.012, 0.03, 0.2, 8), Vector3(0.14, 0.26, 0), mats["brass"], Vector3(0, 0, -0.9))
			var tor2 := TorusMesh.new()
			tor2.inner_radius = 0.05
			tor2.outer_radius = 0.06
			_add(r, tor2, Vector3(-0.1, 0.2, 0), mats["brass"], Vector3(PI * 0.5, 0, 0))
			_glow(r, Color(1.0, 0.75, 0.4), 0.5, 2.0)
		"bead":
			var m1 := _mk_mat(Color(0.03, 0.08, 0.5), 0.2, 0.0, Color(0.1, 0.25, 1.0), 1.0)
			var m2 := _mk_mat(Color(0.9, 0.9, 0.9), 0.3, 0.0, Color(0.8, 0.8, 0.9), 0.5)
			var m3 := _mk_mat(Color(0.2, 0.6, 1.0), 0.2, 0.0, Color(0.2, 0.6, 1.0), 1.4)
			var m4 := _mk_mat(Color(0.0, 0.0, 0.02), 0.2)
			_add(r, _cyl(0.07, 0.07, 0.014, 20), Vector3(0, 0.007, 0), m1)
			_add(r, _cyl(0.05, 0.05, 0.016, 20), Vector3(0, 0.009, 0), m2)
			_add(r, _cyl(0.033, 0.033, 0.018, 20), Vector3(0, 0.011, 0), m3)
			_add(r, _cyl(0.016, 0.016, 0.02, 14), Vector3(0, 0.013, 0), m4)
			_glow(r, Color(0.3, 0.6, 1.0), 0.8, 2.6)
	return r


func _collect_item() -> void:
	if item_done or busy:
		return
	item_done = true
	var n := loop_index
	var d: Dictionary = items_def[n]
	Sfx.play("pickup", -3.0)
	_clear_item()
	Game.say(d["note"], 5.5)
	if n == 3:
		_give_lantern_light()
	await _wait(2.4)
	if not is_inside_tree() or loop_index != n:
		return
	_unlock_door()
	_on_item_taken(n)


func _give_lantern_light() -> void:
	carried_light = OmniLight3D.new()
	carried_light.light_color = Color(1.0, 0.68, 0.32)
	carried_light.light_energy = 1.3
	carried_light.omni_range = 6.0
	carried_light.position = Vector3(-0.25, -0.35, -0.2)
	player.head.add_child(carried_light)
	lamp_power = 0.18


func _unlock_door() -> void:
	door_locked = false
	door_shape.disabled = true
	if door_body.has_meta("interact"):
		door_body.remove_meta("interact")
	Sfx.play3d("unlock", self, Vector3(-9.9, 1.0, -10.0), 2.0)
	Sfx.play3d("door_creak", self, Vector3(-9.9, 1.0, -10.0), 0.0, 1.0, 5.0, 30.0)
	var tw := create_tween()
	tw.tween_property(door_pivot, "rotation:y", deg_to_rad(96.0), 2.2).set_trans(Tween.TRANS_SINE)
	vest_light.light_energy = 0.9
	Game.say("انفتح الباب في آخر الممر...", 4.0)


func _on_front_door() -> void:
	Sfx.play3d("knock", self, Vector3(0, 1.2, 2.0), -14.0)
	Game.say("مُقفل من الخارج... ولا مفتاح معي.", 3.5)


func _on_end_door() -> void:
	if door_locked:
		Sfx.play("click", -6.0)
		Game.say("مقفل. لا بدّ أن أجد «%s» أولًا." % items_def[loop_index]["name"], 4.0)


# ======================================================================
#  أحداث الرعب
# ======================================================================
func _ev(cond: Callable, act: Callable) -> void:
	events.append({"cond": cond, "act": act, "done": false})


func _after(t: float) -> Callable:
	return func() -> bool: return loop_time > t and not busy


func _in_zone(z: String) -> Callable:
	return func() -> bool: return player_zone == z and loop_time > 4.0 and not busy


func _setup_events(n: int) -> void:
	_ev(_after(38.0), _hint_item)
	match n:
		0:
			_ev(_after(14.0), _l0_knock)
			_ev(_after(34.0), _flicker_now)
			_ev(_in_zone("B"), _l0_enter_b)
		1:
			_ev(_after(12.0), _l1_whisper)
			_ev(_in_zone("R2"), _l1_enter_r2)
		2:
			_ev(_after(7.0), _l2_walls)
			_ev(_in_zone("B"), _l2_enter_b)
		3:
			_ev(_after(10.0), _l3_wail)
			_ev(_in_zone("B"), _l3_enter_b)
		4:
			_ev(_after(8.0), _hunt_l4)
		5:
			_ev(_after(5.0), _hunt_l5)


func _run_events() -> void:
	for e in events:
		if not e["done"] and e["cond"].call():
			e["done"] = true
			e["act"].call()


func _flicker_now() -> void:
	_flicker = randf_range(1.0, 2.0)
	Sfx.play("buzz", -8.0)


func _hint_item() -> void:
	if item_done:
		return
	var d: Dictionary = items_def[loop_index]
	Game.say("ابحث عن «%s» — %s." % [d["name"], d["where"]], 5.0)


func _l0_knock() -> void:
	Sfx.play3d("knock", self, Vector3(0, 1.3, 1.8), 3.0)
	Game.say("طَرقٌ على الباب... من الخارج؟", 4.0)


func _l0_enter_b() -> void:
	Sfx.play3d("door_creak", self, Vector3(1.2, 1.2, -6.7), -2.0)
	Game.say("كأن بابًا فُتح خلفي...", 3.5)


func _l1_whisper() -> void:
	Sfx.play3d("whisper", self, Vector3(-3.8, 1.5, -5.0), -2.0)
	_flicker_now()


func _l1_enter_r2() -> void:
	radio_player.stream_paused = true
	Sfx.play("static", -4.0)
	await _wait(2.2)
	if not is_inside_tree() or busy:
		return
	Sfx.play3d("whisper", self, player.global_position + Vector3(0.6, 1.5, 0.4), -2.0)
	await _wait(1.0)
	if not is_inside_tree() or busy:
		return
	entity.peek(Vector3(-1.4, 0, -5.0), 3.5)
	await _wait(3.5)
	if is_inside_tree():
		radio_player.stream_paused = false


func _l2_walls() -> void:
	Sfx.play3d("knock", self, Vector3(2.4, 1.3, -6.7), 4.0)
	Game.say("الطَّرق... يأتي من داخل الجدران.", 4.0)
	await _wait(5.0)
	if is_inside_tree() and not busy:
		Sfx.play3d("knock", self, Vector3(-3.0, 1.3, -11.0), 4.0)


func _l2_enter_b() -> void:
	Sfx.play3d("door_slam", self, Vector3(0, 1.0, 1.9), 0.0)
	_flicker_now()


func _l3_wail() -> void:
	Sfx.play3d("wail", self, Vector3(-11.5, 1.5, -10.0), 0.0, 1.0, 8.0, 50.0)
	_flicker = 2.2


func _l3_enter_b() -> void:
	await _wait(1.5)
	if not is_inside_tree() or busy:
		return
	entity.peek(Vector3(0, 0, -10.0), 4.5)


func _hunt_l4() -> void:
	Game.say("هناك من يمشي في البيت...", 3.5)
	entity.start_hunt(1.35, entity.farthest_node_from(player.global_position))


func _hunt_l5() -> void:
	Game.say("إنها قادمة. لا تُدِر ظهرك.", 3.5)
	entity.start_hunt(1.8, entity.farthest_node_from(player.global_position))


func _on_item_taken(n: int) -> void:
	match n:
		1:
			_flicker_now()
		2:
			_blackout()
		3:
			Game.say("الفانوس يضيء... لكن أنوار الممر تموت.", 4.0)


func _blackout() -> void:
	lamp_power = 0.0
	env.ambient_light_energy = 0.06
	player.flashlight.visible = true
	Game.say("انقطع النور! الكشاف... (F)", 3.0)
	Sfx.play3d("whisper", self, player.global_position + Vector3(0.3, 1.5, 0.5), 2.0)
	await _wait(4.0)
	if not is_inside_tree() or busy:
		return
	lamp_power = 1.0
	env.ambient_light_energy = _ambient_e[loop_index]
	_flicker = 1.0
	entity.peek(Vector3(1.4, 0, -6.7), 3.5)


func _ambient_event() -> void:
	if loop_index < 1 or busy:
		return
	var fwd: Vector3 = -player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var behind := player.global_position - fwd * 2.0 + Vector3(0, 1.4, 0)
	match randi() % 4:
		0:
			Sfx.play3d("whisper", self, behind, -5.0)
		1:
			_flicker_now()
		2:
			Sfx.play3d("knock", self, player.global_position + Vector3(randf_range(-2, 2), 1.2, randf_range(-3, 3)), -2.0)
		3:
			Sfx.play3d("door_creak", self, behind, -6.0)


# ======================================================================
#  كل إطار
# ======================================================================
func _process(delta: float) -> void:
	if player == null:
		return
	player_zone = zone_of(player.global_position)
	if player.global_position.y < -3.0:
		player.teleport(START_POS, 0.0)
	if not busy:
		loop_time += delta
		_run_events()
		_amb_t -= delta
		if _amb_t <= 0.0:
			_amb_t = randf_range(16.0, 32.0) / (1.0 + 0.2 * loop_index)
			_ambient_event()
		if not door_locked and player.global_position.x < -11.0:
			_complete_loop()
	_update_lamps(delta)
	var fear_db := lerpf(-60.0, -3.0, clampf(Game.fear * 1.3, 0.0, 1.0))
	hb_player.volume_db = lerpf(hb_player.volume_db, fear_db, clampf(delta * 4.0, 0.0, 1.0))
	if carried_light and is_instance_valid(carried_light):
		carried_light.light_energy = 1.3 + randf_range(-0.15, 0.15)


func _update_lamps(delta: float) -> void:
	if _flicker > 0.0:
		_flicker -= delta
	var fl := Game.fear > 0.4 and randf() < Game.fear * 0.04
	for l in lamps:
		var cb: float = l.get("cur_base", l["base"])
		var f := 1.0
		if _flicker > 0.0 or fl:
			f = randf_range(0.0, 1.2) if randf() < 0.6 else 0.0
		var e := cb * lamp_power * f
		l["light"].light_energy = e
		if l["mat"] != null:
			l["mat"].emission_energy_multiplier = 2.5 * (e / maxf(cb, 0.01)) * (1.0 if lamp_power > 0.0 else 0.0)
