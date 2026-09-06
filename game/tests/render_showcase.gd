extends SceneTree
## Builds a real settlement with public commands, then photographs its live state.
## Headless validates preparation; native rendering also writes the PNG.

const OUTPUT_PATH := "user://vale-vila-pronta.png"
const REPORT_PATH := "user://vale-showcase-result.json"
const MAX_TICKS := 18000

var game: Node
var failures: Array[String] = []
var orders: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func _command(kind: String, payload: Dictionary) -> bool:
	var result: Dictionary = game.sim.command(kind, payload)
	orders.append({"kind": kind, "payload": str(payload), "ok": result.ok, "message": result.message})
	if not bool(result.ok):
		failures.append("%s: %s" % [kind, result.message])
	return bool(result.ok)

func _settlement_ready() -> bool:
	if game.sim.lost:
		return false
	for building: Dictionary in game.sim.buildings:
		if building.stage != "complete":
			return false
	return game.sim.training.is_empty() and int(game.sim.stats.wine_delivered) >= 12 and int(game.sim.stats.food_produced) >= 16

func _cargo_score() -> int:
	var score: int = 0
	for worker: Dictionary in game.sim.workers:
		var cargo: Dictionary = worker.get("cargo", {})
		if int(cargo.get("amount", 0)) <= 0:
			continue
		score += 2
		if str(cargo.get("item", "")) == "wine":
			score += 5
	return score

func run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	# Prevent wall-clock ticks and autosaves while this harness advances legal steps.
	game.set_process(false)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	var plans: Array = [
		["house", Vector2i(13, 3)],
		["house", Vector2i(16, 3)],
		["farm", Vector2i(13, 16)],
		["vineyard", Vector2i(16, 17)],
		["winery", Vector2i(14, 6)],
		["barracks", Vector2i(18, 20)],
	]
	for plan: Array in plans:
		_command("build", {"kind": plan[0], "cell": plan[1]})
	_command("train", {"role": "servant", "quantity": 3})
	_command("army", {"order": "defend", "target": Vector2i(18, 13)})
	if not failures.is_empty():
		_finish(false, 0)
		return
	var ready_tick: int = -1
	var score: int = 0
	for index in range(MAX_TICKS):
		game.sim.step()
		if game.sim.lost:
			failures.append("A vila entrou em derrota durante a preparação.")
			break
		if _settlement_ready():
			if ready_tick < 0:
				ready_tick = int(game.sim.tick)
			score = _cargo_score()
			# Keep a naturally occurring busy moment, rather than repositioning actors.
			if score >= 11 or int(game.sim.tick) - ready_tick >= 1000:
				break
	if ready_tick < 0:
		failures.append("As seis obras, o treinamento e a produção não concluíram dentro do limite.")
	for error: String in game.sim.conservation_errors():
		failures.append(error)
	if not failures.is_empty():
		_finish(false, score)
		return
	_command("pause", {})
	game.world.focus_cell(Vector2i(12, 11))
	game.world.camera.size = 38.0
	game.world.set_selected(-1)
	game.world.clear_preview()
	# Settle interpolation and render the paused, legally reached state.
	game.world.sync(1.0)
	game.hud.close_panels()
	game.hud.refresh()
	game.hud.show_message("Vila em atividade: alimentos, uvas e vinho produzidos e transportados automaticamente.")
	if DisplayServer.get_name() == "headless":
		print("SHOWCASE_PREPARED_HEADLESS: execute este mesmo script sem --headless para gravar o PNG.")
		_finish(false, score)
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(OUTPUT_PATH)
	if error != OK:
		failures.append("Falha ao salvar PNG: %s" % error_string(error))
	_finish(error == OK, score)

func _finish(captured: bool, score: int) -> void:
	var buildings: Array[Dictionary] = []
	for building: Dictionary in game.sim.buildings:
		buildings.append({"kind": building.kind, "cell": str(building.cell), "stage": building.stage, "reason": building.reason})
	var result: Dictionary = {
		"ok": failures.is_empty(), "captured": captured,
		"output": OUTPUT_PATH if captured else "", "tick": game.sim.tick,
		"paused": game.sim.paused, "cargo_score": score,
		"stock": game.sim.stock, "stats": game.sim.stats,
		"population": game.sim.workers.size(), "buildings": buildings,
		"orders": orders, "failures": failures,
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "  "))
		file.close()
	print("SHOWCASE_RESULT ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
