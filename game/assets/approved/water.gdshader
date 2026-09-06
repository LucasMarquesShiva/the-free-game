shader_type spatial;
render_mode diffuse_burley,cull_disabled;
uniform sampler2D water_tex:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform float pigment_softness : hint_range(0.0,1.0)=0.4;
varying vec3 world_pos;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;VERTEX.y+=sin(VERTEX.x*1.3+TIME*0.8)*0.018+cos(VERTEX.z*1.7+TIME)*0.022;}
void fragment(){
 vec2 p=world_pos.xz;
 vec2 flow=p*vec2(0.8,0.45)+vec2(sin(p.y*0.27)*0.3,-TIME*0.25);
 float n=noise(flow)+noise(flow*2.7+5.0)*0.35;
 float ripple=sin(p.x*3.4+p.y*1.2+n*3.0-TIME*1.5);
 float crest=pow(max(0.0,ripple),17.0)*smoothstep(0.66,0.96,noise(p*0.83+vec2(0.0,-TIME*0.12)));
 float channel_center=57.5+sin(p.y*0.065)*0.3+sin(p.y*0.31)*0.13;
 float bank=abs(p.x-channel_center);
 float half_channel=2.22+sin(p.y*0.17)*0.25+sin(p.y*0.47)*0.12;
 float depth=1.0-smoothstep(0.55,half_channel+0.65,bank);
 float current=noise(vec2((p.x-channel_center)*0.7+sin(p.y*0.13)*0.4,p.y*0.12-TIME*0.016));
 float shore=smoothstep(half_channel-0.1,half_channel+0.85,bank)*smoothstep(0.5,0.95,noise(flow*2.0));
 vec2 uv=p*vec2(0.18,0.14)+vec2(sin(TIME*0.15)*0.006,-TIME*0.023);
 vec2 distortion=vec2(sin(p.y*1.7+TIME)*0.006,cos(p.x*1.3-TIME*0.5)*0.007);
 vec3 pigment=texture(water_tex,uv+distortion).rgb;
 vec3 slow=texture(water_tex,p*0.12+vec2(0.31,-TIME*0.015)).rgb;
 pigment=mix(pigment,slow,0.18);
 vec3 deeper_water=vec3(0.10,0.31,0.34);
 vec3 shallow_water=vec3(0.26,0.48,0.42);
 vec3 foam_color=vec3(0.76,0.85,0.72);
 if(!OUTPUT_IS_SRGB){deeper_water=pow(deeper_water,vec3(2.2));shallow_water=pow(shallow_water,vec3(2.2));foam_color=pow(foam_color,vec3(2.2));}
 // Broad depth/current bands carry the colour; the source texture remains visible.
 vec3 depth_pigment=mix(shallow_water,deeper_water,depth*mix(0.68,1.0,current));
 pigment=mix(pigment,depth_pigment,0.56+pigment_softness*0.30);
 // Short, curved cross-current fragments; longitudinal gate frequency is 3.8x the previous mask.
 vec2 foam_pos=vec2(p.x-channel_center,p.y-TIME*0.11);
 float foam_warp=noise(foam_pos*vec2(1.1,0.70));
 float foam_lane=sin(foam_pos.y*9.0+sin(foam_pos.x*2.4+foam_warp*4.0)*1.4+foam_warp*2.4);
 float foam=pow(max(0.0,foam_lane),26.0)*smoothstep(0.62,0.83,noise(foam_pos*vec2(2.2,3.6)));
 foam*=(1.0-smoothstep(half_channel-0.35,half_channel+0.50,bank));
 ALBEDO=mix(pigment,foam_color,clamp(foam*0.16+shore*0.07,0.0,0.65));
 ROUGHNESS=mix(0.31,0.55,pigment_softness);METALLIC=0.0;SPECULAR=mix(0.55,0.30,pigment_softness);
 NORMAL_MAP=normalize(vec3(ripple*0.10,sin(p.y*5.0-TIME*1.4+n)*0.08,1.0))*0.5+0.5;
 NORMAL_MAP_DEPTH=mix(0.4,0.18,pigment_softness);
}
