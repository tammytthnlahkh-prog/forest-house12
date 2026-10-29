extends Node3D
## الغابة وبيت الجدّ من الخارج. في الأول: ليلة الوصول. في النهاية: فجر النجاة.

const PlayerScript := preload("res://scripts/player.gd")
const FONT_BOLD := preload("res://fonts/DejaVuSans-Bold.ttf")

const LETTER := "إلى حفيدي العزيز،

إن وصلتك هذه الورقة فقد رحلتُ وبقي البيت.
لا تدخله بعد الغروب. السعلاة تسكن الغابة منذ زمنٍ بعيد، وقد وجدت لها بابًا في بيتنا.

إن أُغلق الباب خلفك فلا تحاول الهرب. اجمع ما تركتُه لك: الصورة، والمسبحة، والمفتاح، والفانوس، والدلّة، وأخيرًا الخرزة الزرقاء.

وتذكّر: هي تتجمّد حين تلتقي عيناها بعينيك، وتتقدّم كلما أدرتَ وجهك عنها.
لا تُطِل النظر في وجهها... ولا تُدِر لها ظهرك.

جدّك"

var player: Node3D
var env: Environment
var mats: Dictionary = {}
var dawn: bool = false
var _event_t: float = 15.0
var _eyes: Node3D
var _can_exit: bool = false
var _door_body: StaticBody3D
var _read_letter: bool = false
var _door_light: OmniLight3D


func _ready() -> void:
	dawn = Game.ending_mode
	_init_materials()
	_make_environment()
	_build_ground()
	_build_trees()
	_build_house()
	_build_props()
	_build_player()
	_build_audio()
	Game.enter_game_mode()
	if dawn:
		_ending_sequence()
	else:
		_intro_sequence()


# ------------------------------------------------------------------ مواد وبيئة
func _tex_mat(tex: String, tiling: float, tint: Color = Color.WHITE, rough: float = 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/%s.png" % tex)
	m.albedo_color = tint
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(tiling, tiling, tiling)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _flat(color: Color, rough: float = 0.8, emit: Color = Color.BLACK, emit_e: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if emit_e > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = emit_e
	return m


func _init_materials() -> void:
	var lit := 1.6 if dawn else 1.0
	mats["ground"] = _tex_mat("ground", 0.25, Color(lit, lit, lit))
	mats["path"] = _tex_mat("ground", 0.3, Color(2.2, 1.9, 1.5) * lit)
	mats["plaster"] = _tex_mat("plaster", 0.3, Color(1.0, 0.95, 0.88))
	mats["door"] = _flat(Color.WHITE)
	mats["door"].albedo_texture = load("res://textures/door.png")
	mats["wood"] = _flat(Color(0.15, 0.09, 0.05), 0.8)
	mats["dark"] = _flat(Color(0.01, 0.01, 0.015), 1.0)
	mats["stone"] = _tex_mat("plaster", 0.6, Color(0.7, 0.7, 0.72))
	var b := StandardMaterial3D.new()
	b.albedo_texture = load("res://textures/bark.png")
	b.albedo_color = Color(0.8, 0.8, 0.8)
	b.roughness = 1.0
	mats["bark"] = b
	var f := StandardMaterial3D.new()
	f.albedo_texture = load("res://textures/foliage.png")
	f.albedo_color = Color(0.7, 0.9, 0.75) * (1.5 if dawn else 1.0)
	f.roughness = 1.0
	mats["foliage"] = f


func _make_environment() -> void:
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	if dawn:
		sm.sky_top_color = Color(0.22, 0.34, 0.55)
		sm.sky_horizon_color = Color(0.95, 0.62, 0.42)
		sm.ground_horizon_color = Color(0.7, 0.5, 0.4)
		sm.ground_bottom_color = Color(0.25, 0.2, 0.18)
	else:
		sm.sky_top_color = Color(0.004, 0.01, 0.03)
		sm.sky_horizon_color = Color(0.03, 0.05, 0.09)
		sm.ground_horizon_color = Color(0.02, 0.03, 0.05)
		sm.ground_bottom_color = Color(0.0, 0.0, 0.01)
	sm.sun_angle_max = 0.0
	sm.sun_curve = 0.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.5, 0.45) if dawn else Color(0.10, 0.14, 0.24)
	env.ambient_light_energy = 0.9 if dawn else 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.58, 0.5) if dawn else Color(0.035, 0.055, 0.09)
	env.fog_density = 0.016 if dawn else 0.04
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	if dawn:
		sun.light_color = Color(1.0, 0.72, 0.5)
		sun.light_energy = 1.1
		sun.rotation = Vector3(-0.3, PI + 0.4, 0)
	else:
		sun.light_color = Color(0.55, 0.65, 1.0)
		sun.light_energy = 0.32
		sun.rotation = Vector3(-0.6, PI, 0)
	add_child(sun)

	if not dawn:
		var moon := MeshInstance3D.new()
		var ms := SphereMesh.new()
		ms.radius = 5.0
		ms.height = 10.0
		moon.mesh = ms
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.albedo_color = Color(0.92, 0.94, 0.85)
		mm.disable_fog = true
		moon.material_override = mm
		moon.position = Vector3(18, 62, -125)
		moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(moon)
		# نجوم
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		var star_mesh := SphereMesh.new()
		star_mesh.radius = 0.35
		star_mesh.height = 0.7
		star_mesh.radial_segments = 4
		star_mesh.rings = 2
		var sm2 := StandardMaterial3D.new()
		sm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm2.albedo_color = Color(0.9, 0.9, 1.0)
		sm2.disable_fog = true
		var mmesh := MultiMesh.new()
		mmesh.transform_format = MultiMesh.TRANSFORM_3D
		mmesh.mesh = star_mesh
		mmesh.instance_count = 180
		for i in 180:
			var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.15, 1.0), rng.randf_range(-1, 1)).normalized()
			mmesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * rng.randf_range(0.5, 1.4)), dir * 210.0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mmesh
		mmi.material_override = sm2
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


# ------------------------------------------------------------------ أرض وأشجار
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


func _build_ground() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(200, 1.0, 200), mats["ground"])
	_box(Vector3(0, 0.012, 24.0), Vector3(2.8, 0.024, 40.0), mats["path"], false)
	# جدران غير مرئية
	for w in [[Vector3(0, 5, 40), Vector3(90, 10, 1)], [Vector3(0, 5, -40), Vector3(90, 10, 1)],
			[Vector3(40, 5, 0), Vector3(1, 10, 90)], [Vector3(-40, 5, 0), Vector3(1, 10, 90)]]:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		sb.position = w[0]
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = w[1]
		cs.shape = bs
		sb.add_child(cs)
		add_child(sb)


func _multi(mesh: Mesh, mat: Material, xfs: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var placed: Array = []
	var tries := 0
	while placed.size() < 270 and tries < 8000:
		tries += 1
		var p := Vector2(rng.randf_range(-38, 38), rng.randf_range(-38, 38))
		if p.x > -11.5 and p.x < 11.5 and p.y > -8.5 and p.y < 13.0:
			continue
		if absf(p.x) < 3.0 and p.y >= 13.0:
			continue
		var ok := true
		for q in placed:
			if q.distance_squared_to(p) < 9.0:
				ok = false
				break
		if ok:
			placed.append(p)

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.13
	trunk_mesh.bottom_radius = 0.22
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 7
	trunk_mesh.rings = 1
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = 1.0
	cone_mesh.height = 1.0
	cone_mesh.radial_segments = 8
	cone_mesh.rings = 1

	var trunks: Array = []
	var cones: Array = []
	var bodies := Node3D.new()
	add_child(bodies)
	for p in placed:
		var h := rng.randf_range(6.0, 11.5)
		var s := rng.randf_range(0.8, 1.35)
		var rot := rng.randf() * TAU
		trunks.append(Transform3D(Basis(Vector3.UP, rot) * Basis.from_scale(Vector3(s, h, s)), Vector3(p.x, h * 0.5, p.y)))
		var juniper := rng.randf() < 0.4
		var layers := 4 if not juniper else 3
		for i in layers:
			var ch := h * (0.34 if not juniper else 0.5)
			var base := h * (0.22 + 0.19 * i) if not juniper else h * (0.14 + 0.24 * i)
			var rad := (2.1 - 0.42 * i) * s * (1.0 if not juniper else 0.62)
			cones.append(Transform3D(Basis(Vector3.UP, rot + i) * Basis.from_scale(Vector3(rad, ch, rad)), Vector3(p.x, base + ch * 0.5, p.y)))
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		sb.position = Vector3(p.x, 1.5, p.y)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.28 * s
		cyl.height = 3.0
		cs.shape = cyl
		sb.add_child(cs)
		bodies.add_child(sb)
	_multi(trunk_mesh, mats["bark"], trunks)
	_multi(cone_mesh, mats["foliage"], cones)


# ------------------------------------------------------------------ البيت
func _quad(parent: Node, size: Vector2, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _build_house() -> void:
	_box(Vector3(0, 2.1, 0), Vector3(13.0, 4.2, 9.0), mats["plaster"])
	# سور السطح
	_box(Vector3(0, 4.45, 4.35), Vector3(13.0, 0.5, 0.3), mats["plaster"], false)
	_box(Vector3(0, 4.45, -4.35), Vector3(13.0, 0.5, 0.3), mats["plaster"], false)
	_box(Vector3(6.35, 4.45, 0), Vector3(0.3, 0.5, 9.0), mats["plaster"], false)
	_box(Vector3(-6.35, 4.45, 0), Vector3(0.3, 0.5, 9.0), mats["plaster"], false)
	# قبّة صغيرة
	var dome := SphereMesh.new()
	dome.radius = 1.5
	dome.height = 3.0
	dome.is_hemisphere = true
	var dm := MeshInstance3D.new()
	dm.mesh = dome
	dm.material_override = mats["plaster"]
	dm.position = Vector3(-3.6, 4.2, -1.5)
	add_child(dm)
	_box(Vector3(-3.6, 4.0, -1.5), Vector3(3.2, 0.4, 3.2), mats["plaster"], false)
	# درجة المدخل
	_box(Vector3(0, 0.1, 5.2), Vector3(2.8, 0.2, 1.5), mats["stone"])
	# الباب
	var door := _box(Vector3(0, 1.1, 4.53), Vector3(1.3, 2.2, 0.1), mats["door"], false)
	_door_body = StaticBody3D.new()
	_door_body.collision_layer = 1 | 4
	var dcs := CollisionShape3D.new()
	var dbs := BoxShape3D.new()
	dbs.size = Vector3(1.3, 2.2, 0.2)
	dcs.shape = dbs
	_door_body.add_child(dcs)
	door.add_child(_door_body)
	_door_body.set_meta("prompt", "اضغط E — ادخل البيت" if not dawn else "اضغط E")
	_door_body.set_meta("interact", _on_door)
	# إطار الباب
	_box(Vector3(-0.72, 1.15, 4.54), Vector3(0.14, 2.3, 0.16), mats["wood"], false)
	_box(Vector3(0.72, 1.15, 4.54), Vector3(0.14, 2.3, 0.16), mats["wood"], false)
	_box(Vector3(0, 2.32, 4.54), Vector3(1.58, 0.14, 0.16), mats["wood"], false)
	# النوافذ
	var warm := _flat(Color(1, 0.8, 0.5), 0.5, Color(1.0, 0.65, 0.25), 2.0 if not dawn else 0.2)
	_quad(self, Vector2(1.0, 1.3), Vector3(-3.6, 2.3, 4.52), warm)
	_quad(self, Vector2(1.0, 1.3), Vector3(3.6, 2.3, 4.52), mats["dark"])
	_box(Vector3(-3.6, 2.3, 4.5), Vector3(1.25, 1.55, 0.1), mats["wood"], false)
	_box(Vector3(3.6, 2.3, 4.5), Vector3(1.25, 1.55, 0.1), mats["wood"], false)
	_box(Vector3(-3.6, 2.3, 4.58), Vector3(0.05, 1.3, 0.04), mats["wood"], false)
	_box(Vector3(-3.6, 2.3, 4.58), Vector3(1.0, 0.05, 0.04), mats["wood"], false)
	if not dawn:
		var wl := OmniLight3D.new()
		wl.position = Vector3(-3.6, 2.3, 6.0)
		wl.omni_range = 9.0
		wl.light_energy = 1.0
		wl.light_color = Color(1.0, 0.7, 0.35)
		add_child(wl)
	# فانوس الباب
	var lamp := _flat(Color(1, 0.85, 0.5), 0.4, Color(1.0, 0.65, 0.25), 2.5)
	_box(Vector3(1.4, 2.5, 4.7), Vector3(0.18, 0.3, 0.18), lamp, false)
	_door_light = OmniLight3D.new()
	_door_light.position = Vector3(1.4, 2.3, 5.2)
	_door_light.omni_range = 8.0
	_door_light.light_energy = 0.9 if not dawn else 0.0
	_door_light.light_color = Color(1.0, 0.7, 0.35)
	add_child(_door_light)

	# عينان في النافذة المظلمة (للنهاية)
	_eyes = Node3D.new()
	_eyes.position = Vector3(3.6, 2.4, 4.45)
	_eyes.visible = false
	add_child(_eyes)
	var em := _flat(Color(0.9, 1, 0.9), 0.3, Color(0.8, 1.0, 0.85), 3.5)
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var es := SphereMesh.new()
	es.radius = 0.035
	es.height = 0.07
	es.radial_segments = 8
	es.rings = 4
	for sx in [-0.14, 0.14]:
		var e := MeshInstance3D.new()
		e.mesh = es
		e.material_override = em
		e.position = Vector3(sx, 0, 0)
		e.scale = Vector3(1, 1.4, 0.6)
		_eyes.add_child(e)


func _build_props() -> void:
	# صندوق خشبي عليه الورقة
	var crate := _box(Vector3(-1.9, 0.3, 6.3), Vector3(0.7, 0.6, 0.7), mats["wood"])
	var paper := _flat(Color(0.85, 0.8, 0.65), 1.0)
	_quad(crate, Vector2(0.4, 0.3), Vector3(0, 0.305, 0), paper, Vector3(-PI * 0.5, 0, 0.3))
	var pb := StaticBody3D.new()
	pb.collision_layer = 4
	var pcs := CollisionShape3D.new()
	var psp := SphereShape3D.new()
	psp.radius = 0.45
	pcs.shape = psp
	pcs.position = Vector3(0, 0.4, 0)
	pb.add_child(pcs)
	crate.add_child(pb)
	pb.set_meta("prompt", "اضغط E — قراءة الورقة")
	pb.set_meta("interact", _on_letter)
	# البئر
	var well := Node3D.new()
	well.position = Vector3(7.5, 0, 9.0)
	add_child(well)
	var wm := MeshInstance3D.new()
	var wc := CylinderMesh.new()
	wc.top_radius = 0.95
	wc.bottom_radius = 1.0
	wc.height = 0.9
	wc.radial_segments = 16
	wm.mesh = wc
	wm.material_override = mats["stone"]
	wm.position = Vector3(0, 0.45, 0)
	well.add_child(wm)
	var hole := MeshInstance3D.new()
	var hc := CylinderMesh.new()
	hc.top_radius = 0.68
	hc.bottom_radius = 0.68
	hc.height = 0.02
	hc.radial_segments = 16
	hole.mesh = hc
	hole.material_override = mats["dark"]
	hole.position = Vector3(0, 0.905, 0)
	well.add_child(hole)
	var wb := StaticBody3D.new()
	wb.collision_layer = 1 | 4
	var wcs := CollisionShape3D.new()
	var wcyl := CylinderShape3D.new()
	wcyl.radius = 1.0
	wcyl.height = 0.9
	wcs.shape = wcyl
	wcs.position = Vector3(0, 0.45, 0)
	wb.add_child(wcs)
	well.add_child(wb)
	wb.set_meta("prompt", "اضغط E — انظر في البئر")
	wb.set_meta("interact", _on_well)


# ------------------------------------------------------------------ لاعب وصوت
func _build_player() -> void:
	player = PlayerScript.new()
	add_child(player)
	player.step_sound = "step_leaf"
	if dawn:
		player.teleport(Vector3(0, 0.25, 6.4), PI)
		player.flashlight.visible = false
	else:
		player.teleport(Vector3(0, 0.05, 34.0), 0.0)
		player.flashlight.visible = true


func _build_audio() -> void:
	Sfx.stop_all_loops(0.8)
	if dawn:
		Sfx.start_loop("wind_loop", -26.0, 3.0)
		Sfx.start_loop("birds_loop", -14.0, 4.0)
	else:
		Sfx.start_loop("wind_loop", -17.0, 4.0)
		Sfx.start_loop("crickets_loop", -22.0, 4.0)
		Sfx.start_loop("drone_loop", -30.0, 6.0)


func _process(delta: float) -> void:
	if dawn:
		return
	_event_t -= delta
	if _event_t <= 0.0:
		_event_t = randf_range(18.0, 38.0)
		var a := randf() * TAU
		var pos := player.global_position + Vector3(cos(a), 0.5, sin(a)) * randf_range(25.0, 40.0)
		if randf() < 0.5:
			Sfx.play3d("owl", self, pos, 2.0, randf_range(0.9, 1.1), 8.0, 80.0)
		else:
			Sfx.play3d("howl", self, pos, 3.0, randf_range(0.8, 1.0), 10.0, 100.0)


# ------------------------------------------------------------------ تفاعلات
func _on_door() -> void:
	if dawn:
		Game.say("لن أدخل هذا البيت مرّة أخرى.", 3.5)
		return
	_door_body.remove_meta("interact")
	Sfx.play("door_creak", -3.0)
	Game.set_hint("")
	Game.goto_scene(Game.HOUSE_SCENE)


func _on_letter() -> void:
	_read_letter = true
	Game.show_note(LETTER)


func _on_well() -> void:
	if dawn:
		Game.say("الماء ساكن... ووجهي وحده ينعكس فيه.", 4.0)
	else:
		Game.say("في قاع البئر وجهٌ ينظر إليّ... وجهٌ ليس وجهي.", 4.5)
		Sfx.play("whisper", -10.0)


# ------------------------------------------------------------------ مشاهد
func _intro_sequence() -> void:
	await get_tree().create_timer(1.5, false).timeout
	Game.show_title("بيت الغابة", "ليلة الوصول", 3.0)
	await get_tree().create_timer(5.0, false).timeout
	Game.say("ورثتُ بيت جدّي في أطراف الغابة... وها أنا أراه أخيرًا.", 5.0)
	await get_tree().create_timer(8.0, false).timeout
	Game.say("نافذة واحدة مضاءة. من أشعلها وجدّي رحل منذ سنوات؟", 5.0)
	await get_tree().create_timer(30.0, false).timeout
	if not _read_letter:
		Game.say("هناك ورقة على الصندوق قرب الباب.", 4.0)


func _ending_sequence() -> void:
	player.locked = true
	await get_tree().create_timer(2.0, false).timeout
	player.locked = false
	Game.show_title("أشرقت الشمس", "", 3.0)
	await get_tree().create_timer(5.0, false).timeout
	Game.say("نجوتُ... هذه المرّة.", 5.0)
	await get_tree().create_timer(14.0, false).timeout
	_eyes.visible = true
	Sfx.play("sting", -6.0)
	Game.say("... ", 1.5)
	await get_tree().create_timer(9.0, false).timeout
	Game.show_title("تمّت", "بيت الغابة — شكرًا للعب", 6.0)
	await get_tree().create_timer(9.0, false).timeout
	Game.say("اضغط أي زر للعودة إلى القائمة", 600.0)
	_can_exit = true


func _unhandled_input(event: InputEvent) -> void:
	if _can_exit and event.is_pressed() and (event is InputEventKey or event is InputEventScreenTouch or event is InputEventMouseButton):
		_can_exit = false
		Game.ending_mode = false
		Sfx.stop_all_loops(1.0)
		Game.enter_menu_mode()
		Game.goto_scene(Game.MENU_SCENE)
