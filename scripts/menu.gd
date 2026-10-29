extends Control
## القائمة الرئيسية — مشهد ليلي بسيط مرسوم بالأشكال.

var _window: Polygon2D
var _title: Label
var _t: float = 0.0


func _ready() -> void:
	Game.enter_menu_mode()
	Game.ending_mode = false
	Sfx.start_loop("drone_loop", -14.0, 3.0)
	Sfx.start_loop("wind_loop", -24.0, 3.0)
	_build_scene()
	_build_ui()


func _poly(points: PackedVector2Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	add_child(p)
	return p


func _circle(center: Vector2, r: float, color: Color) -> Polygon2D:
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return _poly(pts, color)


func _build_scene() -> void:
	var bg := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.02, 0.05, 0.11), Color(0.0, 0.0, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	bg.texture = gt
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(bg)

	_circle(Vector2(1010, 140), 56, Color(0.86, 0.88, 0.8))
	_circle(Vector2(1030, 128), 50, Color(0.9, 0.91, 0.84))

	# البيت
	_poly(PackedVector2Array([Vector2(470, 640), Vector2(470, 500), Vector2(800, 500), Vector2(800, 640)]), Color(0.03, 0.03, 0.035))
	_poly(PackedVector2Array([Vector2(462, 500), Vector2(462, 484), Vector2(808, 484), Vector2(808, 500)]), Color(0.025, 0.025, 0.03))
	var dome_pts := PackedVector2Array()
	for i in 21:
		var a := PI * i / 20.0
		dome_pts.append(Vector2(540, 484) + Vector2(-cos(a), -sin(a)) * 46.0)
	_poly(dome_pts, Color(0.03, 0.03, 0.035))
	_window = _poly(PackedVector2Array([Vector2(520, 540), Vector2(560, 540), Vector2(560, 590), Vector2(520, 590)]), Color(1.0, 0.68, 0.28))
	_poly(PackedVector2Array([Vector2(700, 540), Vector2(740, 540), Vector2(740, 590), Vector2(700, 590)]), Color(0.01, 0.01, 0.015))
	_poly(PackedVector2Array([Vector2(618, 640), Vector2(618, 556), Vector2(652, 556), Vector2(652, 640)]), Color(0.01, 0.008, 0.006))

	# أشجار
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 34:
		var x := rng.randf_range(-20, 1300)
		if x > 440 and x < 830:
			x += 420 if x > 635 else -420
		var h := rng.randf_range(160, 380)
		var w := h * rng.randf_range(0.28, 0.4)
		var c := Color(0.005, 0.012, 0.008).lerp(Color(0.01, 0.025, 0.018), rng.randf())
		_poly(PackedVector2Array([Vector2(x - w, 650), Vector2(x, 650 - h), Vector2(x + w, 650)]), c)
	_poly(PackedVector2Array([Vector2(0, 630), Vector2(1280, 622), Vector2(1280, 720), Vector2(0, 720)]), Color(0.0, 0.0, 0.0))


func _style_button(b: Button) -> void:
	b.add_theme_font_size_override("font_size", 34)
	b.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.25, 0.2))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.border_color = Color(0.45, 0.07, 0.07)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(10)
	b.add_theme_stylebox_override("normal", sb)
	var sh := sb.duplicate()
	sh.bg_color = Color(0.12, 0.0, 0.0, 0.8)
	sh.border_color = Color(0.9, 0.15, 0.1)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.custom_minimum_size = Vector2(320, 62)
	b.focus_mode = Control.FOCUS_NONE


func _build_ui() -> void:
	var box := VBoxContainer.new()
	box.anchor_left = 0.0
	box.anchor_right = 0.5
	box.anchor_top = 0.0
	box.anchor_bottom = 1.0
	box.offset_left = 70
	box.offset_right = 0
	box.offset_top = 70
	box.offset_bottom = -50
	box.add_theme_constant_override("separation", 16)
	add_child(box)

	_title = Label.new()
	_title.text = "بيت الغابة"
	_title.add_theme_font_override("font", load("res://fonts/DejaVuSans-Bold.ttf"))
	_title.add_theme_font_size_override("font_size", 104)
	_title.add_theme_color_override("font_color", Color(0.78, 0.08, 0.06))
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_title.add_theme_constant_override("outline_size", 10)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	var sub := Label.new()
	sub.text = "لعبة رعب عربية"
	sub.add_theme_font_size_override("font_size", 30)
	sub.add_theme_color_override("font_color", Color(0.65, 0.62, 0.58))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 30)
	box.add_child(sp)

	var start := Button.new()
	start.text = "ابدأ اللعبة"
	_style_button(start)
	start.pressed.connect(_on_start)
	box.add_child(start)

	var quit := Button.new()
	quit.text = "خروج"
	_style_button(quit)
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)

	var sens_l := Label.new()
	sens_l.text = "حساسية النظر" if Game.touch_mode else "حساسية الماوس"
	sens_l.add_theme_font_size_override("font_size", 20)
	sens_l.add_theme_color_override("font_color", Color(0.6, 0.58, 0.55))
	sens_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sens_l)
	var sl := HSlider.new()
	sl.min_value = 0.0008
	sl.max_value = 0.006
	sl.step = 0.0002
	sl.value = Game.sensitivity
	sl.custom_minimum_size = Vector2(320, 44 if Game.touch_mode else 24)
	sl.focus_mode = Control.FOCUS_NONE
	sl.value_changed.connect(func(v: float) -> void: Game.sensitivity = v)
	box.add_child(sl)

	var help := Label.new()
	help.text = "WASD  حركة     الماوس  نظر     E  تفاعل\nF  كشاف     Shift  ركض     ESC  إيقاف مؤقت"
	if Game.touch_mode:
		help.text = "عصا اليسار  حركة     السحب باليمين  نظر\nأزرار الشاشة  تفاعل / كشاف / ركض / إيقاف"
	help.add_theme_font_size_override("font_size", 21)
	help.add_theme_color_override("font_color", Color(0.55, 0.53, 0.5))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(help)

	var warn := Label.new()
	warn.text = "تحذير: لعبة رعب. يُفضّل اللعب بسماعات وفي غرفة مظلمة."
	warn.add_theme_font_size_override("font_size", 19)
	warn.add_theme_color_override("font_color", Color(0.5, 0.2, 0.18))
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(warn)


func _on_start() -> void:
	Sfx.play("click", -4.0)
	Sfx.stop_loop("drone_loop", 2.0)
	Game.ending_mode = false
	Game.goto_scene(Game.FOREST_SCENE)


func _process(delta: float) -> void:
	_t += delta
	var f := 1.0
	if randf() < 0.02:
		f = randf_range(0.3, 0.8)
	_window.modulate.a = lerpf(_window.modulate.a, f, 0.5)
	_title.modulate.a = lerpf(_title.modulate.a, 1.0 if randf() > 0.015 else 0.55, 0.4)
