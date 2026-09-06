shader_type spatial;
render_mode diffuse_burley,cull_disabled;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;VERTEX.y+=sin(VERTEX.x*1.3+TIME*0.8)*0.025+cos(VERTEX.z*1.7+TIME)*0.025;}
void fragment(){
 float wave=sin(world_pos.x*3.4+world_pos.z*1.1-TIME*1.8)*sin(world_pos.z*4.0+TIME*0.6);
 float rip=pow(max(0.0,wave),12.0);
 vec3 pigment=mix(vec3(0.09,0.34,0.35),vec3(0.23,0.58,0.56),0.55+wave*0.18)+rip*vec3(0.18,0.21,0.17);
 ALBEDO=OUTPUT_IS_SRGB ? pigment : pow(pigment,vec3(2.2)); ROUGHNESS=0.28;METALLIC=0.2;
 NORMAL_MAP=vec3(0.5+wave*0.07,0.5+sin(world_pos.z*8.0-TIME)*0.04,1.0);
 NORMAL_MAP_DEPTH=0.45;
}
