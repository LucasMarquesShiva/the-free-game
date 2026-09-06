shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform sampler2D material_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 quadrant=vec2(0.0);
uniform vec2 texture_scale=vec2(1.0);
uniform float surface_roughness=0.9;
uniform float roughness_variation=0.0;
uniform float brightness=1.0;
uniform float detail_strength=0.0;
uniform float chroma_strength=0.0;
uniform float bump_height=0.0;
uniform float pigment_depth=1.0;
uniform bool warm_pigments_only=false;
uniform float cutoff_height=1000.0;
varying vec4 vertex_tint;
varying float world_height;
void vertex(){vertex_tint=COLOR;world_height=(MODEL_MATRIX*vec4(VERTEX,1.0)).y;}
void fragment(){
 if(world_height>cutoff_height)discard;
 vec2 tiled_uv=UV*texture_scale;
 vec2 uv=quadrant+vec2(0.006)+fract(tiled_uv)*0.488;
 // Gradientes antes de fract evitam saltos de mip nas bordas dos ladrilhos.
 vec3 pigment=textureGrad(material_atlas,uv,dFdx(tiled_uv)*0.488,dFdy(tiled_uv)*0.488).rgb;
 float mean_level=max(0.0,log2(float(textureSize(material_atlas,0).x))-3.0);
 vec3 mean_pigment=textureLod(material_atlas,quadrant+vec2(0.25),mean_level).rgb;
 float grain=dot(pigment,vec3(0.2126,0.7152,0.0722));
 float mean_grain=max(0.015,dot(mean_pigment,vec3(0.2126,0.7152,0.0722)));
 float relief=clamp(grain/mean_grain,0.45,1.60)-1.0;
 vec3 paint=vertex_tint.rgb;
 bool warm=paint.r>paint.g*1.12 && paint.g>paint.b*1.12;
 bool teal=paint.g>paint.r*1.20 && paint.b>paint.r*1.08;
 if(!warm_pigments_only || warm)paint*=pigment_depth;
 if(!OUTPUT_IS_SRGB)paint=pow(paint,vec3(2.2));
 // A cor do atlas varia apenas dentro do pigmento aprovado, sem substituí-lo.
 vec3 relative_chroma=(pigment/max(grain,0.015))/(mean_pigment/mean_grain);
 relative_chroma=clamp(relative_chroma,vec3(0.84),vec3(1.16));
 float paint_detail=teal?0.20:1.0;
 float detail=clamp(1.0+relief*detail_strength*paint_detail,0.66,1.34);
 ALBEDO=paint*brightness*detail*mix(vec3(1.0),relative_chroma,chroma_strength*paint_detail);
 ROUGHNESS=clamp(surface_roughness-relief*roughness_variation,0.72,1.0);
 SPECULAR=0.18;
 // Gradiente de superfície em espaço de vista: dispensa tangentes ausentes
 // nas malhas agrupadas. O limite conserva as normais dos chanfros reais.
 vec3 dpdx=dFdx(VERTEX);
 vec3 dpdy=dFdy(VERTEX);
 vec3 n=normalize(NORMAL);
 vec3 r1=cross(dpdy,n);
 vec3 r2=cross(n,dpdx);
 float determinant=dot(dpdx,r1);
 vec3 gradient=(r1*dFdx(relief)+r2*dFdy(relief))*sign(determinant)/max(abs(determinant),0.000001);
 gradient*=bump_height*(teal?0.25:1.0);
 gradient*=min(1.0,0.24/max(length(gradient),0.0001));
 NORMAL=normalize(n-gradient);
}
