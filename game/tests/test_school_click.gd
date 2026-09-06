extends SceneTree
const Sim=preload('res://simulation/approved_sim.gd')
const Game=preload('res://presentation/approved_game.gd')
const Hud=preload('res://ui/approved_hud.gd')
class MapDouble extends Node3D:
	var cell:=Vector2i(12,10)
	var target:Dictionary={}
	var selected:=-1
	var pan_total:=Vector2.ZERO
	func screen_to_cell(_point:Vector2)->Vector2i:return cell
	func building_at_screen(_point:Vector2)->Dictionary:return target
	func set_selected(id:int)->void:selected=id
	func clear_preview()->void:pass
	func set_road_preview(_cells:Array)->void:pass
	func set_road_removal_preview(_cell:Vector2i)->void:pass
	func pan_by(amount:Vector2)->void:pan_total+=amount
var failures:Array[String]=[]
var checks:=0
func expect(ok:bool,description:String)->void:
	checks+=1
	if not ok:failures.append(description);printerr('FAIL ',description)
func frames(n:int=5)->void:
	for i in range(n):await process_frame
func mouse(game:Node,point:Vector2,pressed:bool)->void:
	var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;game._input(event)
func _initialize()->void:call_deferred('run')
func run()->void:
	root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1280,800)
	var sim:=Sim.new();sim.setup()
	var hud:=Hud.new();root.add_child(hud);hud.setup(sim)
	# The actual controller and HUD use a lightweight map hit-test substitute;
	# simulation commands, queue and autonomous work remain the real code.
	var game:=Game.new();var map:=MapDouble.new();game.sim=sim;game.hud=hud;game.world=map
	hud.command_requested.connect(game._command);hud.build_selected.connect(game._select_build);hud.entrance_highlighted.connect(game._highlight_entrance)
	var school:Dictionary=sim.buildings[1];map.target=school;map.cell=school.cell
	await frames(8)
	mouse(game,Vector2(1000,330),true);mouse(game,Vector2(1000,330),false)
	expect(hud._drawer.visible and hud._drawer_kind=='training' and not hud._inspector.visible,'completed school click opens training')
	expect(hud._training_school_id==school.id and map.selected==school.id,'clicked school stays highlighted')
	expect(hud._training_context.text.contains('Falta uma estrada') and hud._training_context.text.contains('escolas disponíveis'),'unconnected school explains connection and shared queue')
	game._world_click(Vector2(1000,330));expect(hud._drawer.visible,'repeated school click keeps formation open')
	hud._set_quantity(3);expect(hud._training_school_id==school.id and hud._quantity==3,'quantity change keeps school context')
	hud._train_role('farmer');expect(sim.training.size()==3,'school button adds profession quantity to autonomous queue')
	sim.step();hud.refresh();expect(hud._role_count_labels.farmer.text.begins_with('Horticultor'),'profession uses current horticultor name')
	hud.show_message('Agricultor formado.');expect(hud._toast_label.text=='Horticultor formado.','legacy profession notice matches current UI')
	for request:Dictionary in sim.training.duplicate():sim.command('cancel_training',{'id':request.id})
	hud.close_panels()
	map.target=sim.buildings[0];map.cell=map.target.cell;game._world_click(Vector2(1000,330))
	expect(hud._inspector.visible and not hud._drawer.visible,'other completed buildings retain inspection')
	map.target=school;map.cell=school.cell;game._select_build('house');game._world_click(Vector2(1000,330))
	expect(game.build_kind=='house' and not hud._drawer.visible,'building placement has priority over school hit')
	game._select_build('road');map.cell=Vector2i(14,13);game._world_click(Vector2(1000,330))
	expect(not sim.road_at(map.cell).is_empty() and not hud._drawer.visible,'road placement has priority and still creates real road command')
	game._select_build('remove_road');game._world_click(Vector2(1000,330))
	expect(sim.road_at(map.cell).is_empty() and not hud._drawer.visible,'road removal has priority over school hit')
	game._select_build('');map.cell=school.cell;hud.close_panels()
	mouse(game,Vector2(1000,330),true)
	var motion:=InputEventMouseMotion.new();motion.position=Vector2(1020,330);motion.relative=Vector2(20,0);game._input(motion)
	mouse(game,Vector2(1020,330),false)
	expect(map.pan_total.x>0 and not hud._drawer.visible,'drag pans instead of opening school')
	var road_result:Dictionary=sim.command('road',{'cells':[Vector2i(10,13),Vector2i(11,13),Vector2i(12,13),Vector2i(13,13)]})
	expect(road_result.ok,'road starts outside initial plaza')
	for i in range(900):sim.step()
	game._world_click(Vector2(1000,330));hud.refresh()
	expect(sim.is_building_connected(school) and hud._training_context.text.contains('conectada ao principal'),'school context refreshes after legal road completion')
	hud._set_quantity(1);hud._train_role('farmer')
	for i in range(700):sim.step()
	hud.refresh();expect(int(sim.profession_counts().get('farmer',0))>=1,'formation completes autonomously from school UI')
	var result:Dictionary=sim.command('build',{'kind':'training','cell':Vector2i(18,17)})
	expect(result.ok,'unfinished school fixture is a legal queued building')
	var unfinished:Dictionary=sim.buildings.back();map.target=unfinished;map.cell=unfinished.cell;game._world_click(Vector2(1000,330))
	expect(hud._inspector.visible and not hud._drawer.visible,'unfinished school keeps construction inspection')
	expect(hud._inspection_details.text.contains('Madeira: 0 / 10') and hud._inspection_details.text.contains('Pedra: 0 / 6') and hud._inspection_details.text.contains('entregues / necessários'),'construction shows actual required materials explicitly')
	expect(hud._inspection_details.text.contains('estrada concluída'),'disconnected construction explains delivery requirement')
	# A known construction state verifies consumed stock is never mislabeled
	# as missing materials; this fixture is read-only presentation input.
	var applying:Dictionary=unfinished.duplicate(true);applying.stage='building';applying.delivered={'wood':0,'stone':0}
	var lines:Array=hud._construction_material_lines(applying,sim.definition('training'),true)
	expect('Madeira: 10 / 10' in lines and 'Já entregues e aplicados na obra.' in lines,'materials consumed by construction still count as delivered')
	for resolution:Vector2i in [Vector2i(1280,800),Vector2i(844,390)]:
		root.size=resolution;await frames(8);hud.inspect(unfinished);await frames(8)
		var bounds:=Rect2(Vector2.ZERO,Vector2(resolution));expect(bounds.encloses(hud._inspector.get_global_rect()),'construction inspector fits '+str(resolution))
		expect(hud._inspection_cancel.is_visible_in_tree() and bounds.encloses(hud._inspection_cancel.get_global_rect()),'cancel construction stays reachable '+str(resolution))
		hud.open_training(school);await frames(8)
		expect(bounds.encloses(hud._drawer.get_global_rect()),'school training drawer fits '+str(resolution))
		if resolution.y<520:expect(hud._drawer_scroll.get_v_scroll_bar().visible,'compact school content can scroll')
		hud.close_panels()
	await check_material_delivery(hud)
	hud._sim=sim
	expect(sim.definition('house').cost=={'wood':4,'stone':2},'house cost remains four wood and two stone')
	print('SCHOOL_RESOURCE_AUDIT ',sim.conservation_errors());expect(sim.conservation_errors().is_empty(),'legal school and road interactions preserve resources')
	game.free();map.free();hud.queue_free();await frames(2)
	print('SCHOOL_CLICK_RESULT checks=',checks,' failures=',failures)
	quit(0 if failures.is_empty() else 1)

func check_material_delivery(hud:CanvasLayer)->void:
	var sim:=Sim.new();sim.setup();hud._sim=sim
	var build:Dictionary=sim.command('build',{'kind':'house','cell':Vector2i(16,16)})
	expect(build.ok,'house material fixture is a legal build command')
	var house:Dictionary=sim.buildings.back();var cells:Array[Vector2i]=[]
	for x in range(10,19):cells.append(Vector2i(x,15))
	for y in range(16,19):cells.append(Vector2i(18,y))
	var connection:=Vector2i(18,18)
	while connection!=house.entrance:
		connection.x+=signi(house.entrance.x-connection.x)
		cells.append(connection)
	expect(sim.command('road',{'cells':cells}).ok,'house deliveries use legal roads from the plaza')
	var observed_cargo:=false;var observed_application:=false
	for i in range(2400):
		sim.step()
		if not observed_cargo:
			for person:Dictionary in sim.workers:
				if person.task.get('type')=='delivery' and person.task.get('building')==house.id and not person.cargo.is_empty():
					hud.inspect(house)
					observed_cargo=hud._inspection_details.text.contains('Nas mãos dos serventes:')
		if house.stage=='building':
			hud.inspect(house)
			observed_application=hud._inspection_details.text.contains('Madeira: 4 / 4') and hud._inspection_details.text.contains('Pedra: 2 / 2') and hud._inspection_details.text.contains('aplicados')
			break
	if not observed_cargo or not observed_application:
		print('MATERIAL_DIAG tick=',sim.tick,' house_stage=',house.stage,' entrance=',house.entrance,' reason=',house.reason)
	expect(observed_cargo,'inspector reports actual servant cargo destined for the house')
	expect(observed_application,'real autonomous construction shows materials delivered and applied')
	expect(sim.conservation_errors().is_empty(),'material inspector does not change simulation resources')
	await frames(1)
