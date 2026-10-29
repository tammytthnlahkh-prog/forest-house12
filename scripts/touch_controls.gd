extends CanvasLayer
## أزرار اللمس للهاتف: عصا حركة (يسار) + سحب للنظر (يمين) + أزرار تفاعل/كشاف/ركض/إيقاف.
## تعمل مع الكيبورد والماوس بالتوازي ولا تتعارض معهما.

const JOY_RADIUS := 95.0
const LOOK_FACTOR := 1.7

var _draw_node: Control
var _fingers: Dictionary = {}   # index -> {"role": String, "start": Vector2, "pos": Vector2}
var _joy_center: Vector2 = Vector2.ZERO
var _joy_vec: Vector2 = Vector2.ZERO
var _sprint_on: bool = false
var _flash_on: bool = true
var _pressed_btn: Dictionary = {}  # role -> true (لتمييز الزر المضغوط بصريًا)


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_draw_node = Control.new()
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.draw.connect(_on_draw)
	add_child(_draw_node)
	visible = false


# ---------------------------------------------------------------- تخطيط
func _vp() -> Vector2:
	return get_viewport().get_visible_rect().size


func _buttons() -> Dictionary:
	var s := _vp()
	return {
		"interact": {"c": Vector2(s.x - 120, s.y - 140), "r": 64.0, "label": "تفاعل"},
		"flash": {"c": Vector2(s.x - 270, s.y - 95), "r": 46.0, "label": "كشاف"},
		"sprint": {"c": Vector2(s.x - 100, s.y - 295), "r": 46.0, "label": "ركض"},
		"pause": {"c": Vector2(s.x - 55, 55), "r": 32.0, "label": "II"},
	}


func _hit_button(p: Vector2) -> String:
	var b := _buttons()
	for k in b.keys():
		if p.distance_to(b[k]["c"]) <= float(b[k]["r"]) + 14.0:
			return k
	return ""


# ---------------------------------------------------------------- تفعيل/إخفاء
func set_active(v: bool) -> void:
	if visible == v:
		return
	visible = v
	if not v:
		reset()


func reset() -> void:
	for idx in _fingers.keys():
		_end_finger(idx)
	_fingers.clear()
	_joy_vec = Vector2.ZERO
	_apply_move()
	_sprint_on = false
	Input.action_release("sprint")
	_pressed_btn.clear()
	if _draw_node:
		_draw_node.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		reset()


# ---------------------------------------------------------------- إدخال
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_finger(event.index, event.position)
		else:
			_end_finger(event.index)
			_fingers.erase(event.index)
		_draw_node.queue_redraw()
	elif event is InputEventScreenDrag:
		_drag_finger(event.index, event.position, event.relative)
		_draw_node.queue_redraw()


func _begin_finger(idx: int, pos: Vector2) -> void:
	var paused := get_tree().paused
	var btn := _hit_button(pos)
	if btn != "":
		if paused and btn != "pause":
			return
		_fingers[idx] = {"role": "btn_" + btn, "start": pos, "pos": pos}
		_press_button(btn)
		return
	if paused:
		return
	var s := _vp()
	if pos.x < s.x * 0.5:
		# عصا حركة عائمة: تظهر حيث لمست الإصبع
		var already := false
		for f in _fingers.values():
			if f["role"] == "move":
				already = true
		if not already:
			_joy_center = pos
			_joy_vec = Vector2.ZERO
			_fingers[idx] = {"role": "move", "start": pos, "pos": pos}
	else:
		_fingers[idx] = {"role": "look", "start": pos, "pos": pos}


func _drag_finger(idx: int, pos: Vector2, rel: Vector2) -> void:
	if not _fingers.has(idx):
		return
	var f: Dictionary = _fingers[idx]
	f["pos"] = pos
	match f["role"]:
		"move":
			var d: Vector2 = pos - _joy_center
			if d.length() > JOY_RADIUS:
				# العصا تتبع الإصبع إن ابتعد كثيرًا (حركة مريحة)
				_joy_center = pos - d.normalized() * JOY_RADIUS
				d = pos - _joy_center
			_joy_vec = d / JOY_RADIUS
			_apply_move()
		"look":
			_look(rel)


func _end_finger(idx: int) -> void:
	if not _fingers.has(idx):
		return
	var role: String = _fingers[idx]["role"]
	if role == "move":
		_joy_vec = Vector2.ZERO
		_apply_move()
	elif role.begins_with("btn_"):
		_release_button(role.substr(4))


func _look(rel: Vector2) -> void:
	var p := Game.player_ref
	if p == null or not is_instance_valid(p):
		return
	if p.locked or Game.input_locked or get_tree().paused:
		return
	p.look_delta(rel * Game.sensitivity * LOOK_FACTOR)


func _apply_move() -> void:
	var v := _joy_vec
	if v.length() < 0.15:
		v = Vector2.ZERO
	# أخرج الإحداثيات إلى إجراءات الحركة (تتكامل مع Input.get_vector)
	_set_action("move_left", maxf(-v.x, 0.0))
	_set_action("move_right", maxf(v.x, 0.0))
	_set_action("move_forward", maxf(-v.y, 0.0))
	_set_action("move_back", maxf(v.y, 0.0))
	# دفع العصا للأمام بالكامل = ركض تلقائي
	if v.y < -0.92 and not _sprint_on:
		Input.action_press("sprint")
	elif not _sprint_on:
		Input.action_release("sprint")


func _set_action(a: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(a, strength)
	else:
		Input.action_release(a)


func _tap_action(a: String) -> void:
	var ev := InputEventAction.new()
	ev.action = a
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = a
	up.pressed = false
	Input.parse_input_event(up)


func _press_button(btn: String) -> void:
	_pressed_btn[btn] = true
	match btn:
		"interact":
			_tap_action("interact")
		"flash":
			_tap_action("flashlight")
		"sprint":
			_sprint_on = not _sprint_on
			if _sprint_on:
				Input.action_press("sprint")
			else:
				Input.action_release("sprint")
		"pause":
			_tap_action("pause")


func _release_button(btn: String) -> void:
	_pressed_btn.erase(btn)


# ---------------------------------------------------------------- رسم
func _process(_delta: float) -> void:
	if visible:
		_draw_node.queue_redraw()


func _on_draw() -> void:
	var font: Font = load("res://fonts/DejaVuSans.ttf")
	var paused := get_tree().paused
	var has_target := Game.has_hint()

	# العصا
	for f in _fingers.values():
		if f["role"] == "move":
			_draw_node.draw_circle(_joy_center, JOY_RADIUS, Color(1, 1, 1, 0.07))
			_draw_node.draw_arc(_joy_center, JOY_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
			_draw_node.draw_circle(_joy_center + _joy_vec.limit_length(1.0) * JOY_RADIUS, 40.0, Color(1, 1, 1, 0.32))
	# تلميح مكان العصا حين لا يُلمس شيء
	var has_move := false
	for f in _fingers.values():
		if f["role"] == "move":
			has_move = true
	if not has_move and not paused:
		var s := _vp()
		var hc := Vector2(s.x * 0.17, s.y - 150)
		_draw_node.draw_arc(hc, JOY_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.14), 3.0, true)
		_draw_node.draw_circle(hc, 34.0, Color(1, 1, 1, 0.08))

	# الأزرار
	var b := _buttons()
	for k in b.keys():
		if paused and k != "pause":
			continue
		var c: Vector2 = b[k]["c"]
		var r: float = b[k]["r"]
		var on := _pressed_btn.has(k)
		var base_a := 0.22
		var col := Color(1, 1, 1, base_a)
		if k == "interact" and has_target:
			col = Color(1.0, 0.82, 0.4, 0.5)
		if k == "sprint" and _sprint_on:
			col = Color(0.5, 0.9, 1.0, 0.5)
		if on:
			col.a = minf(col.a + 0.3, 0.85)
		_draw_node.draw_circle(c, r, col)
		_draw_node.draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.55), 3.0, true)
		var label: String = b[k]["label"]
		var fs := 22 if k != "pause" else 26
		var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		_draw_node.draw_string(font, c + Vector2(-ts.x * 0.5, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.9))
