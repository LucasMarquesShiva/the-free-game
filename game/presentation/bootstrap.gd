extends Node

const Clock = preload("res://core/simulation_clock.gd")
var clock: RefCounted


func _ready() -> void:
	clock = Clock.new(int(ProjectSettings.get_setting("simulation/fixed_step_usec", 100000)))
	print("M0: base inicializada; passo de simulacao = ", clock.step_usec, " us.")
	if DisplayServer.get_name() == "headless":
		return
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "Vila medieval\n\nBase técnica inicial\n\nA construção autônoma e o combate serão integrados nos próximos marcos."
	label.position = Vector2(48, 48)
	label.add_theme_font_size_override("font_size", 24)
	layer.add_child(label)


func _physics_process(delta: float) -> void:
	clock.advance_usec(roundi(delta * 1000000.0))


func _notification(what: int) -> void:
	if clock == null:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		clock.paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		clock.paused = false

