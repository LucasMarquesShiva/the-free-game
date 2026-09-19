extends Control
## First scene shown at boot. Loads the village scene on a background
## thread (via ResourceLoader.load_threaded_*) so this screen keeps
## animating instead of freezing on Godot's default color for the whole
## multi-second asset load.

const TARGET_SCENE := "res://scenes/approved.tscn"
const GOLD := Color("d8b56a")
const INK := Color("efe1c2")

var _dot_elapsed := 0.0
var _dot_count := 0
var _label: Label
var _hint: Label


func _ready() -> void:
	var background := TextureRect.new()
	background.texture = load("res://assets/boot/community-age.jpg")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var vignette := ColorRect.new()
	vignette.color = Color(0.04,0.03,0.02,0.45)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vignette)

	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia","Times New Roman","Liberation Serif","serif"])

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",14)
	center.add_child(box)

	var rule_top := Label.new()
	rule_top.text = "· ✦ ·"
	rule_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule_top.add_theme_font_override("font",serif)
	rule_top.add_theme_font_size_override("font_size",26)
	rule_top.add_theme_color_override("font_color",GOLD)
	box.add_child(rule_top)

	_label = Label.new()
	_label.text = "Carregando"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font",serif)
	_label.add_theme_font_size_override("font_size",44)
	_label.add_theme_color_override("font_color",INK)
	_label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.6))
	_label.add_theme_constant_override("shadow_offset_x",2)
	_label.add_theme_constant_override("shadow_offset_y",2)
	box.add_child(_label)

	_hint = Label.new()
	_hint.text = "Vale dos Vinhedos"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_override("font",serif)
	_hint.add_theme_font_size_override("font_size",16)
	_hint.add_theme_color_override("font_color",GOLD.darkened(0.05))
	box.add_child(_hint)

	ResourceLoader.load_threaded_request(TARGET_SCENE)


func _process(delta: float) -> void:
	_dot_elapsed += delta
	if _dot_elapsed >= 0.35:
		_dot_elapsed = 0.0
		_dot_count = (_dot_count+1) % 4
		_label.text = "Carregando" + ".".repeat(_dot_count)
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(TARGET_SCENE,progress)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			set_process(false)
			var packed: PackedScene = ResourceLoader.load_threaded_get(TARGET_SCENE)
			get_tree().change_scene_to_packed(packed)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			set_process(false)
			_label.text = "Falha ao carregar"
			_hint.text = "Reinicie o jogo, por favor."
