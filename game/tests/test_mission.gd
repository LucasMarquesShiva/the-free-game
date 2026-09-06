extends SceneTree
const Village = preload("res://simulation/village_sim.gd")
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ",label)
func run() -> void:
	var s := Village.new()
	s.setup()
	for plan in [["house",Vector2i(13,3)],["house",Vector2i(16,3)],["farm",Vector2i(13,19)],["vineyard",Vector2i(16,19)],["winery",Vector2i(18,7)],["barracks",Vector2i(17,23)]]:
		var result: Dictionary = s.command("build",{"kind":plan[0],"cell":plan[1]})
		expect(result.ok,"mission places "+plan[0]+": "+result.message)
	s.command("train",{"role":"servant","quantity":3})
	var order: Dictionary = s.command("army",{"order":"attack","target":Vector2i(30,14)})
	expect(order.ok,"collective attack accepted")
	var start := Time.get_ticks_msec()
	var completed_tick := 0
	var maximum_wait := 0
	var invariant_failures := []
	for i in range(18000):
		s.step()
		if s.won and completed_tick==0:
			completed_tick=s.tick
		if i % 100 == 0:
			for err in s.conservation_errors():
				if not invariant_failures.has(err): invariant_failures.append(err)
			for w in s.workers:
				maximum_wait=maxi(maximum_wait,int(w.wait))
				for u in s.battle.units:
					if u.hp>0 and u.cell==w.cell and not invariant_failures.has("cross-team overlap"):
						invariant_failures.append("cross-team overlap")
	expect(completed_tick>0,"full mission reaches victory using legal construction, training and collective command")
	expect(s.battle.captured,"actual enemy camp captured")
	expect(int(s.stats.wine_delivered)>=12 and int(s.stats.food_produced)>0,"ongoing food and winery chains complete mission")
	expect(invariant_failures.is_empty(),"30 simulation minutes preserve resources and disjoint physical actor positions: "+str(invariant_failures))
	expect(int(s.stock.food)>0,"village sustains food after 30 simulation minutes")
	expect(maximum_wait<100,"traffic recovers without long-lived deadlocks")
	var recruited: Dictionary = s.command("recruit",{"role":"lancer"})
	expect(recruited.ok,"completed barracks recruits an equipped resident into army")
	expect(s.conservation_errors().is_empty(),"recruitment consumes food/equipment exactly once")
	var result := {"checks":checks,"failures":failures,"victory_tick":completed_tick,"duration_ticks":s.tick,"wall_ms":Time.get_ticks_msec()-start,"max_civil_wait_moves":maximum_wait,"stock":s.stock,"stats":s.stats,"battle_status":s.battle.status}
	print("MISSION_RESULT ",JSON.stringify(result))
	var f := FileAccess.open("user://vale-mission-result.json",FileAccess.WRITE)
	if f != null: f.store_string(JSON.stringify(result,"  ")); f.close()
	if failures.is_empty():
		print("PASS: ",checks," integrated mission checks")
		quit(0)
	else:
		for b in s.buildings: print("BUILDING ",b.kind," ",b.cell," ",b.stage," ",b.reason)
		quit(1)
