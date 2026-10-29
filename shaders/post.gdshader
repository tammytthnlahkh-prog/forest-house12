shader_type canvas_item;

// مؤثر ما بعد المعالجة: حبيبات فيلم + تعتيم الأطراف + تشوّه عند الخوف
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float fear : hint_range(0.0, 1.0) = 0.0;
uniform float grain : hint_range(0.0, 0.3) = 0.05;
uniform float vignette : hint_range(0.0, 1.0) = 0.85;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	float band = step(0.982, hash(vec2(floor(t * 14.0), floor(uv.y * 36.0))));
	uv.x += band * fear * 0.035 * (hash(vec2(t, uv.y)) - 0.5) * 2.0;
	vec2 dir = uv - vec2(0.5);
	float ca = 0.0012 + fear * 0.009;
	vec3 col;
	col.r = texture(screen_tex, uv + dir * ca).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - dir * ca).b;
	float n = hash(uv * vec2(1920.0, 1080.0) + vec2(t * 61.0, t * 17.0)) - 0.5;
	col += n * (grain + fear * 0.10);
	float v = 1.0 - smoothstep(0.30, 0.95, length(dir) * 1.45);
	col *= mix(1.0, v, vignette);
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(l), fear * 0.55);
	col = mix(col, col * vec3(1.25, 0.8, 0.8), fear * 0.4);
	COLOR = vec4(col, 1.0);
}
