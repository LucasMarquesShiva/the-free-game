shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform sampler2D stones : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 connections=vec4(0.0);
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 pigment=texture(stones,world_pos.xz*0.18).rgb;
 ALBEDO=pigment*0.88;
 ROUGHNESS=0.94;
 float left=mix(UV.x,1.0,connections.x);
 float right=mix(1.0-UV.x,1.0,connections.y);
 float back=mix(UV.y,1.0,connections.z);
 float front=mix(1.0-UV.y,1.0,connections.w);
 float edge=min(min(left,right),min(back,front));
 float rough_edge=sin(world_pos.x*10.0+world_pos.z*13.0)*0.012;
 ALPHA=smoothstep(0.025,0.12,edge+rough_edge);
}
