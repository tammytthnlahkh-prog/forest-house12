extends Node
## الحالة العامة للعبة + الواجهة (ترجمة، تلميحات، تلاشي، رسائل، إيقاف مؤقت) + مؤثر الشاشة.

const MENU_SCENE := "res://scenes/menu.tscn"
const FOREST_SCENE := "res://scenes/forest.tscn"
const HOUSE_SCENE := "res://scenes/house.tscn"
const POST_SHADER := preload("res://shaders/post.gdshader")

var ending_mode: bool = false     # الخروج من البيت بعد إكمال كل الليالي
var sensitivity: float = 0.0022
var touch_mode: bool = false       # جهاز لمس (هاتف/تابلت)
var in_game: bool = false         # هل نحن داخل مشهد لعب (لا القائمة)؟
var input_locked: bool = false    # يمنع التحكم (رسالة مفتوحة، مشهد سينمائي ...)
var player_ref: Node = null
var fear: float = 0.0:
	set(v):
		fear = clampf(v, 0.0, 1.0)
		if _post_mat:
			_post_mat.set_shader_parameter("fear", fear)

signal note_closed

var _post_mat: ShaderMaterial
var _fade: ColorRect
var _subtitle: Label
var _hint: Label
var _cross: ColorRect
var _title_big: Label
var _title_small: Label
var _note_panel: Panel
var _note_label: Label
var _pause_panel: Panel
var _sub_tween: Tween
var _title_tween: Tween
var _sub_id: int = 0
var _note_open: bool = false
var _touch_ui: CanvasLayer
var _close_l: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	touch_mode = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") \
		or OS.has_feature("web_android") or OS.has_feature("web_ios")
	_register_inputs()
	_build_ui()
	_touch_ui = load("res://scripts/touch_controls.gd").new()
	add_child(_touch_ui)
	_refresh_touch()


func _register_inputs() -> void:
	var map := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT],
		"interact": [KEY_E],
		"flashlight": [KEY_F],
		"pause": [KEY_ESCAPE, KEY_P],
	}
	for action in map.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


# ------------------------------------------------------------------ UI
func _label(parent: Node, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", maxi(4, int(size * 0.2)))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_ui() -> void:
	# طبقة التأثير (حبيبات/تشوه) تحت الواجهة
	var post_layer := CanvasLayer.new()
	post_layer.layer = 10
	add_child(post_layer)
	var post_rect := ColorRect.new()
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = POST_SHADER
	post_rect.material = _post_mat
	post_layer.add_child(post_rect)

	var ui := CanvasLayer.new()
	ui.layer = 20
	add_child(ui)

	_cross = ColorRect.new()
	_cross.color = Color(1, 1, 1, 0.45)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.offset_left = -2
	_cross.offset_right = 2
	_cross.offset_top = -2
	_cross.offset_bottom = 2
	_cross.visible = false
	ui.add_child(_cross)

	_hint = _label(ui, 24, Color(1, 0.93, 0.75))
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.anchor_top = 0.5
	_hint.anchor_bottom = 0.5
	_hint.offset_left = -320
	_hint.offset_right = 320
	_hint.offset_top = 34
	_hint.offset_bottom = 90
	_hint.text = ""

	_subtitle = _label(ui, 28, Color(0.95, 0.93, 0.88))
	_subtitle.anchor_left = 0.08
	_subtitle.anchor_right = 0.92
	_subtitle.anchor_top = 0.80
	_subtitle.anchor_bottom = 0.95
	_subtitle.modulate.a = 0.0

	_title_big = _label(ui, 72, Color(0.85, 0.12, 0.1))
	_title_big.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_big.anchor_top = 0.30
	_title_big.anchor_bottom = 0.55
	_title_big.modulate.a = 0.0
	_title_small = _label(ui, 30, Color(0.8, 0.78, 0.72))
	_title_small.anchor_left = 0.1
	_title_small.anchor_right = 0.9
	_title_small.anchor_top = 0.55
	_title_small.anchor_bottom = 0.68
	_title_small.modulate.a = 0.0

	# الرسالة / الورقة
	_note_panel = Panel.new()
	_note_panel.visible = false
	_note_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_note_panel.anchor_left = 0.5
	_note_panel.anchor_right = 0.5
	_note_panel.anchor_top = 0.5
	_note_panel.anchor_bottom = 0.5
	_note_panel.offset_left = -400
	_note_panel.offset_right = 400
	_note_panel.offset_top = -270
	_note_panel.offset_bottom = 270
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.80, 0.72, 0.55)
	sb.border_color = Color(0.25, 0.15, 0.08)
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(4)
	sb.shadow_size = 30
	sb.shadow_color = Color(0, 0, 0, 0.8)
	_note_panel.add_theme_stylebox_override("panel", sb)
	ui.add_child(_note_panel)
	_note_label = Label.new()
	_note_label.add_theme_font_size_override("font_size", 25)
	_note_label.add_theme_color_override("font_color", Color(0.15, 0.08, 0.04))
	_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_note_label.offset_left = 36
	_note_label.offset_right = -36
	_note_label.offset_top = 24
	_note_label.offset_bottom = -50
	_note_panel.add_child(_note_label)
	var close_l := Label.new()
	_close_l = close_l
	close_l.text = "اضغط E للإغلاق"
	close_l.add_theme_font_size_override("font_size", 18)
	close_l.add_theme_color_override("font_color", Color(0.35, 0.2, 0.1))
	close_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_l.anchor_top = 1.0
	close_l.anchor_bottom = 1.0
	close_l.anchor_right = 1.0
	close_l.offset_top = -40
	close_l.offset_bottom = -8
	_note_panel.add_child(close_l)

	# الإيقاف المؤقت
	_pause_panel = Panel.new()
	_pause_panel.visible = false
	_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0, 0, 0, 0.75)
	_pause_panel.add_theme_stylebox_override("panel", psb)
	ui.add_child(_pause_panel)
	var pl := _label(_pause_panel, 40, Color(0.9, 0.9, 0.9))
	pl.set_anchors_preset(Control.PRESET_FULL_RECT)
	pl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	pl.anchor_bottom = 0.5
	pl.offset_bottom = 0
	pl.text = "متوقّفة مؤقتًا\n\nESC  —  متابعة\nQ  —  العودة إلى القائمة الرئيسية"
	var pbox := HBoxContainer.new()
	pbox.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	pbox.anchor_top = 0.62
	pbox.anchor_bottom = 0.62
	pbox.offset_left = -330
	pbox.offset_right = 330
	pbox.offset_top = 0
	pbox.offset_bottom = 80
	pbox.add_theme_constant_override("separation", 30)
	pbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_pause_panel.add_child(pbox)
	for spec in [["متابعة", "resume"], ["القائمة الرئيسية", "menu"]]:
		var pb := Button.new()
		pb.text = spec[0]
		pb.focus_mode = Control.FOCUS_NONE
		pb.custom_minimum_size = Vector2(300, 72)
		pb.add_theme_font_size_override("font_size", 28)
		pb.pressed.connect(_toggle_pause if spec[1] == "resume" else _quit_to_menu)
		pbox.add_child(pb)

	# التلاشي (فوق كل شيء)
	var fl := CanvasLayer.new()
	fl.layer = 100
	add_child(fl)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fl.add_child(_fade)


# ------------------------------------------------------------------ API
## يحوّل نصوص المفاتيح إلى نصوص لمس عند اللعب على الهاتف
func _tr_keys(text: String) -> String:
	if not touch_mode:
		return text
	return text.replace("اضغط E", "اضغط زر التفاعل").replace("اضغط F", "اضغط زر الكشاف")


func _refresh_touch() -> void:
	if _touch_ui:
		_touch_ui.set_active(touch_mode and in_game)
	if _close_l:
		_close_l.text = "اضغط زر التفاعل للإغلاق" if touch_mode else "اضغط E للإغلاق"


func has_hint() -> bool:
	return _hint != null and _hint.text != ""


func say(text: String, duration: float = 4.5) -> void:
	text = _tr_keys(text)
	_sub_id += 1
	var my_id := _sub_id
	if _sub_tween:
		_sub_tween.kill()
	_subtitle.text = text
	_sub_tween = create_tween()
	_sub_tween.tween_property(_subtitle, "modulate:a", 1.0, 0.4)
	await get_tree().create_timer(duration).timeout
	if my_id != _sub_id:
		return
	_sub_tween = create_tween()
	_sub_tween.tween_property(_subtitle, "modulate:a", 0.0, 0.8)


func set_hint(text: String) -> void:
	_hint.text = _tr_keys(text)


func show_crosshair(v: bool) -> void:
	_cross.visible = v


func show_title(big: String, small: String = "", hold: float = 3.0) -> void:
	if _title_tween:
		_title_tween.kill()
	_title_big.text = big
	_title_small.text = small
	_title_tween = create_tween()
	_title_tween.set_parallel(true)
	_title_tween.tween_property(_title_big, "modulate:a", 1.0, 1.2)
	_title_tween.tween_property(_title_small, "modulate:a", 1.0, 1.8)
	_title_tween.chain().tween_interval(hold)
	_title_tween.chain().set_parallel(true)
	_title_tween.tween_property(_title_big, "modulate:a", 0.0, 1.6)
	_title_tween.tween_property(_title_small, "modulate:a", 0.0, 1.6)


func fade(to_alpha: float, t: float = 0.6) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", to_alpha, t)
	await tw.finished


func set_black(v: bool) -> void:
	_fade.color.a = 1.0 if v else 0.0


func goto_scene(path: String) -> void:
	input_locked = true
	await fade(1.0, 0.8)
	input_locked = false
	fear = 0.0
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	await fade(0.0, 1.2)


func show_note(text: String) -> void:
	_note_label.text = text
	_note_panel.visible = true
	_note_open = true
	input_locked = true
	set_hint("")
	Sfx.play("click", -8, 0.8)


func _close_note() -> void:
	_note_panel.visible = false
	_note_open = false
	input_locked = false
	note_closed.emit()


func capture_mouse(v: bool) -> void:
	if touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if v else Input.MOUSE_MODE_VISIBLE


func enter_game_mode() -> void:
	in_game = true
	_refresh_touch()
	capture_mouse(true)
	show_crosshair(true)


func enter_menu_mode() -> void:
	in_game = false
	_refresh_touch()
	capture_mouse(false)
	show_crosshair(false)
	set_hint("")
	fear = 0.0


# ------------------------------------------------------------------ input
func _input(event: InputEvent) -> void:
	# أول لمسة على الشاشة = جهاز لمس (مفيد للمتصفح على الهاتف)
	if event is InputEventScreenTouch and event.pressed and not touch_mode:
		touch_mode = true
		_refresh_touch()
	if not in_game:
		return
	if _note_open:
		if event.is_action_pressed("interact") or event.is_action_pressed("pause"):
			_close_note()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused and event is InputEventKey and event.pressed and event.physical_keycode == KEY_Q:
		_quit_to_menu()
		return
	if event is InputEventMouseButton and event.pressed and not get_tree().paused:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			capture_mouse(true)


func _quit_to_menu() -> void:
	get_tree().paused = false
	_pause_panel.visible = false
	Sfx.stop_all_loops(0.5)
	enter_menu_mode()
	goto_scene(MENU_SCENE)


func _toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	_pause_panel.visible = p
	capture_mouse(not p)
