shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D stones : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float relief_strength : hint_range(0.0,1.0)=0.28;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_pos.xz-vec2(20.0,35.0);
 vec3 texture_color=texture(stones,world_pos.xz*0.35).rgb;
 float luma=dot(texture_color,vec3(0.2126,0.7152,0.0722));
 vec3 stone=mix(vec3(luma),texture_color,0.35)*vec3(0.92,0.94,0.92);
 float outer=max(abs(p.x),abs(p.y));
 float border=smoothstep(3.38,3.43,outer)*(1.0-smoothstep(3.65,3.71,outer));
 float ring=(1.0-smoothstep(0.055,0.083,abs(length(p)-1.9)))*0.68;
 float center=1.0-smoothstep(0.10,0.16,abs(p.x)+abs(p.y));
 vec3 inlay=stone*vec3(0.58,0.66,0.66);
 ALBEDO=mix(stone,inlay,max(border,max(ring,center)));
 vec2 tex_uv=world_pos.xz*0.35;
 vec3 weights=vec3(0.2126,0.7152,0.0722);
 float h_left=dot(texture(stones,tex_uv-vec2(0.0036,0.0),1.2).rgb,weights);
 float h_right=dot(texture(stones,tex_uv+vec2(0.0036,0.0),1.2).rgb,weights);
 float h_back=dot(texture(stones,tex_uv-vec2(0.0,0.0036),1.2).rgb,weights);
 float h_front=dot(texture(stones,tex_uv+vec2(0.0,0.0036),1.2).rgb,weights);
 float mean_height=max(0.08,(h_left+h_right+h_back+h_front)*0.25);
 vec2 slope=clamp(vec2(h_left-h_right,h_back-h_front)/mean_height,vec2(-0.45),vec2(0.45));
 NORMAL_MAP=normalize(vec3(slope,1.0))*0.5+0.5;
 NORMAL_MAP_DEPTH=relief_strength;
 ROUGHNESS=0.96;SPECULAR=0.13;
}
