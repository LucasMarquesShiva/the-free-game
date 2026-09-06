shader_type spatial;
render_mode blend_mix,depth_draw_never;
uniform sampler2D earth_tex:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 world_pos;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_pos.xz;
 // Rounded, interrupted soil skirt; building foundation and support stay intact.
 vec2 q=abs(UV-vec2(0.5));
 float edge=pow(pow(q.x,8.0)+pow(q.y,8.0),0.125);
 float perturb=(noise(p*1.4)-0.5)*0.084+(noise(p*5.2)-0.5)*0.022;
 ALPHA=(1.0-smoothstep(0.335,0.49,edge+perturb))*0.9;
 ALBEDO=texture(earth_tex,p*0.25).rgb*vec3(0.82,0.89,0.88);
 ROUGHNESS=1.0;SPECULAR=0.15;
}
