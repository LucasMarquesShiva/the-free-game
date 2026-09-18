extends CanvasLayer
## Interface da vila 3D. Somente leitura da simulação; ações seguem por sinais.

signal build_selected(kind: String)
signal command_requested(kind: String, payload: Dictionary)
signal save_requested(slot: int)
signal load_requested(slot: int)
signal restart_requested
signal speed_selected(multiplier: int)
signal focus_requested(cell: Vector2i)
signal entrance_highlighted(cell: Vector2i)
signal language_changed

const PAPER := Color("f5e4bd")
const PANEL := Color("0b2429")
const INK := Color("f1dfb4")
## Body text color for labels sitting on the new paper-textured panel
## background (light), as opposed to INK (light text for dark buttons/docks).
const INK_DARK := Color("3a2a18")
const MUTED := Color("6b5f47")
const BRONZE := Color("c59a50")
const WINE := Color("e1bd71")
## Dark counterpart of WINE for headings on the light paper backgrounds
## used everywhere now (WINE itself is kept for any future dark surface).
const WINE_DARK := Color("5c1710")
const DANGER := Color("eeaa89")
const SUCCESS := Color("b8d292")
const DANGER_DARK := Color("6e2210")
const SUCCESS_DARK := Color("223d10")
const BUILD_ORDER := ["lumber", "sawmill", "quarry", "farm", "mill", "bakery", "inn", "house", "vineyard", "winery", "store", "workshop", "barracks", "training"]
const ROLE_NAMES := {"resident":"Morador", "builder":"Construtor", "servant":"Servente", "instructor":"Instrutor", "lumberjack":"Lenhador", "stonecutter":"Canteiro", "farmer":"Horticultor", "vintner":"Vinhateiro", "miller":"Moleiro", "baker":"Padeiro", "recruit":"Recruta"}
const ROLE_DETAILS := {"builder":"Ergue as obras da vila", "servant":"Leva materiais e produção", "instructor":"Forma novos profissionais", "lumberjack":"Corta árvores e serra troncos", "stonecutter":"Extrai pedra", "farmer":"Cultiva alimentos e cereal", "vintner":"Cultiva uvas e produz vinho", "miller":"Moí cereal", "baker":"Asse pães", "recruit":"Caminha até o quartel"}
const ITEM_NAMES := {"wood":"Madeira", "stone":"Pedra", "food":"Alimentos", "grapes":"Uvas", "wine":"Vinho", "gold":"Ouro", "trunks":"Troncos", "corn":"Cereal", "flour":"Farinha", "loaves":"Pães", "axe":"Machado", "bow":"Arco", "population":"Moradores"}
const SHORT_NAMES := {"house":"Casa", "farm":"Horta", "vineyard":"Parreiral", "winery":"Vinícola", "store":"Armazém", "lumber":"Lenhador", "quarry":"Pedreira", "training":"Escola", "inn":"Taverna", "sawmill":"Serraria", "mill":"Moinho", "bakery":"Padaria", "workshop":"Armas", "barracks":"Quartel"}
const BUILD_HINTS := {"house":"Abrigo", "farm":"Alimento e cereal", "vineyard":"O começo de cada vinho", "winery":"Uvas viram vinho", "store":"Depósito físico", "lumber":"Corta árvores", "quarry":"Pedra na jazida", "training":"Forma civis com ouro", "inn":"Os trabalhadores comem aqui", "sawmill":"Troncos viram madeira", "mill":"Cereal vira farinha", "bakery":"Farinha vira pão", "workshop":"Machados e arcos", "barracks":"Recrutas recebem armas"}

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
			"trunks", "sawmill":
				draw_line(Vector2(8,28),Vector2(32,18),Color("7a5330"),10.0,true)
				draw_circle(Vector2(8,28),5.0,Color("d6ac6f"))
				draw_line(Vector2(10,16),Vector2(34,10),Color("98724b"),8.0,true)
			"mill":
				draw_circle(Vector2(20,22),8.0,Color("969d94"))
				draw_colored_polygon(PackedVector2Array([Vector2(12,16),Vector2(20,6),Vector2(28,16)]),Color("ae6948"))
				draw_line(Vector2(6,20),Vector2(34,20),Color("7a5330"),3.0,true)
				draw_line(Vector2(20,6),Vector2(20,34),Color("7a5330"),3.0,true)
			"bakery", "loaves":
				draw_circle(Vector2(14,24),7.0,Color("c19357"))
				draw_circle(Vector2(26,22),6.0,Color("d6ac6f"))
				draw_rect(Rect2(8,10,24,8),Color("ae6948"))
			"inn":
				draw_style_box(_rounded(Color("d5c5a0")),Rect2(8,16,26,20))
				draw_colored_polygon(PackedVector2Array([Vector2(4,18),Vector2(20,5),Vector2(37,18)]),Color("ae6948"))
				draw_rect(Rect2(16,22,10,12),dark)
				draw_circle(Vector2(31,28),5.0,gold)
			"workshop", "axe":
				draw_rect(Rect2(10,22,20,12),Color("98724b"))
				draw_line(Vector2(14,10),Vector2(14,24),Color("7a5330"),4.0,true)
				draw_colored_polygon(PackedVector2Array([Vector2(10,10),Vector2(26,8),Vector2(26,14),Vector2(10,16)]),Color("85867b"))
			"bow":
				draw_arc(Vector2(20,20),12.0,-1.2,1.2,12,Color("7a5330"),3.0,true)
				draw_line(Vector2(10,12),Vector2(10,28),Color("4f3525"),2.0,true)
			"barracks":
				draw_style_box(_rounded(Color("969d94")),Rect2(8,16,24,18))
				draw_colored_polygon(PackedVector2Array([Vector2(6,18),Vector2(20,6),Vector2(34,18)]),Color("ae6948"))
				draw_rect(Rect2(17,24,8,10),dark)
				draw_line(Vector2(28,20),Vector2(28,34),Color("7a5330"),3.0,true)
			"gold":
				draw_rect(Rect2(8,22,24,10),gold)
				draw_rect(Rect2(12,14,16,10),Color("d6ac6f"))
			"corn", "flour":
				draw_circle(Vector2(16,24),8.0,Color("e2b66b") if kind=="corn" else Color("f3ead3"))
				draw_circle(Vector2(26,22),7.0,Color("c19357") if kind=="corn" else Color("d5c5a0"))
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
var _texture_cache: Dictionary = {}
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
var _build_filter: LineEdit
var _build_cards: Dictionary = {}
var _role_grid: GridContainer
var _role_filter: LineEdit
var _role_cards: Dictionary = {}
var _build_costs: Dictionary = {}
var _role_count_labels: Dictionary = {}
var _quantity := 1
var _training_queue: VBoxContainer
var _queue_signature := ""
var _queue_labels: Dictionary = {}
var _queue_bars: Dictionary = {}
var _resident_label: Label
var _training_school_id := -1
var _training_context: Label
var _menu: PanelContainer
var _menu_scroll: ScrollContainer
var _restart_confirm: VBoxContainer
var _help: PanelContainer
var _inspector: PanelContainer
var _inspector_scroll: ScrollContainer
var _inspected_id := -1
var _inspection_title: Label
var _inspection_description: Label
var _inspection_state: Label
var _inspection_connection: Label
var _inspection_progress: ProgressBar
var _inspection_details: Label
var _inspection_cancel: Button
var _recruit_melee: Button
var _recruit_ranged: Button
var _mode_panel: PanelContainer
var _mode_label: Label
var _road_toggle: Button
var _mode_type := ""
var _toast: PanelContainer
var _toast_label: Label
var _toast_timer: Timer
var _outcome: Label
var _layout_queued := false
var _credit_label: Label
var _menu_button: Button
var _tutorial_title: Label
var _tutorial_intro: Label
var _tutorial_more: Label
var _tutorial_button: Button
var _help_dock_button: Button
var _drawer_close: Button
var _quantity_caption: Label
var _training_cost_label: Label
var _training_queue_title: Label
var _inspect_close: Button
var _inspect_map: Button
var _menu_title: Label
const SAVE_SLOTS := 3
const SAVE_PATH := "user://vale-approved-save-v1.json"
var _save_button: Button
var _load_button: Button
var _save_dialog_dim: ColorRect
var _save_dialog: PanelContainer
var _save_dialog_title: Label
var _save_dialog_mode: String = "save"
var _slot_buttons: Dictionary = {}
var _lesson_button: Button
var _menu_help_button: Button
var _code_button: Button
var _restart_button: Button
var _restart_prompt: Label
var _restart_yes: Button
var _restart_back: Button
var _language_label: Label
var _language_buttons: Dictionary = {}
var _graphics_label: Label
var _graphics_buttons: Dictionary = {}
var _help_title: Label
var _help_close: Button
var _help_body: VBoxContainer
var _mode_cancel: Button

func setup(sim: RefCounted) -> void:
	_sim = sim
	if is_instance_valid(_root):
		refresh()
		return
	layer = 10
	_root = Control.new()
	_root.name = "ApprovedHUD"
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
	_make_save_dialog()
	_prewarm_texture_cache()
	get_viewport().size_changed.connect(_layout)
	_layout()
	refresh()

func _make_theme() -> Theme:
	var theme := Theme.new()
	# A fonte incorporada à engine é distribuível e idêntica no app e na Web.
	# Ela já usa fontes do sistema como reserva (allow_system_fallback), o que
	# cobre os glifos CJK da tradução chinesa no desktop sem alterar métricas.
	theme.default_font = ThemeDB.fallback_font
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Times New Roman", "Liberation Serif", "serif"])
	_serif = serif
	theme.default_font_size = 17
	theme.set_color("font_color", "Label", INK)
	theme.set_constant("separation", "HBoxContainer", 8)
	theme.set_constant("separation", "VBoxContainer", 8)
	theme.set_stylebox("normal", "Button", _paper_button_style())
	theme.set_stylebox("hover", "Button", _paper_button_style(Color(1.12,1.08,0.96)))
	theme.set_stylebox("pressed", "Button", _paper_button_style(Color(0.82,0.78,0.68)))
	theme.set_stylebox("focus", "Button", _focus_style())
	theme.set_stylebox("disabled", "Button", _paper_button_style(Color(0.7,0.7,0.68)))
	theme.set_color("font_color", "Button", INK_DARK)
	theme.set_color("font_hover_color", "Button", INK_DARK)
	theme.set_color("font_pressed_color", "Button", INK_DARK)
	theme.set_color("font_disabled_color", "Button", Color("8a7a5c"))
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

static var _paper_texture: Texture2D
func _panel(parent: Node, register_region: bool = true, padding: int = 14) -> PanelContainer:
	var panel := PanelContainer.new()
	if _paper_texture == null:
		_paper_texture = load("res://assets/approved/ui/paper_panel.png")
	var style := StyleBoxTexture.new()
	style.texture = _paper_texture
	style.texture_margin_left = 64;style.texture_margin_right = 64
	style.texture_margin_top = 44;style.texture_margin_bottom = 44
	style.content_margin_left = padding;style.content_margin_right = padding
	style.content_margin_top = padding;style.content_margin_bottom = padding
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

func _label(parent: Node, text: String = "", size: int = 17, color: Color = INK_DARK, wrap: bool = false) -> Label:
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
	button.custom_minimum_size = Vector2(min_width,54)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	parent.add_child(button)
	return button

## Torn-parchment banner (assets/approved/ui/paper_banner.png) 9-sliced for
## every button; `tint` multiplies it so hover/pressed/accent states reuse
## the one asset instead of needing separate art per state/color.
static var _paper_banner_texture: Texture2D
func _paper_button_style(tint: Color = Color.WHITE) -> StyleBoxTexture:
	if _paper_banner_texture == null:
		_paper_banner_texture = load("res://assets/approved/ui/paper_banner.png")
	var box := StyleBoxTexture.new()
	box.texture = _paper_banner_texture
	box.texture_margin_left = 34;box.texture_margin_right = 34
	box.texture_margin_top = 14;box.texture_margin_bottom = 14
	box.content_margin_left = 22;box.content_margin_right = 22
	box.content_margin_top = 14;box.content_margin_bottom = 14
	box.modulate_color = tint
	return box

func _accent(button: Button, color: Color = Color("08664e")) -> void:
	var tint := color.lightened(0.75)
	var ink := color.darkened(0.35)
	button.add_theme_stylebox_override("normal", _paper_button_style(tint))
	button.add_theme_stylebox_override("hover", _paper_button_style(tint.lightened(0.08)))
	button.add_theme_stylebox_override("pressed", _paper_button_style(tint.darkened(0.12)))
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)

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
	_brand = _label(_brand_box,"The Free Game",24)
	_credit_label = _label(_brand_box,"Lucas Marques, from Shiva",12,MUTED)
	for item in ["wood","stone","food","gold","trunks","loaves","population"]:
		var button := _button(row,"",_resource_info.bind(item),86)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = tr("{item}: toque para detalhes").format({"item":tr(ITEM_NAMES[item])})
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
		_resource_captions[item] = _label(values,tr(ITEM_NAMES[item]),11,MUTED)
		_resource_buttons[item] = button
	_menu_button = _button(row,tr("Menu"),_toggle_menu,66)
	_menu_button.tooltip_text = tr("Salvar, carregar, reiniciar e ajuda")

func _make_objectives() -> void:
	_objectives_panel = _panel(_root,true,12)
	_objectives_panel.name = "MissionPanel"
	var box := _vbox(_objectives_panel,7)
	_objectives_toggle = _button(box,tr("Objetivos  {done}/{total}  {mark}").format({"done":0,"total":3,"mark":"+"}),_toggle_objectives)
	_objectives_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_objectives_toggle.add_theme_stylebox_override("normal",_style(Color.TRANSPARENT,Color.TRANSPARENT,8,4))
	_objectives_toggle.add_theme_stylebox_override("hover",_style(Color.TRANSPARENT,Color.TRANSPARENT,8,4))
	_objectives_toggle.add_theme_stylebox_override("pressed",_style(Color.TRANSPARENT,Color.TRANSPARENT,8,4))
	for state in ["font_color","font_hover_color","font_pressed_color"]:
		_objectives_toggle.add_theme_color_override(state,INK_DARK)
	_objective_details = _vbox(box,9)
	_outcome = _label(_objective_details,tr("Um vale para chamar de seu"),19,WINE_DARK,true)
	for i in range(3):
		_objective_labels.append(_label(_objective_details,"",15,INK_DARK,true))
	_notice_label = _label(_objective_details,"",14,MUTED,true)
	_notice_label.add_theme_constant_override("line_spacing",2)
	_objective_details.hide()

func _make_tutorial() -> void:
	_tutorial = _panel(_root,true,14)
	_tutorial.name = "FirstDayHint"
	var box := _vbox(_tutorial,8)
	_tutorial_title = _label(box,tr("Primeiro, ligue a escola"),21,WINE_DARK)
	_tutorial_intro = _label(box,tr("Você começa com o Prédio principal, sua praça e a Escola de instrutores. Em Estradas, parta de uma borda da praça até a entrada da escola: 1 pedra por trecho."),15,INK_DARK,true)
	_tutorial_intro.max_lines_visible = 7
	_tutorial_more = _label(box,tr("Depois, construa lenhador, pedreira e horta. Clique na escola concluída para formar os profissionais."),14,MUTED,true)
	_tutorial_button = _button(box,tr("Entendi, vamos começar"),_dismiss_tutorial)
	_accent(_tutorial_button)

func _dismiss_tutorial() -> void:
	_tutorial_dismissed = true
	if is_instance_valid(_tutorial):
		_tutorial.hide()

func _cached_texture(path: String) -> Texture2D:
	if not _texture_cache.has(path):
		_texture_cache[path] = load(path) if ResourceLoader.exists(path,"Texture2D") else null
	return _texture_cache[path]

func _prewarm_texture_cache() -> void:
	for kind in _available_build_kinds():
		_cached_texture("res://assets/approved/previews/%s.png" % kind)
	for role in ["builder","servant","farmer","vintner","lumberjack","stonecutter","miller","baker","recruit","instructor"]:
		_cached_texture("res://assets/approved/people-previews/%s.png" % role)

func _thumbnail(parent: Node, kind: String, height: float = 56.0) -> void:
	var path := "res://assets/approved/previews/%s.png" % kind
	var texture := _cached_texture(path)
	if texture != null:
		var image := TextureRect.new()
		image.texture = texture
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
	var row := _hbox(_dock,22)
	_tabs["build"] = _button(row,tr("Construir"),_toggle_drawer.bind("build"),178)
	_tabs["road"] = _button(row,tr("Estradas"),_choose_road,140)
	_tabs["road"].tooltip_text = tr("Traçar ou apagar estradas · R · 1 pedra por trecho novo")
	_tabs["training"] = _button(row,tr("Ofícios"),_toggle_drawer.bind("training"),122)
	_tabs["training"].tooltip_text = tr("Formar profissionais · também disponível ao clicar em uma escola concluída")
	_tabs["army"] = _button(row,tr("Exército"),_choose_army,110)
	_tabs["army"].tooltip_text = tr("Clique no mapa para dar um objetivo à companhia")
	_tabs["objectives"] = _button(row,tr("Objetivos"),_toggle_objectives,122)
	_accent(_tabs["build"])
	_accent(_tabs["road"])
	_spacer(row)
	_village_focus = _button(row,tr("Vila"),_focus_village,70)
	_village_focus.tooltip_text = tr("Voltar ao centro da vila")
	_pause = _button(row,tr("Pausar"),func(): command_requested.emit("pause",{}),88)
	_speed_group = _hbox(row,14)
	for speed in [1,2,4]:
		_speed_buttons[speed] = _button(_speed_group,"%d×" % speed,_choose_speed.bind(speed),44)
	_speed_cycle = _button(row,"1×",_cycle_speed,48)
	_speed_cycle.tooltip_text = tr("Alternar velocidade: 1×, 2×, 4×")
	_help_dock_button = _button(row,"?",_show_help,44)
	_help_dock_button.tooltip_text = tr("Como jogar")

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
	_drawer_close = _button(heading,tr("Fechar"),close_panels,78)
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
	_build_cards.clear()
	_role_cards.clear()
	_role_count_labels.clear()
	_queue_labels.clear()
	_queue_bars.clear()
	_queue_signature = ""
	_build_grid = null
	_role_grid = null
	_training_queue = null
	_resident_label = null
	_training_context = null
	match kind:
		"build": _populate_build()
		"training": _populate_training()
	_drawer.visible = true
	_drawer_scroll.scroll_vertical = 0
	_layout()
	refresh()

func _populate_build() -> void:
	_drawer_title.text = tr("Dê espaço à sua vila")
	_drawer_subtitle.text = tr("Construa ao lado da estrada. Ligue a entrada marcada para liberar as entregas automáticas.")
	_build_filter = LineEdit.new()
	_build_filter.placeholder_text = tr("Filtrar construções…")
	_build_filter.clear_button_enabled = true
	_build_filter.add_theme_stylebox_override("normal",_style(PANEL.lightened(0.06),BRONZE.darkened(0.2),9,10))
	_build_filter.add_theme_stylebox_override("focus",_style(PANEL.lightened(0.06),BRONZE,9,10))
	_build_filter.add_theme_color_override("font_color",INK_DARK)
	_build_filter.add_theme_color_override("font_placeholder_color",MUTED)
	_build_filter.text_changed.connect(_filter_build_cards)
	_drawer_content.add_child(_build_filter)
	_build_grid = GridContainer.new()
	_build_grid.columns = 4
	_build_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_grid.add_theme_constant_override("h_separation",9)
	_build_grid.add_theme_constant_override("v_separation",9)
	_drawer_content.add_child(_build_grid)
	for kind in _available_build_kinds():
		var definition := _definition(kind)
		var button := _button(_build_grid,"",_choose_build.bind(kind))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 168
		button.tooltip_text = str(definition.get("description",tr(BUILD_HINTS[kind])))
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for edge in ["left","right","top","bottom"]:
			margin.add_theme_constant_override("margin_"+edge,10)
		button.add_child(margin)
		var card := _vbox(margin,4)
		_thumbnail(card,kind,76)
		var title := _label(card,tr(SHORT_NAMES[kind]),16 if kind == "training" else 19,WINE_DARK if kind == "winery" else INK_DARK,true)
		title.max_lines_visible = 2
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var cost_label := _label(card,_cost_text(definition.get("cost",{})),14,INK_DARK)
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_build_costs[kind] = cost_label
		_build_cards[kind] = button

func _filter_build_cards(query: String) -> void:
	var needle := query.strip_edges().to_lower()
	for kind in _build_cards:
		var button: Button = _build_cards[kind]
		button.visible = needle.is_empty() or tr(SHORT_NAMES[kind]).to_lower().contains(needle)

func _filter_role_cards(query: String) -> void:
	var needle := query.strip_edges().to_lower()
	for role in _role_cards:
		var button: Button = _role_cards[role]
		button.visible = needle.is_empty() or tr(ROLE_NAMES[role]).to_lower().contains(needle)

func _populate_training() -> void:
	_drawer_title.text = tr("Mais mãos para a vila")
	_drawer_subtitle.text = tr("Escolha profissão e quantidade. A escola conectada à estrada forma a equipe automaticamente.")
	_role_filter = LineEdit.new()
	_role_filter.placeholder_text = tr("Filtrar profissões…")
	_role_filter.clear_button_enabled = true
	_role_filter.add_theme_stylebox_override("normal",_style(PANEL.lightened(0.06),BRONZE.darkened(0.2),9,10))
	_role_filter.add_theme_stylebox_override("focus",_style(PANEL.lightened(0.06),BRONZE,9,10))
	_role_filter.add_theme_color_override("font_color",INK_DARK)
	_role_filter.add_theme_color_override("font_placeholder_color",MUTED)
	_role_filter.text_changed.connect(_filter_role_cards)
	_drawer_content.add_child(_role_filter)
	_training_context = _label(_drawer_content,"",15,MUTED,true)
	_training_context.hide()
	var settings := _hbox(_drawer_content)
	_resident_label = _label(settings,"",16,INK_DARK)
	_spacer(settings)
	_quantity_caption = _label(settings,tr("Quantidade"),15,MUTED)
	for qty in [1,3,5]:
		var btn := _button(settings,str(qty),_set_quantity.bind(qty),44)
		btn.name = "Quantity%d" % qty
		if qty == _quantity:
			_accent(btn)
	_training_cost_label = _label(_drawer_content,tr("Cada pessoa: 1 ouro · 50 s de formação em 1×"),14,MUTED)
	_role_grid = GridContainer.new()
	_role_grid.columns = 4
	_role_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_role_grid.add_theme_constant_override("h_separation",8)
	_role_grid.add_theme_constant_override("v_separation",8)
	_drawer_content.add_child(_role_grid)
	for role in ["builder","servant","farmer","vintner","lumberjack","stonecutter","miller","baker","recruit","instructor"]:
		var button := _button(_role_grid,"",_train_role.bind(role))
		_role_cards[role] = button
		button.custom_minimum_size.y = 96
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = tr("{detail}. Formação e trabalho automáticos.").format({"detail":tr(ROLE_DETAILS[role])})
		var row := _hbox(button,8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 7
		row.offset_right = -8
		row.offset_top = 5
		row.offset_bottom = -5
		var portrait_path := "res://assets/approved/people-previews/%s.png" % role
		var portrait_texture := _cached_texture(portrait_path)
		if portrait_texture != null:
			var portrait := TextureRect.new()
			portrait.texture = portrait_texture
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.custom_minimum_size = Vector2(54,80)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(portrait)
		var content := _vbox(row,2)
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_role_count_labels[role] = _label(content,tr(ROLE_NAMES[role]),17)
		_label(content,tr(ROLE_DETAILS[role]),12,MUTED,true)
		_label(content,tr("+ Formar"),13,WINE_DARK)
	_training_queue_title = _label(_drawer_content,tr("Fila de formação"),18)
	_training_queue = _vbox(_drawer_content,6)

func open_training(building: Dictionary) -> void:
	if not is_instance_valid(_root):
		return
	if building.get("kind","") != "training" or building.get("stage","") != "complete":
		inspect(building)
		return
	_dismiss_tutorial()
	# A map click opens the school even when the same drawer is already open.
	_drawer.hide()
	_toggle_drawer("training")
	_training_school_id = int(building.get("id",-1))
	entrance_highlighted.emit(building.get("entrance",Vector2i(-1,-1)))
	_refresh_school_context()
	_layout()

func _refresh_school_context() -> void:
	if not is_instance_valid(_training_context):
		return
	var school := _find_building(_training_school_id)
	var compact := _compact_layout()
	_training_context.visible = not school.is_empty() and not compact
	if school.is_empty():
		_drawer_subtitle.text = tr("Formação automática · {count} por pedido · 2 alimentos por pessoa").format({"count":_quantity}) if compact else tr("Escolha profissão e quantidade. A escola conectada à estrada forma a equipe automaticamente.")
		return
	_drawer_title.text = tr("Escola de instrutores")
	_drawer_subtitle.text = tr("Escolha quem formar. Os moradores vão estudar e assumem seus ofícios automaticamente.")
	var connected := bool(_sim.call("is_building_connected",school)) if _sim.has_method("is_building_connected") else false
	var context := tr("Escola conectada ao principal.")
	if not connected:
		context = tr("Falta uma estrada concluída entre esta escola e o principal.")
	elif int(school.get("worker",-1)) < 0:
		context += " "+tr("Aguardando um instrutor.")
	else:
		var ready := false
		var current_role := ""
		for course in _array(_sim.get("training")):
			if int(course.get("building",-1)) == int(school.id):
				current_role = str(course.get("role",""))
				break
		for worker in _array(_sim.get("workers")):
			if int(worker.get("id",-1)) == int(school.worker):
				ready = _array(worker.get("route",[])).is_empty()
				break
		if not current_role.is_empty():
			context += " "+tr("Formando {role}.").format({"role":tr(str(ROLE_NAMES.get(current_role,"profissional"))).to_lower()})
		else:
			context += " "+(tr("Instrutor pronto para ensinar.") if ready else tr("Instrutor a caminho."))
	_training_context.text = context+"\n"+tr("A fila é atendida pelas escolas disponíveis.")
	_training_context.add_theme_color_override("font_color",SUCCESS_DARK if connected else DANGER_DARK)
	if compact:
		var state := tr("Escola conectada") if connected else tr("Falta estrada até o principal")
		if connected and int(school.get("worker",-1)) < 0:
			state = tr("Aguardando instrutor")
		_drawer_subtitle.text = tr("{state} · fila compartilhada · {count} por pedido").format({"state":state,"count":_quantity})

func _set_quantity(qty: int) -> void:
	_quantity = qty
	# Recriar só a gaveta por ação explícita mantém foco e fila estáveis nos refreshes.
	var school := _find_building(_training_school_id)
	if not school.is_empty():
		open_training(school)
		return
	_drawer.visible = false
	_toggle_drawer("training")

func _train_role(role: String) -> void:
	command_requested.emit("train",{"role":role,"quantity":_quantity})
	refresh()

func _choose_road() -> void:
	_dismiss_tutorial()
	close_panels()
	_mode_type = "road"
	set_mode(tr("Estradas · arraste ou clique · 1 pedra/trecho · Esc para sair"))
	build_selected.emit("road")

func _choose_army() -> void:
	_dismiss_tutorial()
	close_panels()
	_mode_type = "army"
	set_mode(tr("Exército · clique no mapa para conquistar · Esc para sair"))
	build_selected.emit("army")

func _available_build_kinds() -> Array[String]:
	var kinds: Array[String] = []
	var spec: Variant = _sim.get("mission") if _sim != null else null
	for kind in BUILD_ORDER:
		if spec != null and spec.has_method("allows_building") and not spec.allows_building(kind):
			continue
		kinds.append(kind)
	return kinds

func _choose_build(kind: String) -> void:
	_dismiss_tutorial()
	close_panels()
	_mode_type = "build"
	set_mode(tr("{name} · toque no terreno para construir").format({"name":tr(str(SHORT_NAMES.get(kind,kind)))}))
	build_selected.emit(kind)

func _make_inspector() -> void:
	_inspector = _panel(_root,true,15)
	_inspector.name = "BuildingInspector"
	_inspector.visible = false
	var box := _vbox(_inspector,9)
	var row := _hbox(box)
	_inspection_title = _label(row,"",21,INK_DARK,true)
	_inspect_close = _button(row,"×",close_panels,44)
	_inspect_close.tooltip_text = tr("Fechar inspeção")
	_inspector_scroll = ScrollContainer.new()
	_inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_inspector_scroll)
	var content := _vbox(_inspector_scroll,9)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspection_description = _label(content,"",15,MUTED,true)
	_inspection_state = _label(content,"",17,WINE_DARK,true)
	_inspection_connection = _label(content,"",15,SUCCESS_DARK,true)
	_inspection_connection.max_lines_visible = 3
	_inspection_progress = ProgressBar.new()
	_inspection_progress.show_percentage = false
	_inspection_progress.custom_minimum_size.y = 8
	content.add_child(_inspection_progress)
	_inspection_details = _label(content,"",15,INK_DARK,true)
	var actions := _hbox(box)
	_inspect_map = _button(actions,tr("Ver no mapa"),_focus_inspected)
	_inspect_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspection_cancel = _button(actions,tr("Cancelar obra"),_cancel_inspected)
	_inspection_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspection_cancel.add_theme_color_override("font_color",DANGER_DARK)
	_inspection_cancel.tooltip_text = tr("Interromper esta obra e liberar os materiais que ainda não foram usados")
	_recruit_melee = _button(box, tr("Recrutar lanceiro (machado)"), func(): command_requested.emit("recruit", {"role": "lancer"}))
	_recruit_ranged = _button(box, tr("Recrutar arqueiro (arco)"), func(): command_requested.emit("recruit", {"role": "archer"}))

func inspect(building: Dictionary) -> void:
	if not is_instance_valid(_root):
		return
	close_panels()
	_inspected_id = int(building.get("id",-1))
	_inspector.visible = _inspected_id >= 0
	_inspector_scroll.scroll_vertical = 0
	if _inspector.visible:
		entrance_highlighted.emit(building.get("entrance",Vector2i(-1,-1)))
	_refresh_inspection()
	_layout()

func _focus_inspected() -> void:
	var building := _find_building(_inspected_id)
	if not building.is_empty():
		focus_requested.emit(building.get("entrance",Vector2i(8,13)))
		entrance_highlighted.emit(building.get("entrance",Vector2i(8,13)))

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
	_menu_title = _label(title_row,tr("Sua partida"),22)
	_spacer(title_row)
	_button(title_row,"×",close_panels,44)
	_menu_scroll = ScrollContainer.new()
	_menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_menu_scroll)
	var content := _vbox(_menu_scroll,8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_language_label = _label(content,tr("Idioma"),15,MUTED)
	var languages := _hbox(content,16)
	_language_buttons.clear()
	for code in Locale.SUPPORTED:
		var language_button := _button(languages,Locale.display_name(code),_choose_language.bind(code))
		language_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_language_buttons[code] = language_button
	_refresh_language_buttons()
	_graphics_label = _label(content,tr("Gráficos"),15,MUTED)
	var graphics_row := _hbox(content,16)
	_graphics_buttons.clear()
	_graphics_buttons[false] = _button(graphics_row,tr("Desempenho"),_choose_graphics.bind(false))
	_graphics_buttons[true] = _button(graphics_row,tr("Qualidade"),_choose_graphics.bind(true))
	for key in _graphics_buttons:
		_graphics_buttons[key].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refresh_graphics_buttons()
	_save_button = _button(content,tr("Salvar partida"),_open_save_dialog.bind("save"))
	_accent(_save_button)
	_load_button = _button(content,tr("Carregar partida"),_open_save_dialog.bind("load"))
	_lesson_button = _button(content,tr("Missão: primeira lição"),func():
		close_panels()
		command_requested.emit("load_mission", {"id": "tsk-01"})
	)
	_menu_help_button = _button(content,tr("Como jogar"),_show_help)
	_code_button = _button(content,tr("Código e artes do jogo ↗"),func(): OS.shell_open("https://github.com/LucasMarquesShiva/the-free-game"))
	_restart_button = _button(content,tr("Reiniciar partida"),_toggle_restart_confirmation)
	_restart_confirm = _vbox(content,7)
	_restart_confirm.visible = false
	_restart_prompt = _label(_restart_confirm,tr("Começar uma nova vila? O progresso atual que não foi salvo será perdido."),15,DANGER_DARK,true)
	var actions := _hbox(_restart_confirm)
	_restart_yes = _button(actions,tr("Reiniciar"),func():
		close_panels()
		set_mode("")
		restart_requested.emit()
	)
	_accent(_restart_yes,DANGER)
	_restart_back = _button(actions,tr("Voltar"),func(): _restart_confirm.hide())

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
	if opening:
		_close_save_dialog()
	_menu_scroll.scroll_vertical = 0
	_layout()

func _make_help() -> void:
	_help = _panel(_root,true,18)
	_help.name = "HelpPanel"
	_help.visible = false
	var box := _vbox(_help,10)
	var head := _hbox(box)
	_help_title = _label(head,tr("Bem-vindo ao vale"),24,WINE_DARK)
	_spacer(head)
	_help_close = _button(head,tr("Fechar"),close_panels,78)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_help_body = _vbox(scroll,12)
	_help_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fill_help(_help_body)

func _show_help() -> void:
	close_panels()
	_help.show()
	_layout()

func _help_entries() -> Array:
	return [
		[tr("1. Ligue as entradas"),tr("A vila começa com o Prédio principal, sua praça e a Escola de instrutores. Em Estradas (R), arraste ou clique a partir de uma borda da praça até a entrada da escola. Cada trecho novo custa 1 pedra. Na barra, Apagar trecho remove um por clique; a pedra reservada é liberada se a obra ainda não começou.")],
		[tr("2. Garanta os recursos"),tr("Construa lenhador, pedreira e horta e ligue suas entradas. Obras aguardam a estrada antes de receber materiais. Os serventes transportam apenas por caminhos concluídos; uma interrupção preserva a carga até a reconexão.")],
		[tr("3. Forme a equipe"),tr("Clique na escola concluída ou abra Ofícios. A escola gasta ouro entregue pelos serventes e forma civis novos. Construtores e serventes trabalham sozinhos.")],
		[tr("Taverna e comida"),tr("Os trabalhadores comem na taverna. Construa horta, moinho e padaria para pão; o vinho também serve de bebida.")],
		[tr("Exército"),tr("Construa o quartel, forme recrutas e entregue machados ou arcos. Em Exército, clique no mapa para dar um objetivo à companhia.")],
		[tr("Primeira lição"),tr("Menu → Missão: primeira lição trava a vinha e a horta até você ter escola, taverna, lenhador e pedreira.")],
		[tr("Câmera e atalhos"),tr("Arraste o terreno para mover a câmera; a roda do mouse aproxima. Q/E giram a visão. R inicia estradas; Esc encerra a colocação. Vila retorna ao principal. Pausar permite planejar; 1×, 2× e 4× ajustam o ritmo.")],
		[tr("Guarde sua partida"),tr("Menu → Salvar preserva sua vila. Use Carregar para retomar. Reiniciar pede confirmação antes de começar de novo.")]
	]

func _fill_help(content: VBoxContainer) -> void:
	_clear_children(content)
	for entry in _help_entries():
		_label(content,entry[0],19,INK_DARK,true)
		_label(content,entry[1],17,MUTED,true)

func _choose_language(code: String) -> void:
	if Locale.current() == code:
		return
	if not Locale.set_language(code):
		return
	_retranslate()
	show_message(tr("Idioma alterado para {language}.").format({"language":Locale.display_name(code)}))

func _refresh_language_buttons() -> void:
	var selected := Locale.current()
	for code in _language_buttons:
		var button: Button = _language_buttons[code]
		button.text = Locale.display_name(code)
		if code == selected:
			_accent(button)

func _choose_graphics(high_quality: bool) -> void:
	if GraphicsSettings.high_quality() == high_quality:
		return
	GraphicsSettings.set_high_quality(high_quality)
	_refresh_graphics_buttons()
	show_message(tr("Gráficos em {mode}. Carregue a vila novamente para aplicar por completo.").format({"mode":tr("Qualidade") if high_quality else tr("Desempenho")}))

static func _slot_path(slot: int) -> String:
	return SAVE_PATH if slot <= 1 else "user://vale-approved-save-slot%d.json" % slot

func _slot_text(slot: int) -> String:
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		var stamp := Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(path),true)
		return tr("Slot {slot} · salvo em {date}").format({"slot":slot,"date":stamp})
	return tr("Slot {slot} · vazio").format({"slot":slot})

func _make_save_dialog() -> void:
	_save_dialog_dim = ColorRect.new()
	_save_dialog_dim.name = "SaveDialogDim"
	_save_dialog_dim.color = Color(0,0,0,0.55)
	_save_dialog_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_save_dialog_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_save_dialog_dim.visible = false
	_save_dialog_dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_close_save_dialog()
	)
	_root.add_child(_save_dialog_dim)
	_regions.append(_save_dialog_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_save_dialog_dim.add_child(center)
	_save_dialog = _panel(center,false,18)
	_save_dialog.custom_minimum_size = Vector2(360,0)
	var box := _vbox(_save_dialog,10)
	var header := _hbox(box)
	_save_dialog_title = _label(header,"",22)
	_spacer(header)
	_button(header,"×",_close_save_dialog,44)
	_slot_buttons.clear()
	for slot in range(1,SAVE_SLOTS+1):
		_slot_buttons[slot] = _button(box,"",_pick_slot.bind(slot))

func _slot_dialog_title() -> String:
	return tr("Salvar em qual slot?") if _save_dialog_mode == "save" else tr("Carregar qual slot?")

func _open_save_dialog(mode: String) -> void:
	_save_dialog_mode = mode
	_save_dialog_title.text = _slot_dialog_title()
	for slot in _slot_buttons:
		_slot_buttons[slot].text = _slot_text(slot)
	_save_dialog_dim.visible = true

func _close_save_dialog() -> void:
	_save_dialog_dim.visible = false

func _pick_slot(slot: int) -> void:
	if _save_dialog_mode == "save":
		save_requested.emit(slot)
	else:
		load_requested.emit(slot)
	_close_save_dialog()

func _refresh_graphics_buttons() -> void:
	var selected := GraphicsSettings.high_quality()
	for key in _graphics_buttons:
		var button: Button = _graphics_buttons[key]
		if key == selected:
			_accent(button)
		else:
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_stylebox_override("hover")
			button.remove_theme_stylebox_override("pressed")
			button.remove_theme_color_override("font_color")
			button.remove_theme_color_override("font_hover_color")
			button.remove_theme_color_override("font_pressed_color")

func _retranslate() -> void:
	if not is_instance_valid(_root):
		return
	if is_instance_valid(_menu_button):
		_menu_button.text = tr("Menu")
		_menu_button.tooltip_text = tr("Salvar, carregar, reiniciar e ajuda")
	for item in _resource_buttons:
		var button: Button = _resource_buttons[item]
		button.tooltip_text = tr("{item}: toque para detalhes").format({"item":tr(ITEM_NAMES[item])})
		if _resource_captions.has(item):
			var caption: Label = _resource_captions[item]
			caption.text = tr(ITEM_NAMES[item])
	if is_instance_valid(_tutorial_title):
		_tutorial_title.text = tr("Primeiro, ligue a escola")
		_tutorial_intro.text = tr("Você começa com o Prédio principal, sua praça e a Escola de instrutores. Em Estradas, parta de uma borda da praça até a entrada da escola: 1 pedra por trecho.")
		_tutorial_more.text = tr("Depois, construa lenhador, pedreira e horta. Clique na escola concluída para formar os profissionais.")
		_tutorial_button.text = tr("Entendi, vamos começar")
	if _tabs.has("build"):
		_tabs["build"].text = tr("Construir")
		_tabs["road"].text = tr("Estradas")
		_tabs["road"].tooltip_text = tr("Traçar ou apagar estradas · R · 1 pedra por trecho novo")
		_tabs["training"].text = tr("Ofícios")
		_tabs["training"].tooltip_text = tr("Formar profissionais · também disponível ao clicar em uma escola concluída")
		if _tabs.has("army"):
			_tabs["army"].text = tr("Exército")
			_tabs["army"].tooltip_text = tr("Clique no mapa para dar um objetivo à companhia")
		_tabs["objectives"].text = tr("Objetivos")
	if is_instance_valid(_village_focus):
		_village_focus.text = tr("Vila")
		_village_focus.tooltip_text = tr("Voltar ao centro da vila")
	if is_instance_valid(_speed_cycle):
		_speed_cycle.tooltip_text = tr("Alternar velocidade: 1×, 2×, 4×")
	if is_instance_valid(_help_dock_button):
		_help_dock_button.tooltip_text = tr("Como jogar")
	if is_instance_valid(_drawer_close):
		_drawer_close.text = tr("Fechar")
	if is_instance_valid(_inspect_close):
		_inspect_close.tooltip_text = tr("Fechar inspeção")
	if is_instance_valid(_inspect_map):
		_inspect_map.text = tr("Ver no mapa")
	if is_instance_valid(_inspection_cancel):
		_inspection_cancel.text = tr("Cancelar obra")
		_inspection_cancel.tooltip_text = tr("Interromper esta obra e liberar os materiais que ainda não foram usados")
	if is_instance_valid(_recruit_melee):
		_recruit_melee.text = tr("Recrutar lanceiro (machado)")
	if is_instance_valid(_recruit_ranged):
		_recruit_ranged.text = tr("Recrutar arqueiro (arco)")
	if is_instance_valid(_menu_title):
		_menu_title.text = tr("Sua partida")
		_language_label.text = tr("Idioma")
		_save_button.text = tr("Salvar partida")
		_load_button.text = tr("Carregar partida")
		if is_instance_valid(_save_dialog_title):
			_save_dialog_title.text = _slot_dialog_title()
			for slot in _slot_buttons:
				_slot_buttons[slot].text = _slot_text(slot)
		if is_instance_valid(_lesson_button):
			_lesson_button.text = tr("Missão: primeira lição")
		_menu_help_button.text = tr("Como jogar")
		_code_button.text = tr("Código e artes do jogo ↗")
		_restart_button.text = tr("Reiniciar partida")
		_restart_prompt.text = tr("Começar uma nova vila? O progresso atual que não foi salvo será perdido.")
		_restart_yes.text = tr("Reiniciar")
		_restart_back.text = tr("Voltar")
	_refresh_language_buttons()
	if is_instance_valid(_help_title):
		_help_title.text = tr("Bem-vindo ao vale")
		_help_close.text = tr("Fechar")
	if is_instance_valid(_help_body):
		_fill_help(_help_body)
	if is_instance_valid(_mode_cancel):
		_mode_cancel.text = tr("Cancelar")
	if not _mode_type.is_empty():
		set_road_tool(_mode_type)
	if _drawer.visible:
		var kind := _drawer_kind
		var school_id := _training_school_id
		_drawer.visible = false
		_toggle_drawer(kind)
		if school_id >= 0:
			var school := _find_building(school_id)
			if not school.is_empty():
				open_training(school)
	language_changed.emit()
	refresh()

func _make_mode_and_toast() -> void:
	_mode_panel = _panel(_root,true,8)
	_mode_panel.name = "PlacementInstructions"
	_mode_panel.visible = false
	var mode_row := _hbox(_mode_panel)
	_mode_label = _label(mode_row,"",17,INK_DARK,true)
	_mode_label.max_lines_visible = 2
	_road_toggle = _button(mode_row,tr("Apagar trecho"),_toggle_road_tool,132)
	_road_toggle.visible = false
	_mode_cancel = _button(mode_row,tr("Cancelar"),_cancel_mode,88)
	_toast = _panel(_root,false,13)
	_toast.name = "FeedbackToast"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_toast_label = _label(_toast,"",17,INK_DARK,true)
	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.wait_time = 5.0
	_toast_timer.timeout.connect(func(): _toast.hide())
	add_child(_toast_timer)

func _cancel_mode() -> void:
	set_mode("")
	build_selected.emit("")

func set_road_tool(kind: String) -> void:
	_mode_type = kind if kind in ["road","remove_road"] else ""
	_road_toggle.visible = not _mode_type.is_empty()
	_road_toggle.text = tr("Traçar estrada") if kind == "remove_road" else tr("Apagar trecho")
	_road_toggle.tooltip_text = tr("Voltar a desenhar estradas") if kind == "remove_road" else tr("Apagar um trecho por clique; pedras reservadas de obras não iniciadas são liberadas")

func _toggle_road_tool() -> void:
	build_selected.emit("road" if _mode_type == "remove_road" else "remove_road")

func set_mode(text: String) -> void:
	if not is_instance_valid(_mode_panel):
		return
	_mode_label.text = text
	_mode_panel.visible = not text.is_empty()
	if text.is_empty():
		_mode_type = ""
		_road_toggle.visible = false
	_layout()

func show_message(text: String) -> void:
	if not is_instance_valid(_toast):
		return
	_toast_label.text = _profession_text(text)
	_toast.visible = not text.is_empty()
	_toast_timer.start()
	_layout()

func close_panels() -> void:
	entrance_highlighted.emit(Vector2i(-1,-1))
	for panel in [_drawer,_menu,_help,_inspector]:
		if is_instance_valid(panel):
			panel.hide()
	if is_instance_valid(_save_dialog_dim):
		_save_dialog_dim.hide()
	if is_instance_valid(_restart_confirm):
		_restart_confirm.hide()
	_drawer_kind = ""
	_training_school_id = -1

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
	focus_requested.emit(Vector2i(8,13))

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
	_pause.text = tr("Retomar") if bool(_sim.get("paused")) else tr("Pausar")
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
			label.add_theme_color_override("font_color",SUCCESS_DARK if complete else INK_DARK)
	_objectives_toggle.text = tr("Objetivos  {done}/{total}  {mark}").format({"done":done,"total":rows.size(),"mark":"−" if _objectives_open else "+"})
	_notice_label.text = _profession_text(str(_call_value("notice",tr("Os habitantes encontram trabalho sozinhos."))))
	_outcome.text = tr("Sua vila prosperou!") if bool(_sim.get("won")) else (tr("A vila precisa recomeçar") if bool(_sim.get("lost")) else tr("Um vale para chamar de seu"))
	if bool(_sim.get("lost")):
		_notice_label.text = tr("Abra Menu → Reiniciar para tentar uma nova partida.")
	elif bool(_sim.get("won")):
		_notice_label.text = tr("Todos os objetivos cumpridos. Você pode continuar observando a vila.")
	if _drawer.visible:
		for kind in _build_costs:
			var cost: Dictionary = _definition(kind).get("cost",{})
			var enough := true
			for item in cost:
				if _available(item) < int(cost[item]):
					enough = false
			var cost_label: Label = _build_costs[kind]
			cost_label.add_theme_color_override("font_color",INK_DARK if enough else DANGER_DARK)
		if _drawer_kind == "training":
			_refresh_school_context()
			_resident_label.text = tr("{count} moradores disponíveis").format({"count":int(counts.get("resident",0))})
			for role in _role_count_labels:
				var role_label: Label = _role_count_labels[role]
				role_label.text = tr("{role} · {count}").format({"role":tr(ROLE_NAMES[role]),"count":int(counts.get(role,0))})
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
			_label(_training_queue,tr("Nenhuma formação na fila. Os profissionais formados procuram trabalho automaticamente."),15,MUTED,true)
		for record in queue:
			var id := int(record.get("id",-1))
			var line := _hbox(_training_queue)
			var info := _vbox(line,3)
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_queue_labels[id] = _label(info,"",15,INK_DARK,true)
			var progress := ProgressBar.new()
			progress.show_percentage = false
			progress.custom_minimum_size.y = 5
			info.add_child(progress)
			_queue_bars[id] = progress
			_button(line,tr("Cancelar"),_cancel_training.bind(id),84)
	for record in queue:
		var id := int(record.get("id",-1))
		if _queue_labels.has(id):
			var label: Label = _queue_labels[id]
			var progress: ProgressBar = _queue_bars[id]
			label.text = tr("{role} · {reason}").format({"role":tr(str(ROLE_NAMES.get(record.get("role",""),"Profissional"))),"reason":_profession_text(str(record.get("reason",tr("Em formação"))))})
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
	_inspection_title.text = str(definition.get("name",tr("Construção")))
	_inspection_description.text = str(definition.get("description",""))
	var stage := str(building.get("stage",""))
	var complete := stage == "complete"
	var connected := bool(_sim.call("is_building_connected",building)) if _sim.has_method("is_building_connected") else false
	var main := str(building.get("kind","")) == "hall"
	_inspection_connection.text = tr("Entrada marcada · origem da rede de estradas") if main else (tr("Entrada marcada · conectada ao principal") if connected else tr("Entrada marcada · falta estrada até o principal"))
	_inspection_connection.add_theme_color_override("font_color",SUCCESS_DARK if connected else DANGER_DARK)
	var reason := str(building.get("reason",""))
	var states := {"preparing":tr("Preparando o terreno"),"materials":tr("Recebendo materiais"),"building":tr("Em construção"),"complete":tr("Concluída")}
	_inspection_state.text = _profession_text(reason if not reason.is_empty() else str(states.get(stage,stage)))
	_inspection_progress.value = 100.0 * float(building.get("production",0) if complete else building.get("progress",0))
	_inspection_progress.visible = not complete or not str(definition.get("profession","")).is_empty()
	var details: Array[String] = []
	if not complete:
		details = _construction_material_lines(building,definition,connected)
	else:
		var profession := str(definition.get("profession",""))
		if not profession.is_empty():
			var worker_id := int(building.get("worker",-1))
			var worker_state := tr("Aguardando profissional") if worker_id < 0 else tr("Em atividade")
			for worker in _array(_sim.get("workers")):
				if int(worker.get("id",-1)) == worker_id:
					worker_state = str(worker.get("state",worker_state))
					break
			details.append(tr("{role} · {state}").format({"role":tr(str(ROLE_NAMES.get(profession,profession))),"state":worker_state}))
		for key in ["input","output"]:
			var inventory: Dictionary = building.get(key,{})
			for item in inventory:
				if int(inventory[item]) > 0:
					details.append(tr("{kind}: {amount} {item}").format({"kind":tr("Entrada") if key == "input" else tr("Para retirar"),"amount":int(inventory[item]),"item":tr(str(ITEM_NAMES.get(item,item))).to_lower()}))
		if str(building.get("kind","")) == "house":
			details.append(tr("Abrigo civil. Novos habitantes saem da escola."))
		elif str(building.get("kind","")) == "farm" and _sim.has_method("crop_status"):
			var crop := _dictionary(_sim.call("crop_status",building))
			if not crop.is_empty():
				_inspection_state.text = _profession_text(str(crop.get("label",tr("Cultivando a horta"))))
				var crop_progress := clampf(float(crop.get("progress",0)),0,1)
				_inspection_progress.value = crop_progress*100.0
				details.append(tr("Ciclo da horta: {percent}% · colheita de {amount} alimentos").format({"percent":roundi(crop_progress*100),"amount":int(crop.get("output_amount",8))}))
				if not bool(crop.get("active",false)) and not str(crop.get("reason","")).is_empty():
					details.append(tr("Cultivo pausado: {reason}").format({"reason":str(crop.reason)}))
	_inspection_details.text = _profession_text("\n".join(details))
	_inspection_cancel.visible = not complete and not bool(building.get("initial",false))
	var barracks := complete and str(building.get("kind","")) == "barracks"
	if is_instance_valid(_recruit_melee):
		_recruit_melee.visible = barracks
	if is_instance_valid(_recruit_ranged):
		_recruit_ranged.visible = barracks
	var content := _inspection_details.get_parent()
	content.move_child(_inspection_details,0 if _compact_layout() and not complete else content.get_child_count()-1)

func _construction_material_lines(building: Dictionary, definition: Dictionary, connected: bool) -> Array[String]:
	var compact := _compact_layout()
	var lines: Array[String] = [tr("Entregues / necessários") if compact else tr("Materiais · entregues / necessários")]
	var quantities: Array[String] = []
	var costs: Dictionary = definition.get("cost",{})
	var delivered: Dictionary = building.get("delivered",{})
	var applying: bool = building.get("stage","") == "building"
	var missing := false
	for item in costs:
		var required := int(costs[item])
		# The simulation consumes delivered materials when construction starts.
		# A zero remaining inventory then means 'applied', not 'never delivered'.
		var received := required if applying else int(delivered.get(item,0))
		quantities.append(tr("{item}: {received} / {required}").format({"item":tr(str(ITEM_NAMES.get(item,item))),"received":received,"required":required}))
		missing = missing or received < required
	if compact:
		lines.append(" · ".join(quantities))
	else:
		lines.append_array(quantities)
	if applying:
		lines.append(tr("Já entregues e aplicados na obra."))
		return lines
	var carrying: Dictionary = {}
	var picking_up := 0
	var servants := 0
	for worker in _array(_sim.get("workers")):
		if worker.get("role","") == "servant":
			servants += 1
		var task: Dictionary = worker.get("task",{})
		if task.get("type","") != "delivery" or int(task.get("building",-1)) != int(building.id):
			continue
		var cargo: Dictionary = worker.get("cargo",{})
		if not cargo.is_empty():
			var item := str(cargo.get("item",""))
			carrying[item] = int(carrying.get(item,0))+int(cargo.get("amount",0))
		elif task.get("phase","") == "pickup":
			picking_up += 1
	if not carrying.is_empty():
		lines.append(tr("Nas mãos dos serventes: {cargo}.").format({"cargo":_cost_text(carrying)}))
	if picking_up > 0:
		lines.append(tr("{count} retirada(s) no depósito em andamento.").format({"count":picking_up}))
	if not connected:
		lines.append(tr("Entregas aguardam estrada concluída até a entrada."))
	elif building.get("stage","") == "preparing":
		lines.append(tr("Entregas começam após preparar o terreno."))
	elif not missing:
		lines.append(tr("Materiais entregues. Aguardando construtor."))
	elif servants == 0:
		lines.append(tr("Forme serventes na escola para trazer os materiais."))
	elif carrying.is_empty() and picking_up == 0:
		lines.append(tr("Serventes trazem os materiais pela estrada, conforme ficam disponíveis."))
	return lines

func _profession_text(text: String) -> String:
	return text.replace("Agricultor","Horticultor").replace("agricultor","horticultor")

func _compact_layout() -> bool:
	var viewport := get_viewport().get_visible_rect().size
	return viewport.x < 1180.0 or viewport.y < 520.0

func _resource_info(item: String) -> void:
	if item == "population":
		var counts := _call_dictionary("profession_counts")
		show_message(tr("{count} moradores disponíveis para formação. Casas e alimentos atraem mais habitantes.").format({"count":int(counts.get("resident",0))}))
	else:
		var stock := _dictionary(_sim.get("stock")) if _sim != null else {}
		var reserved := int(stock.get(item,0))-_available(item)
		show_message(tr("{item} no depósito principal: {stock} · livres: {free} · reservados: {reserved}. Cargas e produção nos prédios ficam fora deste total.").format({"item":tr(str(ITEM_NAMES.get(item,item))),"stock":int(stock.get(item,0)),"free":_available(item),"reserved":reserved}))

func _available(item: String) -> int:
	if _sim != null and _sim.has_method("available"):
		return int(_sim.call("available",item))
	return int(_dictionary(_sim.get("stock")).get(item,0)) if _sim != null else 0

func _definition(kind: String) -> Dictionary:
	if _sim != null and _sim.has_method("definition"):
		var value := _dictionary(_sim.call("definition",kind)).duplicate(true)
		if kind == "hall": value.name = tr("Prédio principal")
		if kind == "training": value.name = tr("Escola de instrutores")
		# The controller runs the fixed simulation clock at CIVIL_PACE=0.4 in1×.
		# Keep the shared simulation definitions unchanged for previous versions.
		var descriptions := {
			"lumber":"Um lenhador produz 4 madeiras a cada 20 segundos em 1×.",
			"quarry":"Um canteiro extrai 3 pedras a cada 25 segundos em 1×.",
			"farm":"Um horticultor cultiva 8 alimentos a cada 25 segundos em 1×.",
			"vineyard":"Um vinhateiro colhe 4 uvas a cada 30 segundos em 1×.",
			"winery":"Um vinhateiro transforma 3 uvas em 2 vinhos a cada 25 segundos em 1×."
		}
		if descriptions.has(kind):value.description = tr(descriptions[kind])
		return value
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
			parts.append(tr("{count} {item}").format({"count":int(cost[item]),"item":tr(ITEM_NAMES[item]).to_lower()}))
	return " · ".join(parts) if not parts.is_empty() else tr("Sem custo")

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
	var compact := width < 1180.0 or height < 520.0
	var margin := 12.0 if compact else 18.0
	var top_height := 65.0 if compact else 73.0
	_top.position = Vector2(margin,margin)
	_top.size = Vector2(width-margin*2,top_height)
	_brand_box.custom_minimum_size.x = 145.0 if compact else 182.0
	_brand_box.visible = width >= 900.0
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
	_tabs["build"].custom_minimum_size.x = 116.0 if compact else 160.0
	_tabs["road"].custom_minimum_size.x = 116.0 if compact else 160.0
	_tabs["training"].custom_minimum_size.x = 91.0 if compact else 122.0
	if _tabs.has("army"):
		_tabs["army"].custom_minimum_size.x = 88.0 if compact else 110.0
		_tabs["army"].visible = width >= 980.0
	_tabs["objectives"].custom_minimum_size.x = 102.0 if compact else 122.0
	_tabs["objectives"].visible = width >= 960.0
	_village_focus.visible = width >= 860.0
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
	var drawer_height := minf(440.0,maxf(150.0,height-top_height-margin*3-79.0))
	var drawer_width := minf(1160.0,width-margin*2)
	_drawer.position = Vector2((width-drawer_width)*0.5,height-margin-74-drawer_height)
	_drawer.size = Vector2(drawer_width,drawer_height)
	if is_instance_valid(_build_grid):
		_build_grid.columns = 4
	if is_instance_valid(_role_grid):
		_role_grid.columns = 3 if compact else 4
		# On short screens, the primary profession actions must be visible
		# immediately; quantity and price details remain in the same scroll area.
		_drawer_content.move_child(_role_grid,0 if compact else 3)
		for card: Button in _role_grid.get_children():
			card.custom_minimum_size.y = 64 if compact else 96
			for child in card.get_child(0).get_children():
				if child is TextureRect:
					child.custom_minimum_size = Vector2(36,48) if compact else Vector2(54,80)
		for role in _role_count_labels:
			var content: Node = _role_count_labels[role].get_parent()
			content.get_child(1).visible = not compact
		_refresh_school_context()
	_inspector.position = Vector2(width-margin-(308 if compact else 338),margin+top_height+12)
	_inspector_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if compact else ScrollContainer.SCROLL_MODE_DISABLED
	_inspector.size = Vector2(308 if compact else 338,maxf(160.0,height-_inspector.position.y-margin-74.0) if compact else 0.0)
	_inspection_description.visible = not compact
	_refresh_inspection()
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
