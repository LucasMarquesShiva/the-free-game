shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D meadow_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float pigment_softness : hint_range(0.0,1.0)=0.3;
// Temper the smallest grass marks while retaining the painted meadow.
uniform float detail_mip_bias : hint_range(0.0,2.0)=0.8;
varying vec3 world_pos;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_pos.xz;
 vec2 uv=p*0.125;
 vec3 fine=texture(meadow_tex,uv,detail_mip_bias).rgb;
 vec3 broad=texture(meadow_tex,mat2(vec2(0.8,0.6),vec2(-0.6,0.8))*uv*0.31+vec2(0.23,0.41)).rgb;
 float variation=mix(0.88,1.18,noise(p*0.15));
 vec3 grass=mix(fine,broad,0.45)*variation;
 float grass_value=dot(grass,vec3(0.2126,0.7152,0.0722));
 grass=mix(vec3(grass_value),grass,0.62)*vec3(0.69,0.90,0.83);
 vec3 meadow_base=vec3(0.35,0.43,0.23);
 if(!OUTPUT_IS_SRGB)meadow_base=pow(meadow_base,vec3(2.2));
 grass=mix(grass,meadow_base*variation,pigment_softness);
 // Three-to-six metre ground families keep texture but describe a clearing.
 float patches=noise(p*0.225+vec2(18.1,6.7));
 float thickets=noise(p*0.16+vec2(5.3,27.4));
 float clearing=1.0-smoothstep(10.0,25.0,length((p-vec2(27.5,31.0))*vec2(0.87,1.0)));
 // Multiplicative hue shifts preserve every small grass mark in the source art.
 grass*=mix(vec3(1.0),vec3(0.78,1.035,0.70),smoothstep(0.36,0.78,thickets)*0.48);
 grass*=mix(vec3(1.0),vec3(1.16,1.08,0.86),smoothstep(0.40,0.76,patches)*0.45);
 vec3 worn=texture(earth_tex,p*0.165+vec2(0.13,0.41)).rgb*vec3(0.78,0.86,0.87);
 float bare=smoothstep(0.55,0.78,patches+noise(p*0.61)*0.08)*clearing;
 grass=mix(grass,worn,bare*0.66);
 float bank=1.0-smoothstep(-0.9,-0.12,world_pos.y);
 vec3 earth=mix(vec3(0.29,0.26,0.16),vec3(0.52,0.47,0.3),noise(p*0.7));
 if(!OUTPUT_IS_SRGB)earth=pow(earth,vec3(2.2));
 // Irregular vegetation tongues interrupt the engineered continuous earth line.
 float bank_growth=smoothstep(0.38,0.74,noise(vec2(p.x*0.8,p.y*0.62))+noise(p*1.1)*0.12);
 float upper_bank=1.0-smoothstep(0.48,0.90,bank);
 float earth_cover=bank*(0.91-bank_growth*upper_bank*0.52);
 ALBEDO=mix(grass,earth,earth_cover);
 float center=dot(fine,vec3(0.333));
 float dx=dot(texture(meadow_tex,uv+vec2(0.0015,0.0),detail_mip_bias).rgb,vec3(0.333))-center;
 float dy=dot(texture(meadow_tex,uv+vec2(0.0,0.0015),detail_mip_bias).rgb,vec3(0.333))-center;
 NORMAL_MAP=normalize(vec3(-dx*1.4,-dy*1.4,1.0))*0.5+0.5;
 NORMAL_MAP_DEPTH=0.08;
 ROUGHNESS=0.98;SPECULAR=0.18;
}
