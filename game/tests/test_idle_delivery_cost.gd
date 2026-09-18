extends SceneTree
## Count expensive scans instead of asserting machine-dependent timing.
class CountingSim extends "res://simulation/approved_sim.gd":
	var scans := 0
	func _incoming(id: int, item: String) -> int:
		scans += 1
		return super._incoming(id,item)
	func _outgoing(id: int, item: String) -> int:
		scans += 1
		return super._outgoing(id,item)
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message);printerr("FAIL ",message)
func run() -> void:
	var sim := CountingSim.new()
	sim.setup()
	var courier: Dictionary = sim.workers[3]
	courier.cell = sim.HUB
	courier.goal = sim.HUB
	for i in range(6):
		var empty: Dictionary = sim.buildings[1].duplicate(true)
		empty.id = 1000+i
		sim.buildings.append(empty)
	sim.scans = 0
	for i in range(16): expect(not sim._assign_export(courier), "empty producers offer no exports")
	expect(sim.scans <= 64, "empty outputs do not scan worker reservations per building/item: " + str(sim.scans))
	# Saturated stock also needs no per-output reservation scans.
	sim.buildings[0].output.wood = 4
	sim.scans = 0
	expect(not sim._assign_export(courier), "stock at target leaves output in place")
	expect(sim.scans <= 4, "satisfied stock short-circuits scans")
	# A real output must still be assigned, then reserved against duplicates.
	sim.stock.wood = 0
	sim.buildings[0].output.wood = 2
	expect(sim._assign_export(courier), "available output still creates delivery")
	expect(courier.task.item == "wood" and courier.task.amount == 2, "delivery keeps resource and amount")
	var second: Dictionary = sim.workers[4]
	second.cell = sim.HUB
	expect(not sim._assign_export(second), "already assigned output is not double-booked")
	# Cancelled construction salvage remains eligible.
	courier.task = {}
	sim.buildings[0].output.wood = 0
	var cancelled: Dictionary = sim.buildings[1]
	cancelled.stage = "cancelled"
	cancelled.entrance = sim.HUB
	cancelled.output.stone = 2
	expect(sim._assign_export(courier), "cancelled materials can still be recovered")
	expect(courier.task.item == "stone", "salvage retains material type")
	print("IDLE_DELIVERY_COST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
