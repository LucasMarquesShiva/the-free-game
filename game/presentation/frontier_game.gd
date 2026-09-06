extends Node

const Village = preload("res://simulation/frontier_sim.gd")
const World = preload("res://presentation/frontier_world.gd")
const Hud = preload("res://ui/frontier_hud.gd")
const Clock = preload("res://core/simulation_clock.gd")
const SAVE_PATH := "user://vale-frontier-save-v1.json"
var sim: RefCounted
var world: Node3D
var hud: CanvasLayer
var clock: RefCounted
var speed := 1
var build_kind := ""
var hover_cell := Vector2i(-1,-1)
var selected_id := -1
var drag_start := Vector2.ZERO
var pointer_down := false
var dragging := false
var pointer_ui := false
var pan_pointer_down := false
var pan_pointer_ui := false
var since_refresh := 0.0
var since_autosave := 0.0
var application_paused := false
var touch_points := {}
var pinch_distance := 0.0
var mute := false
var audio_player: AudioStreamPlayer
var event_signature := ""
var road_path: Array[Vector2i] = []

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
	hud.command_requested.connect(_command)
	hud.save_requested.connect(_save)
	hud.load_requested.connect(_load_save)
	hud.restart_requested.connect(_restart)
	hud.speed_selected.connect(func(value): speed = value)
	hud.focus_requested.connect(_focus_map)
	hud.entrance_highlighted.connect(_highlight_entrance)
	_setup_audio()
	hud.show_message("Seu vale começa aqui. Use Estradas para ligar a entrada do principal à escola.")
	print("PLAYABLE_READY: Vale dos Vinhedos — Nova fronteira 0.3")

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
	world.visual_speed = float(speed)
	world.sync(delta)
	since_refresh += delta
	since_autosave += delta
	if since_refresh > 0.2:
		since_refresh = 0.0
		hud.refresh()
		if not build_kind.is_empty() and build_kind != "road" and hover_cell.x >= 0:
			world.set_preview(build_kind,hover_cell,sim.can_place(build_kind,hover_cell).is_empty())
	if since_autosave >= 60.0 and not application_paused:
		since_autosave = 0.0
		_write_save("user://vale-frontier-autosave-v1.json")
	if not sim.events.is_empty():
		var latest: String = str(sim.events.back().tick)+str(sim.events.back().text)
		if latest != event_signature:
			event_signature = latest
			var message: String = sim.events.back().text
			hud.show_message(message)
			if message.contains("concluída") or message.contains("formado") or message.contains("protegido"):
				_chime()

func _select_build(kind: String) -> void:
	_reset_pointer()
	build_kind = kind
	if not kind.is_empty():
		hud._dismiss_tutorial()
	selected_id = -1
	world.set_selected(-1)
	world.clear_preview()
	road_path.clear()
	if kind == "road":
		hud.close_panels()
		hud.set_mode("Estradas · arraste para traçar · 1 pedra por trecho · Esc termina")
		world.set_road_preview(road_path)
	elif not kind.is_empty():
		hud.close_panels()
		hud.set_mode("Construir "+sim.definition(kind).name+": toque no terreno. Esc cancela.")
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
	if build_kind == "road":
		_command("road",{"cell":cell})
		return
	if not build_kind.is_empty():
		var result: Dictionary = sim.command("build",{"kind":build_kind,"cell":cell})
		hud.show_message(result.message)
		if result.ok:
			_select_build("")
		return
	var b: Dictionary = world.building_at_screen(point) if world.has_method("building_at_screen") else sim.building_at(cell)
	selected_id = b.get("id",-1)
	world.set_selected(selected_id)
	hud.inspect(b)

func _reset_pointer() -> void:
	pointer_down = false
	pointer_ui = false
	dragging = false
	pan_pointer_down = false
	pan_pointer_ui = false
	hover_cell = Vector2i(-1,-1)
	road_path.clear()
	touch_points.clear()
	pinch_distance = 0.0

func _cancel_stroke() -> void:
	pointer_down = false
	pointer_ui = false
	dragging = false
	road_path.clear()
	if build_kind == "road":
		world.set_road_preview(road_path)
		hud.set_mode("Estradas · arraste ou clique · 1 pedra por trecho · Esc termina")

func _focus_map(cell: Vector2i) -> void:
	_cancel_stroke()
	world.focus_cell(cell)

func _highlight_entrance(cell: Vector2i) -> void:
	selected_id = -1
	if cell.x >= 0:
		for building in sim.buildings:
			if building.entrance == cell and building.stage != "cancelled":
				selected_id = int(building.id)
				break
	world.set_selected(selected_id)

func _input(event: InputEvent) -> void:
	if sim == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_select_build("")
				hud.close_panels()
			KEY_SPACE: _command("pause",{})
			KEY_1: hud._choose_speed(1)
			KEY_2: hud._choose_speed(2)
			KEY_4: hud._choose_speed(4)
			KEY_F5: _save()
			KEY_F9: _load_save()
			KEY_HOME: _focus_map(Vector2i(7,12))
			KEY_R: _select_build("road")
			KEY_Q, KEY_E:
				_cancel_stroke()
				world.orbit(-PI/6 if event.keycode == KEY_Q else PI/6)
			KEY_M:
				mute = not mute
				hud.show_message("Sons desativados" if mute else "Sons ativados")
			KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D, KEY_UP, KEY_W, KEY_DOWN, KEY_S:
				_cancel_stroke()
				if event.keycode in [KEY_LEFT,KEY_A]: world.pan_by(Vector2(65,0))
				elif event.keycode in [KEY_RIGHT,KEY_D]: world.pan_by(Vector2(-65,0))
				elif event.keycode in [KEY_UP,KEY_W]: world.pan_by(Vector2(0,65))
				else: world.pan_by(Vector2(0,-65))
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed and not hud.blocks_pointer(event.position):
			_cancel_stroke()
			world.zoom_by(-2.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 2.0)
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_cancel_stroke()
				pan_pointer_ui = hud.blocks_pointer(event.position)
			pan_pointer_down = event.pressed
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if pan_pointer_down or touch_points.size() >= 2:
					return
				pointer_down = true
				dragging = false
				drag_start = event.position
				pointer_ui = hud.blocks_pointer(event.position)
				if build_kind == "road" and not pointer_ui:
					road_path.clear()
					_extend_road(world.screen_to_cell(event.position))
			else:
				if pointer_down and build_kind == "road":
					var cell: Vector2i = world.screen_to_cell(event.position)
					if not pointer_ui and not hud.blocks_pointer(event.position) and cell.x >= 0 and cell.y >= 0 and not road_path.is_empty():
						_extend_road(cell)
						_command("road",{"cells":road_path.duplicate()})
					_cancel_stroke()
				elif pointer_down and not dragging and not pointer_ui and not hud.blocks_pointer(event.position):
					_world_click(event.position)
				pointer_down = false
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_select_build("")
	if event is InputEventMouseMotion:
		if pan_pointer_down:
			if not pan_pointer_ui and not hud.blocks_pointer(event.position):
				world.pan_by(event.relative)
			return
		if build_kind == "road":
			if not hud.blocks_pointer(event.position):
				if pointer_down and not pointer_ui:
					_extend_road(world.screen_to_cell(event.position))
				elif not pointer_down:
					var cells: Array[Vector2i] = [world.screen_to_cell(event.position)]
					world.set_road_preview(cells)
			return
		if pointer_down and not pointer_ui:
			if event.position.distance_to(drag_start) > 8.0:
				dragging = true
			if dragging and not hud.blocks_pointer(event.position):
				world.pan_by(event.relative)
		if not build_kind.is_empty() and not hud.blocks_pointer(event.position):
			hover_cell = world.screen_to_cell(event.position)
			world.set_preview(build_kind,hover_cell,sim.can_place(build_kind,hover_cell).is_empty())
	if event is InputEventMagnifyGesture and not hud.blocks_pointer(event.position):
		_cancel_stroke()
		world.zoom_by((1.0-event.factor)*20.0)
	if event is InputEventPanGesture and not hud.blocks_pointer(event.position):
		_cancel_stroke()
		world.pan_by(-event.delta*12.0)
	# Touch -> mouse emulation supplies tap/drag; a second finger cancels placement.
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
			if touch_points.size() >= 2:
				_cancel_stroke()
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
	var data := {"format":"vale-frontier-v1","simulation":sim.snapshot(),"clock":clock.capture(),"speed":speed}
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
	_load_paths([SAVE_PATH,SAVE_PATH+".bak","user://vale-frontier-autosave-v1.json"])

func _load_paths(paths: Array) -> bool:
	for path in paths:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path,FileAccess.READ)
		if file == null or file.get_length()>4000000:
			continue
		var data: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if not data is Dictionary or data.get("format") != "vale-frontier-v1" or not data.get("simulation") is Dictionary or not data.get("clock") is Dictionary:
			continue
		var new_clock := Clock.new(100000)
		if new_clock.restore(data.clock) != OK:
			continue
		if sim.restore(data.simulation):
			clock = new_clock
			var saved_speed: Variant = data.get("speed",1)
			speed = int(saved_speed) if typeof(saved_speed) in [TYPE_INT,TYPE_FLOAT] and saved_speed in [1,2,4] else 1
			_clear_world()
			hud.show_message("Partida recuperada. Nada avançou enquanto esteve fechada.")
			return true
	hud.show_message("Não há uma partida salva válida neste dispositivo.")
	return false

func _clear_world() -> void:
	since_refresh = 0.0
	since_autosave = 0.0
	event_signature = ""
	_select_build("")
	selected_id = -1
	world.queue_free()
	world = World.new()
	add_child(world)
	world.setup(sim)
	hud.close_panels()
	hud.inspect({})
	hud._choose_speed(speed)
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
			_write_save("user://vale-frontier-autosave-v1.json")
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		application_paused = false
	elif what == NOTIFICATION_WM_CLOSE_REQUEST and sim != null:
		_write_save("user://vale-frontier-autosave-v1.json")

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

func _extend_road(cell:Vector2i) -> void:
	if cell.x < 1 or cell.y < 1 or cell.x >= Village.WIDTH-1 or cell.y >= Village.HEIGHT-1: return
	if road_path.is_empty():
		road_path.append(cell)
	else:
		var last:Vector2i=road_path.back()
		# Fill skipped mouse samples with an orthogonal, continuous road stroke.
		while last!=cell and road_path.size()<200:
			if absi(last.x-cell.x)>=absi(last.y-cell.y):last.x+=signi(cell.x-last.x)
			else:last.y+=signi(cell.y-last.y)
			if not road_path.has(last):road_path.append(last)
	world.set_road_preview(road_path)
	var cost:=0
	for tile in road_path:
		if sim.road_at(tile).is_empty() and sim.can_place_road(tile).is_empty():cost+=1
	hud.set_mode("Estradas · %d trechos · %d pedra · solte para construir · Esc termina" % [road_path.size(),cost])
