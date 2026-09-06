extends SceneTree
const Village = preload("res://simulation/village_sim.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: "+message)

func advance(sim: RefCounted, ticks: int) -> void:
	for i in range(ticks):
		sim.step()

func until(sim: RefCounted, predicate: Callable, max_ticks: int = 6000) -> bool:
	for i in range(max_ticks):
		if predicate.call():
			return true
		sim.step()
	return predicate.call()

func fresh() -> RefCounted:
	var sim := Village.new()
	sim.setup()
	return sim

func build(sim: RefCounted, kind: String, cell: Vector2i) -> Dictionary:
	var result: Dictionary = sim.command("build",{"kind":kind,"cell":cell})
	expect(result.ok,"placement "+kind+": "+result.message)
	return sim.buildings.back()

func run() -> void:
	var sim := fresh()
	expect(sim.conservation_errors().is_empty(),"initial inventories and positions valid")
	expect(not sim.command("move_civil",{"id":7,"cell":Vector2i(8,8)}).ok,"individual civilian orders rejected")
	expect(not sim.command("build",{"kind":"house","cell":Vector2i(22,12)}).ok,"river placement rejected")
	expect(not sim.command("build",{"kind":"house","cell":Vector2i(8,10)}).ok,"occupied placement rejected")
	var house := build(sim,"house",Vector2i(13,3))
	expect(until(sim,func(): return house.stage == "complete",3000),"autonomous first house finishes")
	expect(int(sim.stats.houses_built)==1,"house expands mission progress once")
	expect(sim.conservation_errors().is_empty(),"resources conserved through transport and consumption")

	var queued := build(sim,"house",Vector2i(16,3))
	var queued2 := build(sim,"house",Vector2i(18,6))
	expect(until(sim,func(): return queued.stage == "complete" and queued2.stage == "complete",4000),"multiple works progress without manual assignments")
	expect(sim.conservation_errors().is_empty(),"parallel deliveries preserve stock and exclusive positions")

	var trainee_count: int = sim.profession_counts().servant
	expect(sim.command("train",{"role":"servant","quantity":2}).ok,"profession queue accepts quantities")
	expect(until(sim,func(): return sim.profession_counts().servant==trainee_count+2,1800),"residents walk to training and join profession automatically")
	var cancel := build(sim,"winery",Vector2i(14,19))
	advance(sim,200)
	expect(sim.command("cancel",{"id":cancel.id}).ok,"active construction can be cancelled")
	advance(sim,1800)
	expect(sim.conservation_errors().is_empty(),"cancellation returns physical materials without duplication")

	# JSON round trip while work and training are active.
	build(sim,"farm",Vector2i(15,7))
	sim.command("train",{"role":"farmer"})
	advance(sim,140)
	var record: Dictionary = JSON.parse_string(JSON.stringify(sim.snapshot()))
	var restored := fresh()
	expect(restored.restore(record),"full village and battle save restores through JSON")
	expect(JSON.parse_string(JSON.stringify(sim.snapshot()))==JSON.parse_string(JSON.stringify(restored.snapshot())),"restored state includes positions, queues, production and cargo")
	advance(sim,600)
	advance(restored,600)
	expect(JSON.parse_string(JSON.stringify(sim.snapshot()))==JSON.parse_string(JSON.stringify(restored.snapshot())),"continued saved simulation reproduces uninterrupted simulation")
	var before: String = JSON.stringify(restored.snapshot())
	var invalid := record.duplicate(true)
	invalid.stock.wood = -4
	expect(not restored.restore(invalid) and JSON.stringify(restored.snapshot())==before,"bad save rejected without altering game")
	restored.command("pause")
	var paused: String = JSON.stringify(restored.snapshot())
	advance(restored,100)
	expect(JSON.stringify(restored.snapshot())==paused,"pause freezes simulation including combat and queues")

	# Independent production mission, including real grapes -> wine chain.
	var economy := fresh()
	var farm := build(economy,"farm",Vector2i(13,3))
	var vines := build(economy,"vineyard",Vector2i(16,3))
	var winery := build(economy,"winery",Vector2i(16,7))
	economy.command("train",{"role":"servant","quantity":3})
	expect(until(economy,func(): return int(economy.stats.wine_delivered)>=12,12000),"grapes physically supply winery and 12 wines reach storage")
	expect(farm.stage=="complete" and vines.stage=="complete" and winery.stage=="complete","production buildings complete autonomously")
	expect(int(economy.stats.food_produced)>0,"food chain replenishes consumed meals")
	expect(economy.conservation_errors().is_empty(),"all five resource types conserved through production chain")
	print("ECONOMY tick=",economy.tick," stock=",economy.stock," stats=",economy.stats)
	if failures.is_empty():
		print("PASS: ",checks," functional village checks")
		quit(0)
	else:
		print("FAILURES: ",failures)
		print("WORKERS: ",economy.workers)
		quit(1)
