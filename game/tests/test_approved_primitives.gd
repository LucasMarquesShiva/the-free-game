extends SceneTree
const Primitives = preload("res://presentation/approved_primitives.gd")
var checks := 0
func verify(condition: bool, description: String) -> void:
 assert(condition,description)
 checks += 1
func _initialize() -> void:
 var roof := Primitives.Batch.new(912)
 Primitives._roof(roof,Vector3.ZERO,4.2,3.2,1.9)
 verify(not roof.tiles.is_empty(),"O telhado gera telhas individuais")
 for transform in roof.tiles:
  verify(transform.basis.determinant() > 0.0,"Base da telha sem espelhamento")
  verify(transform.basis.x.y < -0.01,"X local sempre aponta para baixo da água")
  verify(transform.basis.x.x*transform.origin.x > 0.0,"Bordo sobreposto aponta para fora da cumeeira")
 var upper := Primitives._tile_point(0.0,0.5)
 var lower := Primitives._tile_point(1.0,0.5)
 verify(lower.y-upper.y > 0.060,"Lábio tem folga física para a telha seguinte")
 var tile := Primitives._roof_tile()
 var arrays := tile.surface_get_arrays(0)
 verify(arrays[Mesh.ARRAY_COLOR].size() == arrays[Mesh.ARRAY_VERTEX].size(),"Bordas possuem pigmento próprio")
 verify(tile == Primitives._roof_tile(),"Telhas compartilham uma única malha")
 var size := Vector3(0.20,4.0,0.20)
 var beam := Primitives._rounded_box(size,0.02)
 verify(beam.get_aabb().size.is_equal_approx(size),"Arredondamento mantém dimensão física")
 verify(beam == Primitives._rounded_box(size,0.02),"Vigas idênticas compartilham malha")
 var smooth := false
 for normal in beam.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]:
  if absf(normal.x)>0.1 and absf(normal.y)>0.1: smooth=true
 verify(smooth,"Cantos possuem normais curvas")
 print("APPROVED_PRIMITIVES_PASS ",checks," checks")
 quit()
