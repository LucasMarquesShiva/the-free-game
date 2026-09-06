shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform sampler2D stones : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 connections=vec4(0.0);
uniform float relief_strength : hint_range(0.0,1.0)=0.38;
varying vec3 world_pos;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_pos.xz;
 vec3 pigment=texture(stones,p*0.28).rgb;
 float value=dot(pigment,vec3(0.2126,0.7152,0.0722));
 // Muted limestone keeps the stone pattern and the road readable against grass.
 pigment=mix(vec3(value),pigment,0.86)*0.76;
 float left=mix(UV.x,1.0,connections.x);
 float right=mix(1.0-UV.x,1.0,connections.y);
 float back=mix(UV.y,1.0,connections.z);
 float front=mix(1.0-UV.y,1.0,connections.w);
 float edge=min(min(left,right),min(back,front));
 float patches=noise(p*2.4+vec2(13.1,7.6));
 float fine=noise(p*6.3);
 float rough_edge=(patches-0.5)*0.028+(fine-0.5)*0.010;
 float verge=1.0-smoothstep(0.055,0.18,edge+rough_edge);
 vec3 earth=texture(earth_tex,p*0.165+vec2(0.13,0.41)).rgb*vec3(0.78,0.86,0.87);
 ALBEDO=mix(pigment,earth,verge*(0.32+patches*0.28));
 // Only unconnected edges erode. Connected sides and junctions remain opaque.
 float grass_break=smoothstep(0.62,0.85,fine)*0.012;
 ALPHA=smoothstep(0.025,0.105,edge+rough_edge-grass_break);
 // Filtered pigment relief retains the original cobbles and never moves the
 // walkable surface. A tangent frame keeps the light response stable on banks.
 vec2 tex_uv=p*0.28;
 vec2 step_uv=vec2(0.0036);
 vec3 weights=vec3(0.2126,0.7152,0.0722);
 float h_left=dot(texture(stones,tex_uv-vec2(step_uv.x,0.0),1.2).rgb,weights);
 float h_right=dot(texture(stones,tex_uv+vec2(step_uv.x,0.0),1.2).rgb,weights);
 float h_back=dot(texture(stones,tex_uv-vec2(0.0,step_uv.y),1.2).rgb,weights);
 float h_front=dot(texture(stones,tex_uv+vec2(0.0,step_uv.y),1.2).rgb,weights);
 float mean_height=max(0.08,(h_left+h_right+h_back+h_front)*0.25);
 vec2 slope=clamp(vec2(h_left-h_right,h_back-h_front)/mean_height,vec2(-0.45),vec2(0.45));
 NORMAL_MAP=normalize(vec3(slope,1.0))*0.5+0.5;
 NORMAL_MAP_DEPTH=relief_strength*(1.0-verge*0.85);
 ROUGHNESS=0.98;SPECULAR=0.12;
}
