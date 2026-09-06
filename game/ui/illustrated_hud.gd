extends CanvasLayer
## Interface ilustrada da vila pacífica. Leitura da simulação; alterações apenas por sinais.

signal build_selected(kind: String)
signal command_requested(kind: String, payload: Dictionary)
signal save_requested
signal load_requested
signal restart_requested
signal speed_selected(multiplier: int)
signal focus_requested(cell: Vector2i)

const PAPER := Color("f5e4bd")
const PANEL := Color("0b2429")
const INK := Color("f1dfb4")
const MUTED := Color("b4b69e")
const BRONZE := Color("c59a50")
const WINE := Color("e1bd71")
const DANGER := Color("eeaa89")
const SUCCESS := Color("b8d292")
const BUILD_ORDER := ["house", "farm", "vineyard", "winery", "store", "lumber", "quarry", "training"]
const ROLE_NAMES := {"resident":"Morador", "builder":"Construtor", "servant":"Servente", "instructor":"Instrutor", "lumberjack":"Lenhador", "stonecutter":"Canteiro", "farmer":"Horticultor", "vintner":"Vinhateiro"}
const ROLE_DETAILS := {"builder":"Ergue as obras da vila", "servant":"Leva materiais e produção", "instructor":"Forma novos profissionais", "lumberjack":"Produz madeira", "stonecutter":"Extrai pedra", "farmer":"Cultiva alimentos na horta", "vintner":"Cultiva uvas e produz vinho"}
const ITEM_NAMES := {"wood":"Madeira", "stone":"Pedra", "food":"Alimentos", "grapes":"Uvas", "wine":"Vinho", "population":"Moradores"}
const SHORT_NAMES := {"house":"Casa", "farm":"Horta", "vineyard":"Parreiral", "winery":"Vinícola", "store":"Armazém", "lumber":"Lenhador", "quarry":"Pedreira", "training":"Treinamento"}
const BUILD_HINTS := {"house":"Mais espaço para morar", "farm":"Alimento para crescer", "vineyard":"O começo de cada vinho", "winery":"Uvas viram vinho", "store":"Espaço para os recursos", "lumber":"Madeira para construir", "quarry":"Pedra para a vila", "training":"Novos profissionais"}

class Glyph extends Control:

	var kind := "house"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := minf(size.x, size.y) / 40.0
		draw_set_transform(Vector2((size.x - 40.0*s)*0.5, (size.y - 40.0*s)*0.5), 0.0, Vector2(s,s))
		var dark := Color("293b35")
		var gold := Color("bb843e")
		var purple := Color("7c405a")
		match kind:
			"grapes", "vineyard":
				draw_line(Vector2(20,4), Vector2(20,12), dark, 3.0, true)
				draw_ellipse_leaf(Vector2(24,7), Color("66835a"))
				for p in [Vector2(12,15),Vector2(22,15),Vector2(30,15),Vector2(17,24),Vector2(26,24),Vector2(22,33)]:
					draw_circle(p, 5.3, purple)
					draw_circle(p+Vector2(-1.5,-1.5), 1.5, Color("b58099"))
			"wine":
				draw_style_box(_bottle_style(), Rect2(13,13,17,23))
				draw_rect(Rect2(17,3,9,13), purple)
				draw_rect(Rect2(16,3,11,4), gold)
				draw_rect(Rect2(15,21,13,8), Color("f3ead3"))
			"wood", "lumber":
				for i in range(3):
					var y := 10.0 + i*9.0
					draw_line(Vector2(10,y+6),Vector2(31,y),Color("98724b"),8.0,true)
					draw_circle(Vector2(10,y+6),4.5,Color("d6ac6f"))
					draw_arc(Vector2(10,y+6),2.0,0,TAU,12,Color("98724b"),1.0,true)
			"stone", "quarry":
				draw_colored_polygon(PackedVector2Array([Vector2(6,29),Vector2(10,12),Vector2(25,8),Vector2(35,18),Vector2(32,32),Vector2(15,35)]),Color("969d94"))
				draw_colored_polygon(PackedVector2Array([Vector2(10,12),Vector2(25,8),Vector2(26,22),Vector2(6,29)]),Color("c6c8b8"))
				draw_line(Vector2(26,22),Vector2(32,32),Color("67756d"),2.0,true)
			"food", "farm":
				draw_circle(Vector2(20,24),13.0,Color("bf8546"))
				draw_circle(Vector2(20,21),12.0,Color("e2b66b"))
				for x in [14,21,28]:
					draw_line(Vector2(x-2,17),Vector2(x+1,24),Color("a6703e"),2.0,true)
			"population":
				draw_circle(Vector2(14,12),6.0,Color("bd9972"))
				draw_circle(Vector2(28,14),5.0,Color("ddb792"))
				draw_style_box(_rounded(dark),Rect2(6,20,17,17))
				draw_style_box(_rounded(Color("6b886a")),Rect2(23,22,12,15))
			_:
				var roof := purple if kind == "winery" else Color("ae6948")
				draw_style_box(_rounded(Color("d5c5a0")),Rect2(8,16,26,20))
				draw_colored_polygon(PackedVector2Array([Vector2(4,18),Vector2(20,5),Vector2(37,18)]),roof)
				draw_rect(Rect2(17,24,8,12),dark)
				draw_rect(Rect2(10,21,4,5),gold)
				draw_rect(Rect2(28,21,4,5),gold)
				if kind == "winery":
					draw_circle(Vector2(31,31),6,purple)
					draw_line(Vector2(26,29),Vector2(36,29),gold,2.0,true)
				elif kind == "training":
					draw_rect(Rect2(16,10,10,7),dark)
					draw_line(Vector2(21,10),Vector2(21,17),gold,1.0,true)

	func draw_ellipse_leaf(p: Vector2, color: Color) -> void:
		draw_colored_polygon(PackedVector2Array([p,p+Vector2(9,-3),p+Vector2(7,4),p+Vector2(1,5)]),color)

	func _rounded(color: Color) -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(3)
		return style

	func _bottle_style() -> StyleBoxFlat:
		return _rounded(Color("7c405a"))

var _serif: Font
var _tutorial: PanelContainer
var _tutorial_dismissed := false
var _sim: RefCounted
var _root: Control
var _regions: Array[Control] = []
var _top: PanelContainer
var _brand: Label
var _brand_box: VBoxContainer
var _resource_values: Dictionary = {}
var _resource_buttons: Dictionary = {}
var _resource_captions: Dictionary = {}
var _resource_glyphs: Dictionary = {}
var _dock: PanelContainer
var _tabs: Dictionary = {}
var _pause: Button
var _speed_buttons: Dictionary = {}
var _speed_group: HBoxContainer
var _speed_cycle: Button
var _speed := 1
var _village_focus: Button
var _objectives_panel: PanelContainer
var _objectives_toggle: Button
var _objective_details: VBoxContainer
var _objective_labels: Array[Label] = []
var _notice_label: Label
var _objectives_open := false
var _was_compact := false
var _drawer: PanelContainer
var _drawer_title: Label
var _drawer_subtitle: Label
var _drawer_scroll: ScrollContainer
var _drawer_content: VBoxContainer
var _drawer_kind := ""
var _build_grid: GridContainer
var _role_grid: GridContainer
var _build_costs: Dictionary = {}
var _role_count_labels: Dictionary = {}
var _quantity := 1
var _training_queue: VBoxContainer
var _queue_signature := ""
var _queue_labels: Dictionary = {}
var _queue_bars: Dictionary = {}
var _resident_label: Label
var _menu: PanelContainer
var _menu_scroll: ScrollContainer
var _restart_confirm: VBoxContainer
var _help: PanelContainer
var _inspector: PanelContainer
var _inspected_id := -1
var _inspection_title: Label
var _inspection_description: Label
var _inspection_state: Label
var _inspection_progress: ProgressBar
var _inspection_details: Label
var _inspection_cancel: Button
var _mode_panel: PanelContainer
var _mode_label: Label
var _mode_type := ""
var _toast: PanelContainer
var _toast_label: Label
var _toast_timer: Timer
var _outcome: Label
var _layout_queued := false

func setup(sim: RefCounted) -> void:
	_sim = sim
	if is_instance_valid(_root):
		refresh()
		return
	layer = 10
	_root = Control.new()
	_root.name = "IllustratedHUD"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)
	_make_top_bar()
	_make_objectives()
	_make_tutorial()
	_make_dock()
	_make_drawer()
	_make_inspector()
	_make_menu()
	_make_help()
	_make_mode_and_toast()
	get_viewport().size_changed.connect(_layout)
	_layout()
	refresh()

func _make_theme() -> Theme:
	var theme := Theme.new()
	# A fonte incorporada à engine é distribuível e idêntica no app e na Web.
	theme.default_font = ThemeDB.fallback_font
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Times New Roman", "Liberation Serif", "serif"])
	_serif = serif
	theme.default_font_size = 17
	theme.set_color("font_color", "Label", INK)
	theme.set_constant("separation", "HBoxContainer", 8)
	theme.set_constant("separation", "VBoxContainer", 8)
	theme.set_stylebox("normal", "Button", _style(Color("14383c"), Color("94713a"), 9))
	theme.set_stylebox("hover", "Button", _style(Color("205057"), BRONZE, 9))
	theme.set_stylebox("pressed", "Button", _style(Color("155d55"), BRONZE, 9))
	theme.set_stylebox("focus", "Button", _focus_style())
	theme.set_stylebox("disabled", "Button", _style(Color("1a3336"), Color("47605c"), 9))
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_color("font_disabled_color", "Button", MUTED)
	theme.set_font_size("font_size", "Button", 17)
	theme.set_stylebox("background", "ProgressBar", _style(Color("1a4143"), Color.TRANSPARENT, 4, 0))
	theme.set_stylebox("fill", "ProgressBar", _style(SUCCESS, Color.TRANSPARENT, 4, 0))
	return theme

func _style(bg: Color, border: Color = Color("94713a"), radius: int = 12, padding: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _focus_style() -> StyleBoxFlat:
	var style := _style(Color.TRANSPARENT, BRONZE, 9, 0)
	style.set_border_width_all(3)
	return style

func _panel(parent: Node, register_region: bool = true, padding: int = 14) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := _style(PANEL, BRONZE.darkened(0.2), 7, padding)
	style.set_border_width_all(2)
	style.shadow_color = Color(0.08,0.12,0.09,0.23)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0,3)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(panel)
	panel.minimum_size_changed.connect(_queue_layout)
	if register_region:
		_regions.append(panel)
	return panel

func _vbox(parent: Node, spacing: int = 8) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", spacing)
	parent.add_child(box)
	return box

func _hbox(parent: Node, spacing: int = 8) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", spacing)
	parent.add_child(box)
	return box

func _label(parent: Node, text: String = "", size: int = 17, color: Color = INK, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	if size >= 19 and _serif != null:
		label.add_theme_font_override("font",_serif)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.max_lines_visible = 4
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable, min_width: float = 0) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(min_width,44)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _accent(button: Button, color: Color = Color("08664e")) -> void:
	button.add_theme_stylebox_override("normal", _style(color, color.lightened(0.12), 9))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.1), BRONZE, 9))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.1), BRONZE, 9))
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", PAPER)

func _spacer(parent: Node) -> Control:
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)
	return spacer

func _glyph(parent: Node, kind: String, side: float = 34) -> Glyph:
	var glyph := Glyph.new()
	glyph.kind = kind
	glyph.custom_minimum_size = Vector2(side,side)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(glyph)
	return glyph

func _make_top_bar() -> void:
	_top = _panel(_root, true, 10)
	_top.name = "ResourcesBar"
	var row := _hbox(_top, 9)
	_glyph(row,"grapes",38)
	_brand_box = _vbox(row,0)
	_brand_box.custom_minimum_size.x = 182
	_brand_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_brand = _label(_brand_box,"Minha vila",28)
	_label(_brand_box,"Vale dos Vinhedos",13,MUTED)
	for item in ["wood","stone","food","grapes","wine","population"]:
		var button := _button(row,"",_resource_info.bind(item),86)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = ITEM_NAMES[item]+": toque para detalhes"
		button.add_theme_stylebox_override("normal",_style(Color("102f34"),Color.TRANSPARENT,8,4))
		var content := _hbox(button,5)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 6
		content.offset_right = -6
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_resource_glyphs[item] = _glyph(content,item,27)
		var values := _vbox(content,0)
		values.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_resource_values[item] = _label(values,"0",20)
		_resource_captions[item] = _label(values,ITEM_NAMES[item],11,MUTED)
		_resource_buttons[item] = button
	var menu_button := _button(row,"Menu",_toggle_menu,66)
	menu_button.tooltip_text = "Salvar, carregar, reiniciar e ajuda"

func _make_objectives() -> void:
	_objectives_panel = _panel(_root,true,12)
	_objectives_panel.name = "MissionPanel"
	var box := _vbox(_objectives_panel,7)
	_objectives_toggle = _button(box,"Objetivos  0/3  +",_toggle_objectives)
	_objectives_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_objectives_toggle.add_theme_stylebox_override("normal",_style(Color.TRANSPARENT,Color.TRANSPARENT,8,4))
	_objective_details = _vbox(box,9)
	_outcome = _label(_objective_details,"Um vale para chamar de seu",19,WINE,true)
	for i in range(3):
		_objective_labels.append(_label(_objective_details,"",15,INK,true))
	_notice_label = _label(_objective_details,"",14,MUTED,true)
	_notice_label.add_theme_constant_override("line_spacing",2)
	_objective_details.hide()

func _make_tutorial() -> void:
	_tutorial = _panel(_root,true,14)
	_tutorial.name = "FirstDayHint"
	var box := _vbox(_tutorial,8)
	_label(box,"Seu primeiro dia",21,WINE)
	_label(box,"Construa casas e uma horta. Seus moradores cuidam do trabalho. Depois, faça seu primeiro vinho.",15,INK,true)
	_accent(_button(box,"Entendi, vamos começar",_dismiss_tutorial))

func _dismiss_tutorial() -> void:
	_tutorial_dismissed = true
	if is_instance_valid(_tutorial):
		_tutorial.hide()

func _thumbnail(parent: Node, kind: String, height: float = 56.0) -> void:
	var path := "res://assets/illustrated/%s.png" % kind
	if ResourceLoader.exists(path,"Texture2D"):
		var image := TextureRect.new()
		var cutout := ShaderMaterial.new()
		cutout.shader = preload("res://assets/illustrated/paper_cutout.gdshader")
		image.material = cutout
		image.texture = load(path)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(100,height)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(image)
	else:
		var glyph := _glyph(parent,kind,height)
		glyph.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _make_dock() -> void:
	_dock = _panel(_root,true,8)
	_dock.name = "CommandDock"
	var row := _hbox(_dock,7)
	_tabs["build"] = _button(row,"Construir",_toggle_drawer.bind("build"),178)
	_tabs["training"] = _button(row,"Ofícios",_toggle_drawer.bind("training"),122)
	_tabs["objectives"] = _button(row,"Objetivos",_toggle_objectives,122)
	_accent(_tabs["build"])
	_spacer(row)
	_village_focus = _button(row,"Vila",_focus_village,70)
	_village_focus.tooltip_text = "Voltar ao centro da vila"
	_pause = _button(row,"Pausar",func(): command_requested.emit("pause",{}),88)
	_speed_group = _hbox(row,3)
	for speed in [1,2,4]:
		_speed_buttons[speed] = _button(_speed_group,"%d×" % speed,_choose_speed.bind(speed),44)
	_speed_cycle = _button(row,"1×",_cycle_speed,48)
	_speed_cycle.tooltip_text = "Alternar velocidade: 1×, 2×, 4×"
	_button(row,"?",_show_help,44).tooltip_text = "Como jogar"

func _make_drawer() -> void:
	_drawer = _panel(_root,true,16)
	_drawer.name = "ActionDrawer"
	_drawer.visible = false
	var box := _vbox(_drawer,9)
	var heading := _hbox(box)
	var titles := _vbox(heading,1)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drawer_title = _label(titles,"",26)
	_drawer_subtitle = _label(titles,"",15,MUTED,true)
	_drawer_subtitle.max_lines_visible = 2
	_button(heading,"Fechar",close_panels,78)
	_drawer_scroll = ScrollContainer.new()
	_drawer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_drawer_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_drawer_scroll)
	_drawer_content = _vbox(_drawer_scroll,12)
	_drawer_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _toggle_drawer(kind: String) -> void:
	if _drawer.visible and _drawer_kind == kind:
		close_panels()
		return
	close_panels()
	_drawer_kind = kind
	_clear_children(_drawer_content)
	_build_costs.clear()
	_role_count_labels.clear()
	_queue_labels.clear()
	_queue_bars.clear()
	_queue_signature = ""
	_build_grid = null
	_role_grid = null
	_training_queue = null
	_resident_label = null
	match kind:
		"build": _populate_build()
		"training": _populate_training()
	_drawer.visible = true
	_drawer_scroll.scroll_vertical = 0
	_layout()
	refresh()

func _populate_build() -> void:
	_drawer_title.text = "Dê espaço à sua vila"
	_drawer_subtitle.text = "Escolha uma construção e toque no terreno. A equipe assume a obra."
	_build_grid = GridContainer.new()
	_build_grid.columns = 4
	_build_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_grid.add_theme_constant_override("h_separation",9)
	_build_grid.add_theme_constant_override("v_separation",9)
	_drawer_content.add_child(_build_grid)
	for kind in BUILD_ORDER:
		var definition := _definition(kind)
		var button := _button(_build_grid,"",_choose_build.bind(kind))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 120
		button.tooltip_text = str(definition.get("description",BUILD_HINTS[kind]))
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for edge in ["left","right","top","bottom"]:
			margin.add_theme_constant_override("margin_"+edge,10)
		button.add_child(margin)
		var card := _vbox(margin,4)
		_thumbnail(card,kind,52)
		var title := _label(card,SHORT_NAMES[kind],19,WINE if kind == "winery" else INK)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var cost_label := _label(card,_cost_text(definition.get("cost",{})),14,INK)
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_build_costs[kind] = cost_label

func _populate_training() -> void:
	_drawer_title.text = "Mais mãos para a vila"
	_drawer_subtitle.text = "Escolha profissão e quantidade. O centro encontra moradores e forma a equipe."
	var settings := _hbox(_drawer_content)
	_resident_label = _label(settings,"",16,INK)
	_spacer(settings)
	_label(settings,"Quantidade",15,MUTED)
	for qty in [1,3,5]:
		var btn := _button(settings,str(qty),_set_quantity.bind(qty),44)
		btn.name = "Quantity%d" % qty
		if qty == _quantity:
			_accent(btn)
	_label(_drawer_content,"Cada pessoa: 2 alimentos · 20 s de formação",14,MUTED)
	_role_grid = GridContainer.new()
	_role_grid.columns = 4
	_role_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_role_grid.add_theme_constant_override("h_separation",8)
	_role_grid.add_theme_constant_override("v_separation",8)
	_drawer_content.add_child(_role_grid)
	for role in ["builder","servant","farmer","vintner","lumberjack","stonecutter","instructor"]:
		var button := _button(_role_grid,"",_train_role.bind(role))
		button.custom_minimum_size.y = 75
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = ROLE_DETAILS[role]+". Formação e trabalho automáticos."
		var content := _vbox(button,2)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 12
		content.offset_right = -12
		content.offset_top = 8
		_role_count_labels[role] = _label(content,ROLE_NAMES[role],17)
		_label(content,ROLE_DETAILS[role],12,MUTED)
		_label(content,"+ Formar",13,WINE)
	_label(_drawer_content,"Fila de formação",18)
	_training_queue = _vbox(_drawer_content,6)

func _set_quantity(qty: int) -> void:
	_quantity = qty
	# Recriar só a gaveta por ação explícita mantém foco e fila estáveis nos refreshes.
	_drawer.visible = false
	_toggle_drawer("training")

func _train_role(role: String) -> void:
	command_requested.emit("train",{"role":role,"quantity":_quantity})
	refresh()

func _choose_build(kind: String) -> void:
	_dismiss_tutorial()
	close_panels()
	_mode_type = "build"
	set_mode(SHORT_NAMES.get(kind,kind)+" · toque no terreno para construir")
	build_selected.emit(kind)

func _make_inspector() -> void:
	_inspector = _panel(_root,true,15)
	_inspector.name = "BuildingInspector"
	_inspector.visible = false
	var box := _vbox(_inspector,9)
	var row := _hbox(box)
	_inspection_title = _label(row,"",21,INK,true)
	_button(row,"×",func(): _inspector.hide(),44).tooltip_text = "Fechar inspeção"
	_inspection_description = _label(box,"",15,MUTED,true)
	_inspection_state = _label(box,"",17,WINE,true)
	_inspection_progress = ProgressBar.new()
	_inspection_progress.show_percentage = false
	_inspection_progress.custom_minimum_size.y = 8
	box.add_child(_inspection_progress)
	_inspection_details = _label(box,"",15,INK,true)
	var actions := _hbox(box)
	var focus := _button(actions,"Ver no mapa",_focus_inspected)
	focus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspection_cancel = _button(actions,"Cancelar obra",_cancel_inspected)
	_inspection_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspection_cancel.add_theme_color_override("font_color",DANGER)
	_inspection_cancel.tooltip_text = "Interromper esta obra e liberar os materiais que ainda não foram usados"

func inspect(building: Dictionary) -> void:
	if not is_instance_valid(_root):
		return
	close_panels()
	_inspected_id = int(building.get("id",-1))
	_inspector.visible = _inspected_id >= 0
	_refresh_inspection()
	_layout()

func _focus_inspected() -> void:
	var building := _find_building(_inspected_id)
	if not building.is_empty():
		focus_requested.emit(building.get("cell",Vector2i(8,12)))

func _cancel_inspected() -> void:
	if _inspected_id >= 0:
		command_requested.emit("cancel",{"id":_inspected_id})
		_refresh_inspection()

func _make_menu() -> void:
	_menu = _panel(_root,true,15)
	_menu.name = "GameMenu"
	_menu.visible = false
	var box := _vbox(_menu,8)
	var title_row := _hbox(box)
	_label(title_row,"Sua partida",22)
	_spacer(title_row)
	_button(title_row,"×",close_panels,44)
	_menu_scroll = ScrollContainer.new()
	_menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_menu_scroll)
	var content := _vbox(_menu_scroll,8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_accent(_button(content,"Salvar partida",func(): save_requested.emit()))
	_button(content,"Carregar partida",func(): load_requested.emit())
	_button(content,"Como jogar",_show_help)
	_button(content,"Reiniciar partida",_toggle_restart_confirmation)
	_restart_confirm = _vbox(content,7)
	_restart_confirm.visible = false
	_label(_restart_confirm,"Começar uma nova vila? O progresso atual que não foi salvo será perdido.",15,DANGER,true)
	var actions := _hbox(_restart_confirm)
	_accent(_button(actions,"Reiniciar",func():
		close_panels()
		set_mode("")
		restart_requested.emit()
	),DANGER)
	_button(actions,"Voltar",func(): _restart_confirm.hide())

func _toggle_restart_confirmation() -> void:
	_restart_confirm.visible = not _restart_confirm.visible
	_layout()
	# Aguardar os containers resolverem a nova altura antes de revelar os botões.
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_restart_confirm) and _restart_confirm.visible and _menu.visible:
		_menu_scroll.ensure_control_visible(_restart_confirm)

func _toggle_menu() -> void:
	var opening := not _menu.visible
	close_panels()
	_menu.visible = opening
	_menu_scroll.scroll_vertical = 0
	_layout()

func _make_help() -> void:
	_help = _panel(_root,true,18)
	_help.name = "HelpPanel"
	_help.visible = false
	var box := _vbox(_help,10)
	var head := _hbox(box)
	_label(head,"Bem-vindo ao vale",24,WINE)
	_spacer(head)
	_button(head,"Fechar",close_panels,78)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var content := _vbox(scroll,12)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in [
		["Construa e observe","Comece com duas casas e uma horta. Em Construir, escolha o prédio e toque em um terreno livre. Construtores e serventes assumem tudo sozinhos."],
		["Forme a equipe","Em Ofícios, escolha profissão e quantidade. Se todos estiverem ocupados, você pode esperar ou formar mais. Toque nos prédios para entender qualquer espera."],
		["Do parreiral à vinícola","Construa ambos. Cada um precisa de um vinhateiro. Serventes levam as uvas para a vinícola e retiram o vinho. Entregue 12 vinhos ao armazém."],
		["Explore com calma","Arraste o terreno para mover a câmera. Use pinça ou a roda do mouse para aproximar. Vila retorna ao centro. Pausar permite planejar; 1×, 2× e 4× ajustam o ritmo."],
		["Guarde sua partida","Menu → Salvar preserva sua vila. Use Carregar para retomar. Reiniciar pede confirmação antes de começar de novo."]
	]:
		_label(content,entry[0],19,INK,true)
		_label(content,entry[1],17,MUTED,true)

func _show_help() -> void:
	close_panels()
	_help.show()
	_layout()

func _make_mode_and_toast() -> void:
	_mode_panel = _panel(_root,true,8)
	_mode_panel.name = "PlacementInstructions"
	_mode_panel.visible = false
	var mode_row := _hbox(_mode_panel)
	_mode_label = _label(mode_row,"",17,INK,true)
	_mode_label.max_lines_visible = 2
	_button(mode_row,"Cancelar",_cancel_mode,88)
	_toast = _panel(_root,false,13)
	_toast.name = "FeedbackToast"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_toast_label = _label(_toast,"",17,INK,true)
	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.wait_time = 5.0
	_toast_timer.timeout.connect(func(): _toast.hide())
	add_child(_toast_timer)

func _cancel_mode() -> void:
	set_mode("")
	build_selected.emit("")

func set_mode(text: String) -> void:
	if not is_instance_valid(_mode_panel):
		return
	_mode_label.text = text
	_mode_panel.visible = not text.is_empty()
	if text.is_empty():
		_mode_type = ""
	_layout()

func show_message(text: String) -> void:
	if not is_instance_valid(_toast):
		return
	_toast_label.text = text
	_toast.visible = not text.is_empty()
	_toast_timer.start()
	_layout()

func close_panels() -> void:
	for panel in [_drawer,_menu,_help,_inspector]:
		if is_instance_valid(panel):
			panel.hide()
	if is_instance_valid(_restart_confirm):
		_restart_confirm.hide()
	_drawer_kind = ""

func blocks_pointer(position: Vector2) -> bool:
	if not is_instance_valid(_root) or not _root.is_visible_in_tree():
		return false
	# Converter o ponteiro para cada painel também sob stretch canvas_items.
	for region in _regions:
		if not is_instance_valid(region) or not region.is_visible_in_tree():
			continue
		var local_point := region.get_global_transform_with_canvas().affine_inverse() * position
		if Rect2(Vector2.ZERO,region.size).has_point(local_point):
			return true
	return false

func _toggle_objectives() -> void:
	_dismiss_tutorial()
	_objectives_open = not _objectives_open
	_objective_details.visible = _objectives_open
	refresh()
	_layout()

func _choose_speed(multiplier: int) -> void:
	_speed = multiplier
	speed_selected.emit(multiplier)
	_refresh_speed()

func _cycle_speed() -> void:
	_choose_speed(2 if _speed == 1 else (4 if _speed == 2 else 1))

func _refresh_speed() -> void:
	for value in _speed_buttons:
		var button: Button = _speed_buttons[value]
		button.add_theme_stylebox_override("normal",_style(Color("08664e") if value == _speed else Color("14383c"),Color("94713a"),8,8))
		button.add_theme_color_override("font_color",PAPER if value == _speed else INK)
	_speed_cycle.text = "%d×" % _speed

func _focus_village() -> void:
	focus_requested.emit(Vector2i(8,12))

func refresh() -> void:
	if not is_instance_valid(_root) or _sim == null:
		return
	var stock := _dictionary(_sim.get("stock"))
	var counts := _call_dictionary("profession_counts")
	var workers := _array(_sim.get("workers"))
	for item in _resource_values:
		var label: Label = _resource_values[item]
		if item == "population":
			label.text = "%d/%d" % [workers.size(),int(_call_value("population_capacity",workers.size()))]
		else:
			label.text = str(int(stock.get(item,0)))
			label.add_theme_color_override("font_color",DANGER if item == "food" and int(stock.get(item,0)) < 20 else INK)
	_pause.text = "Retomar" if bool(_sim.get("paused")) else "Pausar"
	var rows: Array = _call_value("objective_rows",[])
	var done := 0
	for i in range(_objective_labels.size()):
		var label := _objective_labels[i]
		label.visible = i < rows.size()
		if i < rows.size():
			var row: Dictionary = rows[i]
			var complete := bool(row.get("done",false))
			done += 1 if complete else 0
			label.text = ("[x]  " if complete else "[ ]  ")+str(row.get("text",""))
			label.add_theme_color_override("font_color",SUCCESS if complete else INK)
	_objectives_toggle.text = "Objetivos  %d/%d  %s" % [done,rows.size(),"−" if _objectives_open else "+"]
	_notice_label.text = str(_call_value("notice","Os habitantes encontram trabalho sozinhos."))
	_outcome.text = "Sua vila prosperou!" if bool(_sim.get("won")) else ("A vila precisa recomeçar" if bool(_sim.get("lost")) else "Um vale para chamar de seu")
	if bool(_sim.get("lost")):
		_notice_label.text = "Abra Menu → Reiniciar para tentar uma nova partida."
	elif bool(_sim.get("won")):
		_notice_label.text = "Todos os objetivos cumpridos. Você pode continuar observando a vila."
	if _drawer.visible:
		for kind in _build_costs:
			var cost: Dictionary = _definition(kind).get("cost",{})
			var enough := true
			for item in cost:
				if _available(item) < int(cost[item]):
					enough = false
			var cost_label: Label = _build_costs[kind]
			cost_label.add_theme_color_override("font_color",INK if enough else DANGER)
		if _drawer_kind == "training":
			_resident_label.text = "%d moradores disponíveis" % int(counts.get("resident",0))
			for role in _role_count_labels:
				var role_label: Label = _role_count_labels[role]
				role_label.text = "%s · %d" % [ROLE_NAMES[role],int(counts.get(role,0))]
			_refresh_training()
	_refresh_inspection()
	_refresh_speed()

func _refresh_training() -> void:
	if not is_instance_valid(_training_queue):
		return
	var queue := _array(_sim.get("training"))
	var signature := ""
	for record in queue:
		signature += str(record.get("id",-1))+":"+str(record.get("role",""))+";"
	if signature != _queue_signature or _training_queue.get_child_count() == 0:
		_queue_signature = signature
		_clear_children(_training_queue)
		_queue_labels.clear()
		_queue_bars.clear()
		if queue.is_empty():
			_label(_training_queue,"Nenhuma formação na fila. Os profissionais formados procuram trabalho automaticamente.",15,MUTED,true)
		for record in queue:
			var id := int(record.get("id",-1))
			var line := _hbox(_training_queue)
			var info := _vbox(line,3)
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_queue_labels[id] = _label(info,"",15,INK,true)
			var progress := ProgressBar.new()
			progress.show_percentage = false
			progress.custom_minimum_size.y = 5
			info.add_child(progress)
			_queue_bars[id] = progress
			_button(line,"Cancelar",_cancel_training.bind(id),84)
	for record in queue:
		var id := int(record.get("id",-1))
		if _queue_labels.has(id):
			var label: Label = _queue_labels[id]
			var progress: ProgressBar = _queue_bars[id]
			label.text = "%s · %s" % [ROLE_NAMES.get(record.get("role",""),"Profissional"),record.get("reason","Em formação")]
			progress.value = clampf(float(record.get("progress",0))*100.0,0,100)

func _cancel_training(id: int) -> void:
	command_requested.emit("cancel_training",{"id":id})
	refresh()

func _refresh_inspection() -> void:
	if not is_instance_valid(_inspector) or not _inspector.visible:
		return
	var building := _find_building(_inspected_id)
	if building.is_empty() or str(building.get("stage","")) == "cancelled":
		_inspector.hide()
		return
	var definition := _definition(str(building.get("kind","")))
	_inspection_title.text = str(definition.get("name","Construção"))
	_inspection_description.text = str(definition.get("description",""))
	var stage := str(building.get("stage",""))
	var complete := stage == "complete"
	var reason := str(building.get("reason",""))
	var states := {"preparing":"Preparando o terreno","materials":"Recebendo materiais","building":"Em construção","complete":"Concluída"}
	_inspection_state.text = reason if not reason.is_empty() else str(states.get(stage,stage))
	_inspection_progress.value = 100.0 * float(building.get("production",0) if complete else building.get("progress",0))
	_inspection_progress.visible = not complete or not str(definition.get("profession","")).is_empty()
	var details: Array[String] = []
	if not complete:
		var delivered: Dictionary = building.get("delivered",{})
		var costs: Dictionary = definition.get("cost",{})
		for item in costs:
			details.append("%s: %d/%d" % [ITEM_NAMES.get(item,item),int(delivered.get(item,0)),int(costs[item])])
	else:
		var profession := str(definition.get("profession",""))
		if not profession.is_empty():
			var worker_id := int(building.get("worker",-1))
			var worker_state := "Aguardando profissional" if worker_id < 0 else "Em atividade"
			for worker in _array(_sim.get("workers")):
				if int(worker.get("id",-1)) == worker_id:
					worker_state = str(worker.get("state",worker_state))
					break
			details.append(ROLE_NAMES.get(profession,profession)+" · "+worker_state)
		for key in ["input","output"]:
			var inventory: Dictionary = building.get(key,{})
			for item in inventory:
				if int(inventory[item]) > 0:
					details.append("%s: %d %s" % ["Entrada" if key == "input" else "Para retirar",int(inventory[item]),str(ITEM_NAMES.get(item,item)).to_lower()])
		if str(building.get("kind","")) == "house":
			details.append("4 vagas de moradia · chegada automática de moradores")
	_inspection_details.text = "\n".join(details)
	_inspection_cancel.visible = not complete and not bool(building.get("initial",false))

func _resource_info(item: String) -> void:
	if item == "population":
		var counts := _call_dictionary("profession_counts")
		show_message("%d moradores disponíveis para formação. Casas e alimentos atraem mais habitantes." % int(counts.get("resident",0)))
	else:
		var stock := _dictionary(_sim.get("stock")) if _sim != null else {}
		var reserved := int(stock.get(item,0))-_available(item)
		show_message("%s no armazém: %d · livres: %d · reservados: %d. Cargas e produção nos prédios ficam fora deste total." % [ITEM_NAMES.get(item,item),int(stock.get(item,0)),_available(item),reserved])

func _available(item: String) -> int:
	if _sim != null and _sim.has_method("available"):
		return int(_sim.call("available",item))
	return int(_dictionary(_sim.get("stock")).get(item,0)) if _sim != null else 0

func _definition(kind: String) -> Dictionary:
	if _sim != null and _sim.has_method("definition"):
		return _dictionary(_sim.call("definition",kind))
	return {}

func _find_building(id: int) -> Dictionary:
	if _sim != null:
		for building in _array(_sim.get("buildings")):
			if int(building.get("id",-1)) == id:
				return building
	return {}

func _call_dictionary(method: String) -> Dictionary:
	return _dictionary(_call_value(method,{}))

func _call_value(method: String, fallback: Variant) -> Variant:
	return _sim.call(method) if _sim != null and _sim.has_method(method) else fallback

func _dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

func _array(value: Variant) -> Array:
	return value if value is Array else []

func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for item in ["wood","stone","food","grapes","wine"]:
		if int(cost.get(item,0)) > 0:
			parts.append("%d %s" % [int(cost[item]),str(ITEM_NAMES[item]).to_lower()])
	return " · ".join(parts) if not parts.is_empty() else "Sem custo"

func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _queue_layout() -> void:
	if _layout_queued:
		return
	_layout_queued = true
	call_deferred("_apply_queued_layout")

func _apply_queued_layout() -> void:
	_layout_queued = false
	_layout()

func _layout() -> void:
	if not is_instance_valid(_root):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var width := viewport_size.x
	var height := viewport_size.y
	var compact := width < 1020.0 or height < 520.0
	var margin := 12.0 if compact else 18.0
	var top_height := 65.0 if compact else 73.0
	_top.position = Vector2(margin,margin)
	_top.size = Vector2(width-margin*2,top_height)
	_brand_box.custom_minimum_size.x = 145.0 if compact else 182.0
	_brand.add_theme_font_size_override("font_size",24 if compact else 28)
	for item in _resource_buttons:
		var button: Button = _resource_buttons[item]
		button.custom_minimum_size.x = 73.0 if compact else 86.0
		var value: Label = _resource_values[item]
		value.add_theme_font_size_override("font_size",17 if compact else 20)
		_resource_captions[item].visible = not compact
		_resource_glyphs[item].custom_minimum_size = Vector2(22,22) if compact else Vector2(27,27)
	_dock.position = Vector2(margin,height-margin-62)
	_dock.size = Vector2(width-margin*2,62)
	_tabs["build"].custom_minimum_size.x = 155.0 if compact else 178.0
	_tabs["training"].custom_minimum_size.x = 91.0 if compact else 122.0
	_tabs["objectives"].custom_minimum_size.x = 112.0 if compact else 132.0
	_village_focus.custom_minimum_size.x = 57.0 if compact else 70.0
	_pause.custom_minimum_size.x = 76.0 if compact else 88.0
	_speed_group.visible = not compact
	_speed_cycle.visible = compact
	if compact and not _was_compact:
		_objectives_open = false
		_objective_details.hide()
	_was_compact = compact
	_objectives_panel.position = Vector2(margin,margin+top_height+12)
	_objectives_panel.size = Vector2(285 if compact else 302,0)
	if is_instance_valid(_tutorial):
		_tutorial.position = Vector2(margin,margin+top_height+88)
		_tutorial.size = Vector2(285 if compact else 302,0)
	var drawer_height := minf(358.0,maxf(150.0,height-top_height-margin*3-79.0))
	var drawer_width := minf(1160.0,width-margin*2)
	_drawer.position = Vector2((width-drawer_width)*0.5,height-margin-74-drawer_height)
	_drawer.size = Vector2(drawer_width,drawer_height)
	if is_instance_valid(_build_grid):
		_build_grid.columns = 4
	if is_instance_valid(_role_grid):
		_role_grid.columns = 3 if compact else 4
	_inspector.position = Vector2(width-margin-(308 if compact else 338),margin+top_height+12)
	_inspector.size = Vector2(308 if compact else 338,0)
	_inspection_description.visible = not compact
	_menu.position = Vector2(width-margin-310,margin+top_height+12)
	_menu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if compact else ScrollContainer.SCROLL_MODE_DISABLED
	_menu.size = Vector2(310,maxf(160.0,height-_menu.position.y-margin-74.0) if compact else 0.0)
	var help_width := minf(630.0,width-margin*2)
	var help_height := minf(570.0,height-margin*2-10)
	_help.position = Vector2((width-help_width)*0.5,(height-help_height)*0.5)
	_help.size = Vector2(help_width,help_height)
	var mode_width := minf(665.0,width-margin*2)
	_mode_panel.position = Vector2((width-mode_width)*0.5,height-margin-132)
	_mode_panel.size = Vector2(mode_width,56)
	var toast_width := minf(500.0,width-margin*2)
	_toast.position = Vector2((width-toast_width)*0.5,margin+top_height+12)
	_toast.size = Vector2(toast_width,0)
