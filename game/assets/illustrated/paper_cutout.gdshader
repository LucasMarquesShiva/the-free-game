shader_type canvas_item;
// Some generated source PNGs encode their neutral preview background in RGB.
// Key it only at draw time; the original artwork remains unchanged on disk.
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
 vec4 tex = texture(TEXTURE, UV);
 float high = max(tex.r, max(tex.g, tex.b));
 float low = min(tex.r, min(tex.g, tex.b));
 float neutral = 1.0 - smoothstep(0.035, 0.12, high - low);
 float light = smoothstep(0.72, 0.83, low);
 COLOR = vec4(tex.rgb, tex.a * (1.0-neutral*light)) * tint;
}
