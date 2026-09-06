shader_type spatial;
render_mode diffuse_burley, cull_back;
// This surface field replaces triangle tint only on the river rock factory.
// Geometry, weighted normals, support and all original LODs remain unchanged.
uniform sampler2D surface_field : filter_linear_mipmap, repeat_enable;
uniform vec4 granite_light : source_color = vec4(0.54, 0.53, 0.48, 1.0);
uniform vec4 granite_dark : source_color = vec4(0.43, 0.43, 0.40, 1.0);
uniform vec4 moss_center : source_color = vec4(0.32, 0.38, 0.20, 1.0);
uniform vec4 moss_edge : source_color = vec4(0.42, 0.45, 0.28, 1.0);
varying vec3 stone_position;
varying vec3 stone_normal;
void vertex() {
 stone_position = VERTEX + MODEL_MATRIX[3].xyz * vec3(0.37, 0.19, 0.31);
 stone_normal = NORMAL;
}
void fragment() {
 vec3 p = stone_position * 0.22;
 // Fixed, overlapping planes sample the same continuous field on either side of
 // every triangle edge, including the old moss overlay triangles.
 vec3 a = texture(surface_field, p.xz).rgb;
 vec3 b = texture(surface_field, p.xy + vec2(0.31, 0.73)).rgb;
 vec3 c = texture(surface_field, p.yz + vec2(0.67, 0.19)).rgb;
 float macro = a.r * 0.60 + b.r * 0.25 + c.r * 0.15;
 float fine = a.g * 0.50 + b.g * 0.30 + c.g * 0.20;
 float grain = a.b * 0.50 + b.b * 0.30 + c.b * 0.20;
 float weather = smoothstep(0.30, 0.72, macro * 0.67 + fine * 0.33);
 vec3 stone = mix(granite_dark.rgb, granite_light.rgb, weather);
 stone *= 0.94 + grain * 0.12;
 float upward = smoothstep(-0.15, 0.70, normalize(stone_normal).y);
 float moss_field = macro + (fine - 0.5) * 0.15;
 float moss = smoothstep(0.535, 0.625, moss_field) * mix(0.38, 1.0, upward);
 vec3 organic = mix(moss_edge.rgb, moss_center.rgb, smoothstep(0.57, 0.68, moss_field));
 organic *= 0.94 + grain * 0.12;
 ALBEDO = mix(stone, organic, moss);
 ROUGHNESS = 0.98;
 SPECULAR = 0.07;
}
