extends Node

const Village = preload("res://simulation/village_sim.gd")
const World = preload("res://presentation/world_view.gd")
const Hud = preload("res://ui/game_hud.gd")
const Clock = preload("res://core/simulation_clock.gd")
const SAVE_PATH := "user://vale-save-v1.json"
var sim: RefCounted
var world: Node3D
var hud: CanvasLayer
var clock: RefCounted
var speed := 1
var build_kind := ""
var army_order := ""
var hover_cell := Vector2i(-1,-1)
var selected_id := -1
var drag_start := Vector2.ZERO
var pointer_down := false
var dragging := false
var pointer_ui := false
var since_refresh := 0.0
var since_autosave := 0.0
var application_paused := false
var touch_points := {}
var pinch_distance := 0.0
var mute := false
var audio_player: AudioStreamPlayer
var event_signature := ""

func _ready() -> void:
	_configure_display()
	get_window().size_changed.connect(_configure_display)
	sim = Village.new()
	sim.setup()
	clock = Clock.new(100000)
	world = World.new()
	add_child(world)
	world.setup(sim)
	hud = Hud.new()
	add_child(hud)
	hud.setup(sim)
	hud.build_selected.connect(_select_build)
	hud.army_selected.connect(_select_army)
	hud.command_requested.connect(_command)
	hud.save_requested.connect(_save)
	hud.load_requested.connect(_load_save)
	hud.restart_requested.connect(_restart)
	hud.speed_selected.connect(func(value): speed = value)
	hud.focus_requested.connect(func(cell): world.focus_cell(cell))
	_setup_audio()
	hud.show_message("Sua vila está pronta. Abra Construir e escolha a primeira casa.")
	print("PLAYABLE_READY: Vale dos Vinhedos 0.1")

func _configure_display() -> void:
	# Web and mobile report framebuffer pixels; use the platform density so
	# the responsive HUD and pointer coordinates stay in logical screen units.
	if OS.has_feature("web") or OS.has_feature("mobile"):
		var density := maxf(1.0,DisplayServer.screen_get_scale())
		if not is_equal_approx(get_window().content_scale_factor,density):
			get_window().content_scale_factor = density

func _process(delta: float) -> void:
	if sim == null:
		return
	clock.paused = sim.paused or application_paused
	var due: int = clock.advance_usec(roundi(minf(delta,0.25)*1000000.0)*speed)
	for i in range(due):
		sim.step()
	world.sync(delta)
	since_refresh += delta
	since_autosave += delta
	if since_refresh > 0.2:
		since_refresh = 0.0
		hud.refresh()
		if not build_kind.is_empty() and hover_cell.x >= 0:
			world.set_preview(build_kind,hover_cell,sim.can_place(build_kind,hover_cell).is_empty())
	if since_autosave >= 60.0 and not application_paused:
		since_autosave = 0.0
		_write_save("user://vale-autosave-v1.json")
	if not sim.events.is_empty():
		var latest: String = str(sim.events.back().tick)+str(sim.events.back().text)
		if latest != event_signature:
			event_signature = latest
			var message: String = sim.events.back().text
			hud.show_message(message)
			if message.contains("concluída") or message.contains("formado") or message.contains("protegido"):
				_chime()

func _select_build(kind: String) -> void:
	build_kind = kind
	army_order = ""
	selected_id = -1
	world.set_selected(-1)
	world.clear_preview()
	if not kind.is_empty():
		hud.close_panels()
		hud.set_mode("Construir "+sim.definition(kind).name+": toque no terreno. Esc cancela.")
	else:
		hud.set_mode("")

func _select_army(order: String) -> void:
	army_order = order
	build_kind = ""
	world.clear_preview()
	if not order.is_empty():
		hud.close_panels()
		hud.set_mode("Indique o objetivo do exército no terreno. Esc cancela.")
	else:
		hud.set_mode("")

func _command(kind: String, payload: Dictionary) -> void:
	var result: Dictionary = sim.command(kind,payload)
	hud.show_message(result.message)
	hud.refresh()

func _world_click(point: Vector2) -> void:
	var cell: Vector2i = world.screen_to_cell(point)
	if cell.x < 0:
		return
	if not build_kind.is_empty():
		var result: Dictionary = sim.command("build",{"kind":build_kind,"cell":cell})
		hud.show_message(result.message)
		if result.ok:
			_select_build("")
		return
	if not army_order.is_empty():
		var result: Dictionary = sim.command("army",{"order":army_order,"target":cell})
		hud.show_message(result.message)
		if result.ok:
			_select_army("")
		return
	var b: Dictionary = sim.building_at(cell)
	selected_id = b.get("id",-1)
	world.set_selected(selected_id)
	hud.inspect(b)

func _input(event: InputEvent) -> void:
	if sim == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_select_build("")
				_select_army("")
				hud.close_panels()
			KEY_SPACE:
				_command("pause",{})
			KEY_1: speed = 1
			KEY_2: speed = 2
			KEY_4: speed = 4
			KEY_F5: _save()
			KEY_F9: _load_save()
			KEY_HOME: world.focus_cell(Vector2i(10,11))
			KEY_M:
				mute = not mute
				hud.show_message("Sons desativados" if mute else "Sons ativados")
			KEY_LEFT, KEY_A: world.pan_by(Vector2(65,0))
			KEY_RIGHT, KEY_D: world.pan_by(Vector2(-65,0))
			KEY_UP, KEY_W: world.pan_by(Vector2(0,65))
			KEY_DOWN, KEY_S: world.pan_by(Vector2(0,-65))
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed and not hud.blocks_pointer(event.position):
			world.zoom_by(-2.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 2.0)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pointer_down = true
				dragging = false
				drag_start = event.position
				pointer_ui = hud.blocks_pointer(event.position)
			else:
				if pointer_down and not dragging and not pointer_ui and not hud.blocks_pointer(event.position):
					_world_click(event.position)
				pointer_down = false
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_select_build("")
			_select_army("")
	if event is InputEventMouseMotion:
		if pointer_down and not pointer_ui:
			if event.position.distance_to(drag_start)>8.0:
				dragging = true
			if dragging:
				world.pan_by(event.relative)
		if not build_kind.is_empty() and not hud.blocks_pointer(event.position):
			hover_cell = world.screen_to_cell(event.position)
			world.set_preview(build_kind,hover_cell,sim.can_place(build_kind,hover_cell).is_empty())
	if event is InputEventMagnifyGesture:
		world.zoom_by((1.0-event.factor)*20.0)
	if event is InputEventPanGesture and not hud.blocks_pointer(event.position):
		world.pan_by(-event.delta*12.0)
	# Touch -> mouse emulation supplies tap/drag. Two fingers add pinch zoom.
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
		else:
			touch_points.erase(event.index)
		if touch_points.size() != 2:
			pinch_distance = 0.0
	if event is InputEventScreenDrag:
		touch_points[event.index] = event.position
		if touch_points.size() == 2:
			var positions: Array = touch_points.values()
			var distance: float = positions[0].distance_to(positions[1])
			if pinch_distance > 0.0:
				world.zoom_by((pinch_distance-distance)*0.06)
			pinch_distance = distance
			dragging = true

func _write_save(path: String) -> bool:
	var data := {"format":"vale-v1","simulation":sim.snapshot(),"clock":clock.capture(),"speed":speed}
	var text := JSON.stringify(data)
	var temporary := path+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	file.close()
	var check := FileAccess.open(temporary,FileAccess.READ)
	if check == null or not JSON.parse_string(check.get_as_text()) is Dictionary:
		return false
	check.close()
	if FileAccess.file_exists(path):
		var backup := path+".bak"
		if DirAccess.copy_absolute(path,backup) != OK:
			return false
	return DirAccess.rename_absolute(temporary,path) == OK

func _save() -> void:
	hud.show_message("Partida salva neste dispositivo." if _write_save(SAVE_PATH) else "Não foi possível salvar. Verifique espaço e permissões locais.")

func _load_save() -> void:
	_load_paths([SAVE_PATH,SAVE_PATH+".bak","user://vale-autosave-v1.json"])

func _load_paths(paths: Array) -> bool:
	for path in paths:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path,FileAccess.READ)
		if file == null or file.get_length()>4000000:
			continue
		var data: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if not data is Dictionary or data.get("format") != "vale-v1" or not data.get("simulation") is Dictionary or not data.get("clock") is Dictionary:
			continue
		var new_clock := Clock.new(100000)
		if new_clock.restore(data.clock) != OK:
			continue
		if sim.restore(data.simulation):
			clock = new_clock
			speed = int(data.get("speed",1)) if int(data.get("speed",1)) in [1,2,4] else 1
			_clear_world()
			hud.show_message("Partida recuperada. Nada avançou enquanto esteve fechada.")
			return true
	hud.show_message("Não há uma partida salva válida neste dispositivo.")
	return false

func _clear_world() -> void:
	_select_build("")
	_select_army("")
	selected_id = -1
	world.queue_free()
	world = World.new()
	add_child(world)
	world.setup(sim)
	hud.close_panels()
	hud.inspect({})
	hud.refresh()

func _restart() -> void:
	sim.setup()
	clock = Clock.new(100000)
	speed = 1
	_clear_world()
	hud.show_message("Nova partida iniciada. Seu salvamento manual anterior foi preservado.")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		application_paused = true
		if sim != null:
			_write_save("user://vale-autosave-v1.json")
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		application_paused = false
	elif what == NOTIFICATION_WM_CLOSE_REQUEST and sim != null:
		_write_save("user://vale-autosave-v1.json")

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.volume_db = -18
	add_child(audio_player)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(11025*2)
	for i in range(11025):
		var t := float(i)/22050.0
		var note := sin(TAU*523.25*t)*exp(-t*8.0)+0.4*sin(TAU*783.99*t)*exp(-t*10.0)
		bytes.encode_s16(i*2,int(clampf(note,-1,1)*16000))
	stream.data = bytes
	audio_player.stream = stream

func _chime() -> void:
	if not mute:
		audio_player.play()
