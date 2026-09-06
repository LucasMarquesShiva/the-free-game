extends SceneTree
var game: Node
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://vale-first-frame.png")
	print("RENDER_CAPTURED")
	quit()
