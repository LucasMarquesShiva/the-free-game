shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D detail_tex : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 world_pos;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){ world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
 vec2 p=world_pos.xz;
 float broad=noise(p*0.12)*0.65+noise(p*0.32)*0.35;
 vec3 lush=vec3(0.24,0.36,0.125);
 vec3 dry=vec3(0.43,0.48,0.22);
 vec3 grass=mix(lush,dry,smoothstep(0.22,0.86,broad));
 float fine=texture(detail_tex,p*0.19).g;
 grass*=0.89+fine*0.25;
 float sand=1.0-smoothstep(-0.85,-0.18,world_pos.y);
 vec3 earth=mix(vec3(0.31,0.29,0.18),vec3(0.58,0.52,0.35),noise(p*0.6));
 vec3 pigment=mix(grass,earth,sand*0.8);
 ALBEDO=OUTPUT_IS_SRGB ? pigment : pow(pigment,vec3(2.2));
 ROUGHNESS=0.96;
 NORMAL_MAP=vec3(0.5+(noise(p*6.0)-0.5)*0.05,0.5+(noise(p*6.0+20.0)-0.5)*0.05,1.0);
 NORMAL_MAP_DEPTH=0.2;
}
