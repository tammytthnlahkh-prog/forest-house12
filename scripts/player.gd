extends CharacterBody3D
## اللاعب: منظور الشخص الأول + كشاف + تفاعل.
## طبقات الاصطدام: 1 = العالم، 2 = اللاعب، 4 = الأشياء القابلة للتفاعل.

const WALK_SPEED := 2.2
const RUN_SPEED := 3.5
const BACK_FACTOR := 0.7
const GRAVITY := 18.0

var head: Node3D
var camera: Camera3D
var flashlight: SpotLight3D
var ray: RayCast3D

var pitch: float = 0.0
var locked: bool = false             # قفل سينمائي (موت، مشهد ...)
var step_sound: String = "step_wood" # step_wood أو step_leaf
var flashlight_energy: float = 2.4
var _bob: float = 0.0
var _step_acc: float = 0.0
var _target: Object = null
var _shake: float = 0.0
var _flicker_t: float = 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	add_child(col)

	head = Node3D.new()
	head.position = Vector3(0, 1.6, 0)
	add_child(head)

	camera = Camera3D.new()
	camera.fov = 74.0
	camera.near = 0.05
	camera.far = 260.0
	head.add_child(camera)
	camera.make_current()

	flashlight = SpotLight3D.new()
	flashlight.spot_range = 20.0
	flashlight.spot_angle = 30.0
	flashlight.spot_angle_attenuation = 0.8
	flashlight.light_energy = flashlight_energy
	flashlight.light_color = Color(1.0, 0.95, 0.82)
	flashlight.shadow_enabled = true
	flashlight.position = Vector3(0.18, -0.12, -0.1)
	head.add_child(flashlight)

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -2.5)
	ray.collision_mask = 1 | 4
	ray.add_exception(self)
	camera.add_child(ray)

	Game.player_ref = self


func _unhandled_input(event: InputEvent) -> void:
	if locked or Game.input_locked or get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * Game.sensitivity)
		pitch = clampf(pitch - event.relative.y * Game.sensitivity, -1.45, 1.45)
		head.rotation.x = pitch
	elif event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
		Sfx.play("click", -10)
	elif event.is_action_pressed("interact"):
		_try_interact()


## دوران الكاميرا بالسحب باللمس (x = يمين/يسار، y = أعلى/أسفل) بالراديان
func look_delta(d: Vector2) -> void:
	rotate_y(-d.x)
	pitch = clampf(pitch - d.y, -1.45, 1.45)
	head.rotation.x = pitch


func _try_interact() -> void:
	if _target and is_instance_valid(_target) and _target.has_meta("interact"):
		var cb: Callable = _target.get_meta("interact")
		cb.call()


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	var speed := WALK_SPEED
	if not (locked or Game.input_locked):
		var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = global_transform.basis * Vector3(v.x, 0, v.y)
		if Input.is_action_pressed("sprint") and v.y <= 0.0:
			speed = RUN_SPEED
		if v.y > 0.0:
			speed *= BACK_FACTOR
	velocity.x = move_toward(velocity.x, dir.x * speed, 22.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 22.0 * delta)
	if is_on_floor():
		velocity.y = -0.1
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	var hs := Vector2(velocity.x, velocity.z).length()
	if hs > 0.3 and is_on_floor():
		_bob += delta * hs * 2.4
		head.position.y = 1.6 + sin(_bob * 2.0) * 0.022
		head.position.x = cos(_bob) * 0.012
		_step_acc += delta * hs
		if _step_acc > 1.55:
			_step_acc = 0.0
			Sfx.play("%s%d" % [step_sound, randi_range(1, 3)], -7.0 if hs < 3.0 else -3.0, randf_range(0.9, 1.1))
	else:
		head.position.y = lerpf(head.position.y, 1.6, 8.0 * delta)
		head.position.x = lerpf(head.position.x, 0.0, 8.0 * delta)


func _process(delta: float) -> void:
	# هدف التفاعل
	var tgt: Object = null
	if not locked and not Game.input_locked and ray.is_colliding():
		var c := ray.get_collider()
		if c and c.has_meta("interact"):
			tgt = c
	if tgt != _target:
		_target = tgt
		Game.set_hint(str(tgt.get_meta("prompt", "")) if tgt else "")

	# اهتزاز الكاميرا
	if _shake > 0.001:
		camera.position = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.05
		_shake = move_toward(_shake, 0.0, delta * 2.0)
	else:
		camera.position = Vector3.ZERO

	# ارتخاء حركة الكشاف + وميضه عند الخوف
	var cur := flashlight.global_basis.get_rotation_quaternion()
	var want := camera.global_basis.get_rotation_quaternion()
	flashlight.global_basis = Basis(cur.slerp(want, clampf(delta * 14.0, 0.0, 1.0)))
	if Game.fear > 0.35 and randf() < Game.fear * 0.08:
		_flicker_t = randf_range(0.04, 0.16)
	if _flicker_t > 0.0:
		_flicker_t -= delta
		flashlight.light_energy = flashlight_energy * randf_range(0.0, 0.5)
	else:
		flashlight.light_energy = flashlight_energy


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func teleport(pos: Vector3, yaw: float) -> void:
	global_position = pos
	rotation = Vector3(0, yaw, 0)
	pitch = 0.0
	head.rotation.x = 0.0
	velocity = Vector3.ZERO


func head_pos() -> Vector3:
	return head.global_position


## يدير الرأس نحو نقطة بالعالم (للمشاهد السينمائية)
func look_at_point(p: Vector3, t: float = 0.2) -> void:
	var d := p - head.global_position
	var yaw_t := atan2(-d.x, -d.z)
	var pitch_t := clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.4, 1.4)
	var yaw_0 := rotation.y
	var pitch_0 := pitch
	var tw := create_tween()
	tw.tween_method(func(w: float) -> void:
		rotation.y = lerp_angle(yaw_0, yaw_t, w)
		pitch = lerpf(pitch_0, pitch_t, w)
		head.rotation.x = pitch, 0.0, 1.0, t)
