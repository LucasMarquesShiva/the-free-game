extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280,720)
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await settle()
	var hud: CanvasLayer = game.hud
	hud.call("_toggle_drawer","build")
	await settle()
	print("DRAWER ",hud.get("_drawer").get_global_rect()," min ",hud.get("_drawer").get_combined_minimum_size())
	print("DRAWER SUBTITLE ",hud.get("_drawer_subtitle").get_global_rect())
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://vale-hud-build.png")
	hud.call("_choose_build","house")
	await settle()
	print("MODE ",hud.get("_mode_panel").get_global_rect()," min ",hud.get("_mode_panel").get_combined_minimum_size())
	print("MODE LABEL ",hud.get("_mode_label").get_global_rect())
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://vale-hud-mode.png")
	assert(hud.get("_drawer").size.y < 320,"Gaveta não pode reter o mínimo transitório")
	assert(hud.get("_mode_panel").size.y < 100,"Modo deve ser uma faixa compacta")
	root.content_scale_size = Vector2i(844,390)
	root.size = Vector2i(844,390)
	hud.call("_layout")
	await settle()
	print("COMPACT TOP ",hud.get("_top").get_global_rect())
	print("COMPACT DOCK ",hud.get("_dock").get_global_rect())
	hud.call("_cancel_mode")
	hud.call("_toggle_drawer","build")
	await settle()
	print("COMPACT DRAWER ",hud.get("_drawer").get_global_rect())
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://vale-hud-compact.png")
	assert(hud.get("_top").get_global_rect().end.x <= 844,"Barra cabe na largura compacta")
	assert(hud.get("_dock").get_global_rect().end.x <= 844,"Comandos cabem na largura compacta")
	assert(hud.get("_drawer").get_global_rect().end.y < hud.get("_dock").position.y,"Gaveta não invade os comandos")
	hud.call("_toggle_menu")
	await settle()
	hud.call("_toggle_restart_confirmation")
	await settle()
	var menu: Control = hud.get("_menu")
	var menu_scroll: ScrollContainer = hud.get("_menu_scroll")
	var confirmation: Control = hud.get("_restart_confirm")
	assert(menu.get_global_rect().end.y < hud.get("_dock").position.y,"Menu compacto não invade os comandos")
	assert(menu_scroll.scroll_vertical > 0,"Menu rola para revelar confirmação")
	var confirm_actions: Control = confirmation.get_child(1)
	assert(menu_scroll.get_global_rect().encloses(confirm_actions.get_global_rect()),"Botões de confirmação ficam inteiros no corpo rolável")
	assert(confirm_actions.get_child(0).size.y >= 44,"Confirmar reinício mantém alvo de toque44px")
	game.sim.stock.food = 100.0
	hud.refresh()
	assert(hud.get("_resource_values")["food"].text == "100","Recursos carregados de JSON usam números inteiros")
	print("HUD_GEOMETRY_PASS: 10 checks")
	quit()

func settle() -> void:
	for i in range(8):
		await process_frame
