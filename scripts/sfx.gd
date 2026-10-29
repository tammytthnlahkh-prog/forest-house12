extends Node
## مدير الصوت: أصوات لمرة واحدة، أصوات مكانية ثلاثية الأبعاد، وحلقات مستمرة.
## كل الأصوات في مجلد audio/ مولَّدة برمجيًا.

var _cache: Dictionary = {}
var _loops: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func get_stream(sound: String, looped: bool = false) -> AudioStream:
	var key := sound + ("#loop" if looped else "")
	if _cache.has(key):
		return _cache[key]
	var path := "res://audio/%s.wav" % sound
	if not ResourceLoader.exists(path):
		push_warning("الصوت غير موجود: " + path)
		return null
	var s: AudioStream = load(path)
	if s == null:
		return null
	if looped and s is AudioStreamWAV:
		s = s.duplicate()
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.data.size() * 0.5)
	_cache[key] = s
	return s


## صوت لمرة واحدة (غير مكاني)
func play(sound: String, vol_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	var st := get_stream(sound)
	if st == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = vol_db
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


## صوت مكاني لمرة واحدة، يُضاف تحت parent (موضعه عالمي)
func play3d(sound: String, parent: Node, pos: Vector3, vol_db: float = 0.0, pitch: float = 1.0,
		unit_size: float = 6.0, max_dist: float = 40.0) -> AudioStreamPlayer3D:
	var st := get_stream(sound)
	if st == null or parent == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.unit_size = unit_size
	p.max_distance = max_dist
	parent.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
	return p


## حلقة صوتية مستمرة تبقى بين المشاهد
func start_loop(sound: String, vol_db: float = -10.0, fade: float = 2.0) -> AudioStreamPlayer:
	if _loops.has(sound):
		var ex: AudioStreamPlayer = _loops[sound]
		var tw0 := ex.create_tween()
		tw0.tween_property(ex, "volume_db", vol_db, fade)
		return ex
	var st := get_stream(sound, true)
	if st == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = -60.0
	add_child(p)
	p.play()
	_loops[sound] = p
	var tw := p.create_tween()
	tw.tween_property(p, "volume_db", vol_db, fade)
	return p


func set_loop_volume(sound: String, vol_db: float, fade: float = 1.0) -> void:
	if _loops.has(sound):
		var p: AudioStreamPlayer = _loops[sound]
		var tw := p.create_tween()
		tw.tween_property(p, "volume_db", vol_db, fade)


func stop_loop(sound: String, fade: float = 1.5) -> void:
	if not _loops.has(sound):
		return
	var p: AudioStreamPlayer = _loops[sound]
	_loops.erase(sound)
	var tw := p.create_tween()
	tw.tween_property(p, "volume_db", -60.0, fade)
	tw.tween_callback(p.queue_free)


func stop_all_loops(fade: float = 1.0) -> void:
	for k in _loops.keys():
		stop_loop(k, fade)
