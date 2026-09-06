extends SceneTree
const People=preload("res://presentation/approved_people.gd")
const Terrain=preload("res://presentation/approved_terrain.gd")
const Sim=preload("res://simulation/approved_sim.gd")
func _initialize():call_deferred("run")
func run():
	var sim:=Sim.new();sim.setup()
	var terrain:=Terrain.new();root.add_child(terrain);terrain.setup(sim)
	var people: Array[Node3D]=[]
	for i in range(48):
		var person:=People.create(People.APPROVED[i%8],i,1);root.add_child(person);person.set_meta("ground_height",Callable(terrain,"support_height"));people.append(person)
	var samples: Array[float]=[]
	for frame in range(480):
		var start:=Time.get_ticks_usec()
		for i in range(people.size()):
			var person:=people[i];person.position=Vector3(25.0+float(i%8)*1.2,0.002,45.0-float(frame)*5.0/60.0)
			var loaded:=i%3==0;var gain:=6.8 if loaded else 5.6
			People.animate(person,float(frame)*5.0/60.0*gain+float(i)*0.21,true,false,loaded,"wood")
		if frame>=120:samples.append(float(Time.get_ticks_usec()-start)/1000.0)
	samples.sort();var sum:=0.0
	for sample in samples:sum+=sample
	print("GAIT_CPU_48 mean_ms=",sum/samples.size()," p95_ms=",samples[int(samples.size()*0.95)]," max_ms=",samples[-1])
	quit()
