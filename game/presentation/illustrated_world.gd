extends Node2D
## Fixed-angle illustrated village. The simulation owns all people and materials.
const TILE := Vector2(64,32)
const CUTOUT = preload("res://assets/illustrated/paper_cutout.gdshader")
const TYPES := ["hall","house","store","training","lumber","quarry","farm","vineyard","winery"]
var sim: RefCounted
var camera: Camera2D
var layer: Node2D
var terrain: Node2D
var textures := {}
var buildings := {}
var people := {}
var decorations: Array[Node2D] = []
var preview: Sprite2D
var preview_kind := ""
var preview_cell := Vector2i(-1,-1)
var preview_valid := false
var selected_id := -1
var art_material: ShaderMaterial
var elapsed := 0.0
var road_cells := {}
var count_seen := -1
var zoom_level := 1.32
var image_cache := {}

class Terrain extends Node2D:
 var owner_world: Node2D
 func _draw() -> void:
  var w = owner_world
  if w.textures.has("grass_v2"):
   draw_texture_rect(w.textures.grass_v2,Rect2(-3000,-1000,6000,4000),true,Color(0.75,0.88,0.80))
  var map := PackedVector2Array([w.project(Vector2(0,0)),w.project(Vector2(36,0)),w.project(Vector2(36,28)),w.project(Vector2(0,28))])
  draw_colored_polygon(map,Color("758050"))
  if w.textures.has("grass"):
   var uv := PackedVector2Array([Vector2(0,0),Vector2(6,0),Vector2(6,4.66),Vector2(0,4.66)])
   draw_polygon(map,PackedColorArray([Color(0.96,1.0,0.96)]),uv,w.textures.grass_v2)
  for y in range(28):
   var river: PackedVector2Array = w.diamond_rect(Vector2(22,y),Vector2(3,1))
   draw_colored_polygon(river,Color("477361"))
   var inner: PackedVector2Array = w.diamond_rect(Vector2(22.20,y),Vector2(2.60,1))
   draw_colored_polygon(inner,Color("2d7e87"))
   for i in range(4):
    var p: Vector2 = w.project(Vector2(22.45+i*0.54,y+0.44))
    draw_line(p,p+Vector2(7,-3),Color(0.67,0.86,0.77,0.33),1.3,true)
  for key in w.road_cells:
   var cell: Vector2 = Vector2(key)
   var road: PackedVector2Array=w.diamond_rect(cell,Vector2.ONE)
   if w.textures.has("road"):
    var uv := PackedVector2Array([cell/3.0,(cell+Vector2(1,0))/3.0,(cell+Vector2.ONE)/3.0,(cell+Vector2(0,1))/3.0])
    draw_polygon(road,PackedColorArray([Color(0.94,0.94,0.85)]),uv,w.textures.road)
   else:draw_colored_polygon(road,Color("a69973"))
  for y in range(13,16):
   draw_colored_polygon(w.diamond_rect(Vector2(21.8,y),Vector2(3.4,1)),Color("805a34"))
   for n in range(11):
    draw_line(w.project(Vector2(21.85+n*0.3,y)),w.project(Vector2(21.85+n*0.3,y+1)),Color("c4985a"),5.0,true)
  draw_polyline(PackedVector2Array([map[0],map[1],map[2],map[3],map[0]]),Color(0.64,0.68,0.42,0.45),3,true)

class Markers extends Node2D:
 var owner_world: Node2D
 func _draw() -> void:
  var w = owner_world
  if w.preview_cell.x>=0 and not w.preview_kind.is_empty():
   var line: PackedVector2Array = w.diamond_rect(Vector2(w.preview_cell),Vector2(2,2))
   draw_colored_polygon(line,Color(0.35,0.74,0.58,0.35) if w.preview_valid else Color(0.88,0.24,0.17,0.38))
   line.append(line[0])
   draw_polyline(line,Color("d4e8a5") if w.preview_valid else Color("ed8261"),2.5,true)
  if w.selected_id>=0:
   for b in w.sim.buildings:
    if b.id==w.selected_id:
     var line: PackedVector2Array = w.diamond_rect(Vector2(b.cell),Vector2(2,2));line.append(line[0])
     draw_polyline(line,Color("f5cf77"),3.0,true)

var markers: Node2D

func project(cell: Vector2) -> Vector2:
 return Vector2((cell.x-cell.y)*32.0,(cell.x+cell.y)*16.0)

func diamond_rect(cell: Vector2, extent: Vector2) -> PackedVector2Array:
 return PackedVector2Array([project(cell),project(cell+Vector2(extent.x,0)),project(cell+extent),project(cell+Vector2(0,extent.y))])

func setup(village: RefCounted) -> void:
 sim=village
 art_material=ShaderMaterial.new();art_material.shader=CUTOUT
 for kind in TYPES+["grass","grass_v2","workers","decor","road"]:
  var path: String="res://assets/illustrated/"+kind+".png"
  if ResourceLoader.exists(path): textures[kind]=load(path)
 RenderingServer.set_default_clear_color(Color("263e34"))
 terrain=Terrain.new();terrain.owner_world=self;terrain.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED;add_child(terrain)
 markers=Markers.new();markers.owner_world=self;add_child(markers)
 layer=Node2D.new();layer.y_sort_enabled=true;add_child(layer)
 preview=Sprite2D.new();preview.material=art_material;preview.z_index=3000;add_child(preview)
 camera=Camera2D.new();camera.position_smoothing_enabled=false;camera.zoom=Vector2.ONE*zoom_level;add_child(camera);camera.make_current()
 focus_cell(Vector2i(8,11))
 _make_decorations()
 sync(0)

func _sprite(kind: String, width: float, base := 0.92) -> Sprite2D:
 var sprite:=Sprite2D.new()
 if textures.has(kind):
  sprite.texture=textures[kind]
  sprite.scale=Vector2.ONE*width/sprite.texture.get_width()
  sprite.offset=Vector2(0,sprite.texture.get_height()*(0.5-base))
  if kind!="grass" and kind!="decor":sprite.material=art_material
 return sprite

func _atlas(kind: String, index: int, height: float) -> Sprite2D:
 var sprite:=Sprite2D.new()
 if not textures.has(kind):return sprite
 var tex: Texture2D=textures[kind]
 var size:=tex.get_size()
 var region:=Rect2(Vector2(index%2,index/2)*size/2.0,size/2.0)
 if kind=="decor":
  var split:=0.625
  region=Rect2(Vector2(float(index%2)*size.x/2.0,0 if index<2 else size.y*split),Vector2(size.x/2.0,size.y*(split if index<2 else 1.0-split)))
 var atlas:=AtlasTexture.new();atlas.atlas=tex;atlas.region=region;atlas.filter_clip=true
 sprite.texture=atlas;sprite.scale=Vector2.ONE*height/region.size.y
 sprite.offset=Vector2(0,-region.size.y*0.42)
 if kind=="workers":sprite.material=art_material
 return sprite

func _make_decorations() -> void:
 var rng:=RandomNumberGenerator.new();rng.seed=43821
 for i in range(210):
  var c:=Vector2(rng.randf_range(-2,37),rng.randf_range(-2,29))
  # Keep the player's starting village and its expansion area unobstructed.
  if c.x>1 and c.x<21 and c.y>2 and c.y<25:continue
  if c.x>21 and c.x<26:continue
  if c.x>26 and c.x<34 and c.y>6 and c.y<22 and i%3!=0:continue
  var index:=0 if i%3==0 else (1 if i%3==1 else 3)
  var tree:=_atlas("decor",index,rng.randf_range(105,185))
  tree.position=project(c);layer.add_child(tree);decorations.append(tree)
 for c in [Vector2(1,7),Vector2(1,12),Vector2(2,23),Vector2(12,24),Vector2(19,23),Vector2(18,2),Vector2(20,9)]:
  var rock:=_atlas("decor",2,48);rock.position=project(c);layer.add_child(rock);decorations.append(rock)

func _roads() -> void:
 road_cells.clear()
 var origin:=Vector2i(8,12)
 for b in sim.buildings:
  if b.stage=="cancelled":continue
  var entrance: Vector2i=b.cell+Vector2i(0,2)
  var path: Array=sim.find_path(origin,entrance)
  for c in path:road_cells[c]=true
  road_cells[entrance]=true
 terrain.queue_redraw()

func sync(delta: float) -> void:
 elapsed+=delta
 if sim.buildings.size()!=count_seen:
  count_seen=sim.buildings.size();_roads()
 for b in sim.buildings:
  if not buildings.has(b.id):
   var node:=Node2D.new();node.position=project(Vector2(b.cell)+Vector2(1,1.55));layer.add_child(node)
   var sprite:=_sprite(b.kind,210.0 if b.kind!="hall" else 228.0)
   sprite.name="Art";node.add_child(sprite)
   var progress:=ProgressBar.new();progress.name="Progress";progress.size=Vector2(80,6);progress.position=Vector2(-40,3);progress.show_percentage=false;progress.mouse_filter=Control.MOUSE_FILTER_IGNORE;node.add_child(progress)
   var label:=Label.new();label.name="State";label.position=Vector2(-95,10);label.size=Vector2(190,20);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",11);label.add_theme_color_override("font_outline_color",Color("18332a"));label.add_theme_constant_override("outline_size",4);node.add_child(label)
   buildings[b.id]=node
  var visual: Node2D=buildings[b.id]
  visual.visible=b.stage!="cancelled"
  var complete: bool=b.get("stage","")=="complete"
  visual.get_node("Art").modulate=Color.WHITE if complete else Color(0.84,0.85,0.70,0.48)
  visual.get_node("Progress").visible=not complete
  visual.get_node("State").visible=not complete or b.id==selected_id
  visual.get_node("State").text=sim.definition(b.kind).name if complete else _site_text(b)
  visual.get_node("Progress").value=float(b.get("progress",0))*100.0
 var present:={}
 for w in sim.workers:
  present[w.id]=true
  var role: String=w.role
  var index:=1 if role=="servant" else (2 if role in ["builder","lumberjack","stonecutter"] else (3 if role in ["farmer","vintner"] else 0))
  if not people.has(w.id):
   var person:=Node2D.new();person.position=project(Vector2(w.cell)+Vector2(0.5,0.5));layer.add_child(person)
   var art:=_atlas("workers",index,39.0);art.name="Art";person.add_child(art)
   var cargo:=Label.new();cargo.name="Cargo";cargo.position=Vector2(6,-22);cargo.add_theme_font_size_override("font_size",12);cargo.add_theme_color_override("font_outline_color",Color("18332a"));cargo.add_theme_constant_override("outline_size",3);person.add_child(cargo)
   person.set_meta("role",role);people[w.id]=person
  var person: Node2D=people[w.id]
  if person.get_meta("role")!=role:
   var old: Sprite2D=person.get_node("Art");person.remove_child(old);old.queue_free()
   var art:=_atlas("workers",index,39.0);art.name="Art";person.add_child(art);person.set_meta("role",role)
  var target:=project(Vector2(w.cell)+Vector2(0.5,0.5))
  var movement:=target-person.position
  person.position=person.position.lerp(target,minf(1,delta*13.0)) if delta>0 else target
  var walking: bool = movement.length()>0.2 and not sim.paused
  var art: Sprite2D=person.get_node("Art")
  art.position.y=-absf(sin(elapsed*11+w.id))*1.6 if walking else 0.0
  if absf(movement.x)>0.3:art.flip_h=movement.x<0
  var load_amount: int=int(w.get("cargo",{}).get("amount",0)) if w.get("cargo") is Dictionary else int(w.get("amount",0))
  person.get_node("Cargo").text="+"+str(load_amount) if load_amount>0 else ""
 for id in people.keys():
  if not present.has(id):people[id].queue_free();people.erase(id)
 markers.queue_redraw()

func _site_text(b: Dictionary) -> String:
 match str(b.get("stage","")):
  "preparing":return "Preparando a obra"
  "materials":return "Recebendo materiais"
  "building":return "Construindo"
 return "Obra em andamento"

func cell_to_screen(cell: Vector2) -> Vector2:
 return get_canvas_transform()*project(cell)

func screen_to_cell(point: Vector2) -> Vector2i:
 var p:=get_canvas_transform().affine_inverse()*point
 var cell:=Vector2i(floori(p.x/64.0+p.y/32.0),floori(p.y/32.0-p.x/64.0))
 return cell if cell.x>=0 and cell.y>=0 and cell.x<36 and cell.y<28 else Vector2i(-1,-1)

func building_at_screen(point: Vector2) -> Dictionary:
 var candidates: Array=sim.buildings.duplicate()
 candidates.sort_custom(func(a,b):return a.cell.x+a.cell.y>b.cell.x+b.cell.y)
 for b in candidates:
  if b.stage=="cancelled" or not buildings.has(b.id):continue
  var sprite: Sprite2D=buildings[b.id].get_node("Art")
  if sprite.texture==null:continue
  var local:=sprite.get_global_transform_with_canvas().affine_inverse()*point
  var rect:=sprite.get_rect()
  if not rect.has_point(local):continue
  if not image_cache.has(b.kind):image_cache[b.kind]=sprite.texture.get_image()
  var im: Image=image_cache[b.kind]
  var pixel:=Vector2i((local-rect.position)/rect.size*Vector2(im.get_size()))
  var col:=im.get_pixelv(pixel.clamp(Vector2i.ZERO,im.get_size()-Vector2i.ONE))
  var high:=maxf(col.r,maxf(col.g,col.b));var low:=minf(col.r,minf(col.g,col.b))
  if col.a>0.1 and not (low>0.74 and high-low<0.10):return b
 return sim.building_at(screen_to_cell(point))

func focus_cell(cell: Vector2i) -> void:
 camera.position=project(Vector2(cell))+Vector2(0,-30)

func zoom_by(amount: float) -> void:
 zoom_level=clampf(zoom_level*exp(-amount*0.055),0.55,2.4)
 camera.zoom=Vector2.ONE*zoom_level

func pan_by(delta: Vector2) -> void:
 camera.position-=delta/zoom_level
 camera.position=camera.position.clamp(Vector2(-1000,100),Vector2(1100,1000))

func set_preview(kind: String, cell: Vector2i, valid: bool) -> void:
 preview_kind=kind;preview_cell=cell;preview_valid=valid
 preview.visible=cell.x>=0 and textures.has(kind)
 if preview.visible:
  preview.texture=textures[kind];preview.scale=Vector2.ONE*210.0/preview.texture.get_width();preview.offset=Vector2(0,-preview.texture.get_height()*0.42)
  preview.position=project(Vector2(cell)+Vector2(1,1.55));preview.modulate=Color(0.9,1,0.87,0.65) if valid else Color(1,0.45,0.35,0.55)
 markers.queue_redraw()

func clear_preview() -> void:
 preview_kind="";preview_cell=Vector2i(-1,-1)
 if preview!=null:preview.visible=false
 if markers!=null:markers.queue_redraw()

func set_selected(id: int) -> void:
 selected_id=id
