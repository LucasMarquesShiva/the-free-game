extends SceneTree
const Frontier = preload("res://simulation/approved_sim.gd")
const HUD = preload("res://ui/approved_hud.gd")
var checks := 0
var failures: Array[String] = []
var selected := ""
var highlighted := Vector2i(-1,-1)
func _initialize() -> void: call_deferred("run")
func expect(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures.append(message)
  printerr("FAIL: ",message)
func frames(count: int = 4) -> void:
 for index in range(count): await process_frame
func run() -> void:
 root.content_scale_size = Vector2i.ZERO
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
 root.size = Vector2i(1280,800)
 var sim := Frontier.new()
 sim.setup()
 var hud := HUD.new()
 root.add_child(hud)
 hud.setup(sim)
 hud.build_selected.connect(func(kind): selected = kind)
 hud.entrance_highlighted.connect(func(cell): highlighted = cell)
 hud.command_requested.connect(func(kind,payload): sim.command(kind,payload))
 await frames(10)
 expect(hud._tabs.has("road") and hud._tabs.road.visible,"road control is a primary dock action")
 expect(hud._definition("hall").name == "Prédio principal" and hud._definition("training").name == "Escola de instrutores","initial building names match frontier tutorial")
 hud._tabs.road.pressed.emit()
 expect(selected == "road" and hud._mode_panel.visible and hud._mode_label.text.contains("1 pedra"),"road button emits placement mode and displays finite stone cost")
 hud._cancel_mode()
 expect(selected.is_empty() and not hud._mode_panel.visible,"cancel exits placement mode")
 hud.inspect(sim.buildings[1])
 expect(highlighted == Vector2i(13,13) and hud._inspection_connection.text.contains("falta estrada"),"inspection highlights school entrance and explains missing connection")
 sim.command("road",{"cells":[Vector2i(9,13),Vector2i(10,13),Vector2i(11,13),Vector2i(12,13),Vector2i(13,13)]})
 for index in range(900): sim.step()
 hud.refresh()
 expect(hud._inspection_connection.text.contains("conectada"),"inspection updates after autonomous road completion")
 hud.close_panels()
 expect(highlighted == Vector2i(-1,-1),"closing inspection clears entrance highlight")
 hud._toggle_drawer("training")
 hud._train_role("lumberjack")
 expect(sim.training.size() == 1,"profession button queues a worker without selecting individuals")
 hud._dismiss_tutorial()
 for resolution in [Vector2i(800,600),Vector2i(980,650),Vector2i(1280,800),Vector2i(1440,900)]:
  root.size = resolution
  await frames(8)
  hud._layout()
  await frames(5)
  var bounds := Rect2(Vector2.ZERO,Vector2(resolution))
  expect(bounds.encloses(hud._dock.get_global_rect()) and bounds.encloses(hud._top.get_global_rect()),"primary controls fit "+str(resolution))
  for button in [hud._tabs.build,hud._tabs.road,hud._tabs.training,hud._pause,hud._speed_cycle]:
   if button.is_visible_in_tree(): expect(bounds.encloses(button.get_global_rect()),"dock action fits "+button.text+" "+str(resolution))
  hud._drawer.hide()
  hud._toggle_drawer("build")
  await frames(10)
  if resolution.x>=1280:
   for card:Control in hud._build_grid.get_children():expect(hud._drawer_scroll.get_global_rect().encloses(card.get_global_rect()),"desktop catalog shows full card without clipping: "+str(resolution))
  expect(hud._build_grid.get_child_count() == HUD.BUILD_ORDER.size() and bounds.encloses(hud._drawer.get_global_rect()),"building drawer fits "+str(resolution))
  hud._show_help()
  await frames(5)
  expect(bounds.encloses(hud._help.get_global_rect()),"help fits "+str(resolution))
  hud.close_panels()
 expect(hud.blocks_pointer(Vector2(60,50)),"resource bar consumes pointer input")
 expect(not hud.blocks_pointer(Vector2(720,600)),"open world receives pointer input")
 print("APPROVED_HUD_RESULT checks=",checks," failures=",failures)
 hud.queue_free()
 await frames()
 quit(0 if failures.is_empty() else 1)
