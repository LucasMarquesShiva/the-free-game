shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D earth_tex:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D meadow_tex:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 world_pos;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_pos.xz;
 // Same scale as the existing clearing; the soil grain continues into its skirt.
 vec3 earth=texture(earth_tex,p*0.25,0.45).rgb*vec3(0.82,0.89,0.88);
 float patches=noise(p*0.7+vec2(7.3,13.7));
 earth*=mix(0.91,1.07,patches);
 // Match the adjacent meadow's palette/scale rather than painting a green rim.
 vec2 uv=p*0.125;
 vec3 fine=texture(meadow_tex,uv,0.8).rgb;
 vec3 broad=texture(meadow_tex,mat2(vec2(0.8,0.6),vec2(-0.6,0.8))*uv*0.31+vec2(0.23,0.41)).rgb;
 float variation=mix(0.88,1.18,noise(p*0.15));
 vec3 grass=mix(fine,broad,0.45)*variation;
 float value=dot(grass,vec3(0.2126,0.7152,0.0722));
 grass=mix(vec3(value),grass,0.62)*vec3(0.69,0.90,0.83);
 vec3 meadow_base=vec3(0.35,0.43,0.23);
 if(!OUTPUT_IS_SRGB)meadow_base=pow(meadow_base,vec3(2.2));
 grass=mix(grass,meadow_base*variation,0.3);
 float thickets=noise(p*0.16+vec2(5.3,27.4));
 float families=noise(p*0.225+vec2(18.1,6.7));
 grass*=mix(vec3(1.0),vec3(0.78,1.035,0.70),smoothstep(0.36,0.78,thickets)*0.48);
 grass*=mix(vec3(1.0),vec3(1.16,1.08,0.86),smoothstep(0.40,0.76,families)*0.45);
 float edge=max(abs(UV.x-0.5),abs(UV.y-0.5));
 float broken_edge=edge+(noise(p*2.2)-0.5)*0.06+(noise(p*6.7)-0.5)*0.018;
 float growth=smoothstep(0.39,0.5,broken_edge);
 // Grass tongues also reach flat support areas; only the exposed margin slopes.
 ALBEDO=mix(earth,grass,growth*0.84);
 ROUGHNESS=1.0;SPECULAR=0.12;
}
