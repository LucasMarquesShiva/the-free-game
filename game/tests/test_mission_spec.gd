extends SceneTree
const Approved = preload("res://simulation/approved_sim.gd")
const Spec = preload("res://simulation/mission_spec.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)


func run() -> void:
	var spec: RefCounted = Spec.load_id("tsk-01")
	expect(spec != null and spec.id == "tsk-01", "tsk-01 loads from res://content/missions")
	expect(spec.allows_building("lumber") and spec.allows_building("quarry"), "wood and stone huts stay available")
	expect(spec.allows_building("training") and spec.allows_building("inn"), "school and inn stay available")
	expect(not spec.allows_building("farm") and not spec.allows_building("vineyard") and not spec.allows_building("winery"), "sandbox wine chain stays locked")
	expect(spec.allows_role("lumberjack") and not spec.allows_role("vintner") and not spec.allows_role("farmer"), "only wood/stone professions train")
	expect(spec.objectives_met({"training":1,"inn":1,"lumber":1,"quarry":1}), "four teaching buildings win")
	expect(not spec.objectives_met({"house":2,"farm":1}), "sandbox wine/house checklist does not win")

	var sandbox := Approved.new()
	sandbox.setup()
	expect(sandbox.command("build", {"kind":"farm","cell":Vector2i(16,19)}).ok, "default sandbox still places a farm")

	var sim := Approved.new()
	sim.setup()
	sim.mission = spec
	expect(not sim.command("build", {"kind":"farm","cell":Vector2i(16,19)}).ok, "tsk-01 rejects farm")
	expect(not sim.command("build", {"kind":"winery","cell":Vector2i(18,17)}).ok, "tsk-01 rejects winery")
	var lumber: Dictionary = sim.command("build", {"kind":"lumber","cell":Vector2i(3,18)})
	expect(lumber.ok, "tsk-01 still places a woodcutter: " + str(lumber.message))
	expect(not sim.command("train", {"role":"vintner"}).ok, "tsk-01 rejects vintner training")
	expect(sim.command("train", {"role":"lumberjack"}).ok, "tsk-01 still queues a lumberjack")

	print("MISSION_SPEC_RESULT checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)
