extends SceneTree
const Sim = preload("res://simulation/approved_sim.gd")
const Status = preload("res://ui/village_status.gd")
const HUD = preload("res://ui/approved_hud.gd")
var failures: Array[String] = []
var checks := 0
var focused := Vector2i(-1,-1)
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)
func has_reason(rows: Array[Dictionary], reason: String) -> bool:
	for row in rows:
		if row.reason == reason: return true
	return false
func frames() -> void:
	for i in range(8): await process_frame
func run() -> void:
	var sim := Sim.new()
	sim.setup()
	var rows := Status.collect(sim)
	expect(has_reason(rows, "Conecte a entrada à estrada do edifício principal"), "disconnected school is reported globally")
	sim.command("road", {"cells":[Vector2i(9,13),Vector2i(10,13),Vector2i(11,13),Vector2i(12,13),Vector2i(13,13)]})
	for i in range(900): sim.step()
	expect(not has_reason(Status.collect(sim), "Conecte a entrada à estrada do edifício principal"), "resolved connection disappears")
	var school: Dictionary = sim.buildings[1]
	school.worker = -1
	expect(has_reason(Status.collect(sim), "Forme um instrutor"), "missing professional is actionable")
	school.worker = sim.workers[8].id
	for person in [sim.workers[0], sim.workers[1]]:
		person.state = "Aguardando retirada da produção"
	rows = Status.collect(sim)
	var group: Dictionary = {}
	for row in rows:
		if row.reason == "Aguardando retirada da produção": group = row
	expect(group.get("cells", []).size() == 2, "same waits are grouped with both locations")
	sim.training.append({"role":"builder","reason":"Aguardando ouro na escola","building":school.id})
	expect(has_reason(Status.collect(sim), "Aguardando ouro na escola"), "blocked training is shown")
	sim.training[0].reason = "Formando construtor"
	expect(not has_reason(Status.collect(sim), "Formando construtor"), "active training is not a warning")
	sim.training.clear()
	var before := str(sim.snapshot())
	Status.collect(sim)
	expect(str(sim.snapshot()) == before, "collecting status never mutates simulation")
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280,800)
	var hud := HUD.new()
	root.add_child(hud)
	hud.setup(sim)
	hud._dismiss_tutorial()
	hud.focus_requested.connect(func(cell): focused = cell)
	await frames()
	expect(hud._status_panel.visible, "global panel appears without inspection")
	hud._focus_status(group)
	expect(focused == group.cells[0], "warning focuses first affected location")
	hud._focus_status(group)
	expect(focused == group.cells[1], "repeated click cycles grouped locations")
	for resolution in [Vector2i(800,600),Vector2i(980,650),Vector2i(1440,900)]:
		root.size = resolution
		await frames()
		hud._layout()
		await frames()
		expect(Rect2(Vector2.ZERO,Vector2(resolution)).encloses(hud._status_panel.get_global_rect()), "status fits " + str(resolution))
		expect(hud.blocks_pointer(hud._status_panel.position + Vector2(20,20)), "status consumes map clicks")
	for person in [sim.workers[0],sim.workers[1]]: person.state = "Na praça"
	hud.refresh()
	expect(not has_reason(hud._status_groups, "Aguardando retirada da produção"), "resolved wait is removed from UI")
	hud.queue_free()
	await frames()
	print("VILLAGE_STATUS_RESULT checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)
