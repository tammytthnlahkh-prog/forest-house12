extends Node3D
## «السعلاة» — كيان الغابة. يظهر لمحًا، أو يطارد اللاعب:
## يتجمّد تمامًا ما دمتَ تنظر إليه، ويتقدّم كلما أدرت وجهك عنه.

signal caught
signal first_seen

enum Mode { HIDDEN, PEEK, HUNT, STILL }

var mode: int = Mode.HIDDEN
var player: Node3D = null

# شبكة التنقّل (يملؤها البيت)
var nav_pos: Array = []     # Array[Vector3]
var nav_adj: Array = []     # Array[Array[int]]
var nav_zone: Array = []    # Array[String]
var zone_fn: Callable       # (Vector3) -> String

var speed: float = 1.6
var kill_dist: float = 1.2

var _body: Node3D
var _head: Node3D
var _arms: Array = []
var _mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
var _breath: AudioStreamPlayer3D
var _t: float = 0.0
var _twitch_t: float = 0.5
var _head_goal: Vector3 = Vector3.ZERO
var _peek_left: float = 0.0
var _look_time: float = 0.0
var _seen: bool = false
var _unseen_for: float = 99.0
var _from: int = 0
var _wail_t: float = 8.0


func _ready() -> void:
	_build()
	visible = false
	set_physics_process(true)


# ------------------------------------------------------------------ مظهر الكيان
func _cyl(top: float, bottom: float, h: float, seg: int = 8) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m


func _mesh(parent: Node, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _build() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.02, 0.018, 0.022)
	_mat.roughness = 1.0
	_mat.emission_enabled = true
	_mat.emission = Color(0.04, 0.04, 0.055)

	_body = Node3D.new()
	add_child(_body)

	# الثوب الممزّق الطويل
	_mesh(_body, _cyl(0.14, 0.52, 1.7, 14), Vector3(0, 0.98, 0), _mat)
	# الجذع
	var caps := CapsuleMesh.new()
	caps.radius = 0.15
	caps.height = 1.05
	caps.radial_segments = 10
	caps.rings = 4
	_mesh(_body, caps, Vector3(0, 1.8, 0), _mat)

	# الرأس
	_head = Node3D.new()
	_head.position = Vector3(0, 2.4, 0)
	_body.add_child(_head)
	var sph := SphereMesh.new()
	sph.radius = 0.15
	sph.height = 0.3
	sph.radial_segments = 12
	sph.rings = 6
	var skull := _mesh(_head, sph, Vector3.ZERO, _mat)
	skull.scale = Vector3(0.85, 1.3, 0.95)

	# العينان المتوهجتان
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = Color(0.9, 1.0, 0.9)
	_eye_mat.emission_enabled = true
	_eye_mat.emission = Color(0.8, 1.0, 0.85)
	_eye_mat.emission_energy_multiplier = 3.5
	_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var eye := SphereMesh.new()
	eye.radius = 0.022
	eye.height = 0.044
	eye.radial_segments = 8
	eye.rings = 4
	for s in [-1.0, 1.0]:
		var e := _mesh(_head, eye, Vector3(s * 0.055, 0.03, -0.125), _eye_mat)
		e.scale = Vector3(1.0, 1.4, 0.6)

	# الشعر الطويل
	var hair_meshes: Array = []
	for L in [1.1, 1.4, 1.7, 2.0]:
		hair_meshes.append(_cyl(0.011, 0.002, L, 4))
	for i in 44:
		var a := TAU * float(i) / 44.0 + randf() * 0.12
		var rad := randf_range(0.07, 0.15)
		var pivot := Node3D.new()
		pivot.position = Vector3(cos(a) * rad, 0.12, sin(a) * rad)
		var tilt := randf_range(0.03, 0.2)
		pivot.rotation = Vector3(-sin(a) * tilt, 0.0, cos(a) * tilt)
		_head.add_child(pivot)
		var idx := randi() % hair_meshes.size()
		var L: float = hair_meshes[idx].height
		_mesh(pivot, hair_meshes[idx], Vector3(0, -L * 0.5, 0), _mat)

	# الذراعان الطويلتان والمخالب
	var claw := _cyl(0.0, 0.012, 0.32, 4)
	for s in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(s * 0.2, 2.2, 0)
		sh.rotation = Vector3(0.12, 0.0, s * 0.1)
		_body.add_child(sh)
		_mesh(sh, _cyl(0.035, 0.025, 1.7, 6), Vector3(0, -0.85, 0), _mat)
		for k in 4:
			var c := _mesh(sh, claw, Vector3((k - 1.5) * 0.02, -1.82, 0), _mat)
			c.rotation.z = (k - 1.5) * 0.12
			c.rotation.x = 0.1
		_arms.append(sh)

	# صوت النَّفَس
	_breath = AudioStreamPlayer3D.new()
	_breath.stream = Sfx.get_stream("breath_loop", true)
	_breath.volume_db = -3.0
	_breath.unit_size = 3.0
	_breath.max_distance = 22.0
	add_child(_breath)


# ------------------------------------------------------------------ تحكم
func face(p: Vector3) -> void:
	var d := p - global_position
	d.y = 0.0
	if d.length() > 0.01:
		rotation.y = atan2(-d.x, -d.z)


func appear(pos: Vector3, look_pos: Vector3 = Vector3.INF) -> void:
	global_position = Vector3(pos.x, 0.0, pos.z)
	if look_pos != Vector3.INF:
		face(look_pos)
	visible = true
	_seen = false
	_look_time = 0.0
	if _breath and not _breath.playing:
		_breath.play()


func vanish() -> void:
	mode = Mode.HIDDEN
	visible = false
	if _breath:
		_breath.stop()


## ظهور خاطف: يختفي حين تنظر إليه أو بعد انتهاء المدة
func peek(pos: Vector3, duration: float = 3.0) -> void:
	mode = Mode.PEEK
	_peek_left = duration
	appear(pos, player.global_position if player else Vector3.INF)


func start_hunt(spd: float, spawn: Vector3) -> void:
	speed = spd
	mode = Mode.HUNT
	appear(spawn, player.global_position)
	_from = _nearest_node(global_position, "")
	_wail_t = randf_range(5.0, 9.0)


func stop_hunt() -> void:
	vanish()


func farthest_node_from(pos: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var bd := -1.0
	for p in nav_pos:
		var d: float = Vector2(p.x - pos.x, p.z - pos.z).length()
		if d > bd:
			bd = d
			best = p
	return best


## موضع رأس الكيان (للمشاهد السينمائية)
func head_point() -> Vector3:
	return _head.global_position


# ------------------------------------------------------------------ رؤية
func player_sees_me() -> bool:
	if player == null:
		return false
	var cam: Camera3D = player.camera
	var space := get_world_3d().direct_space_state
	for h in [1.5, 0.8]:
		var target := global_position + Vector3(0, h, 0)
		if not cam.is_position_in_frustum(target):
			continue
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, target, 1)
		if space.intersect_ray(q).is_empty():
			return true
	return false


# ------------------------------------------------------------------ تنقّل
func _nearest_node(pos: Vector3, zone: String) -> int:
	var best := -1
	var bd := 1e9
	for i in nav_pos.size():
		if zone != "" and nav_zone[i] != zone:
			continue
		var d := Vector2(nav_pos[i].x - pos.x, nav_pos[i].z - pos.z).length()
		if d < bd:
			bd = d
			best = i
	if best == -1:
		return _nearest_node(pos, "") if zone != "" else 0
	return best


func _next_hop(start: int, goal: int) -> int:
	if start == goal:
		return goal
	var prev := {}
	prev[start] = -1
	var queue: Array = [start]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		if cur == goal:
			break
		for nb in nav_adj[cur]:
			if not prev.has(nb):
				prev[nb] = cur
				queue.append(nb)
	if not prev.has(goal):
		return start
	var n := goal
	while prev[n] != start and prev[n] != -1:
		n = prev[n]
	return n


func _advance(step: float) -> void:
	var zone: String = zone_fn.call(player.global_position) if zone_fn.is_valid() else ""
	var goal := _nearest_node(player.global_position, zone)
	var target: Vector3
	if _from == goal:
		target = player.global_position
	else:
		var nxt := _next_hop(_from, goal)
		target = nav_pos[nxt]
		if Vector2(target.x - global_position.x, target.z - global_position.z).length() < 0.25:
			_from = nxt
	var dir := target - global_position
	dir.y = 0.0
	if dir.length() > 0.02:
		global_position += dir.normalized() * minf(step, dir.length())
		face(target)


func _flat_dist(p: Vector3) -> float:
	return Vector2(global_position.x - p.x, global_position.z - p.z).length()


# ------------------------------------------------------------------ حلقات
func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_body.position.y = 0.06 * sin(_t * 1.6)
	_body.rotation.z = 0.025 * sin(_t * 1.1)
	for i in _arms.size():
		_arms[i].rotation.x = 0.12 + 0.06 * sin(_t * 1.3 + i * 1.7)
	_twitch_t -= delta
	if _twitch_t <= 0.0:
		_twitch_t = randf_range(0.5, 2.4)
		_head_goal = Vector3(randf_range(-0.2, 0.2), randf_range(-0.3, 0.3), randf_range(-0.55, 0.55))
	_head.rotation = _head.rotation.lerp(_head_goal, clampf(delta * 9.0, 0.0, 1.0))
	if mode == Mode.HUNT and not _seen:
		_body.position.x = randf_range(-0.012, 0.012)
	else:
		_body.position.x = 0.0
	if randf() < 0.004:
		_eye_mat.emission_energy_multiplier = 0.0
	else:
		_eye_mat.emission_energy_multiplier = lerpf(_eye_mat.emission_energy_multiplier, 3.5, delta * 12.0)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	match mode:
		Mode.PEEK:
			_peek_left -= delta
			face(player.global_position)
			if player_sees_me():
				if not _seen:
					_seen = true
					first_seen.emit()
					Sfx.play("sting", -4.0)
				_look_time += delta
			if _look_time > 1.3 or _peek_left <= 0.0:
				vanish()
		Mode.HUNT:
			var seen := player_sees_me()
			var dist := _flat_dist(player.global_position)
			if seen:
				if not _seen and _unseen_for > 2.5:
					Sfx.play("sting", -8.0)
					first_seen.emit()
				_seen = true
				_unseen_for = 0.0
				face(player.global_position)
			else:
				_seen = false
				_unseen_for += delta
				_advance(speed * delta)
			var f := clampf(1.0 - dist / 11.0, 0.0, 1.0)
			Game.fear = lerpf(Game.fear, f * (0.6 if seen else 1.0), clampf(delta * 3.0, 0.0, 1.0))
			_wail_t -= delta
			if _wail_t <= 0.0:
				_wail_t = randf_range(9.0, 16.0)
				Sfx.play3d("wail", get_parent(), global_position, -3.0, randf_range(0.85, 1.1), 5.0, 45.0)
			if dist < kill_dist:
				mode = Mode.STILL
				caught.emit()
		_:
			pass
