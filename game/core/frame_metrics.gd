extends RefCounted
## CPU timings of game work, not GPU timers. Constant-size aggregates per interval.
var elapsed := 0.0
var frames := 0
var totals: Dictionary = {}
var peaks: Dictionary = {}
var calls: Dictionary = {}
func record(section: String, start_usec: int) -> void:
	var milliseconds := float(Time.get_ticks_usec()-start_usec)/1000.0
	totals[section] = float(totals.get(section,0.0))+milliseconds
	peaks[section] = maxf(float(peaks.get(section,0.0)),milliseconds)
	calls[section] = int(calls.get(section,0))+1
func finish(delta: float, sim: RefCounted, speed: int) -> void:
	elapsed += delta
	frames += 1
	if elapsed < 10.0: return
	var sections: Dictionary = {}
	for section in totals:
		sections[section] = {"avg_ms":snappedf(float(totals[section])/int(calls[section]),0.01),"max_ms":snappedf(float(peaks[section]),0.01),"calls":calls[section]}
	print("FRAME_PROFILE ",JSON.stringify({"fps":Engine.get_frames_per_second(),"workers":sim.workers.size(),"roads":sim.roads.size(),"speed":speed,"frames":frames,"cpu":sections,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}))
	elapsed=0.0;frames=0;totals.clear();peaks.clear();calls.clear()
