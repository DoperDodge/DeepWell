// Full-screen post stack (PLAN §13.6): vignette driven by stamina, film
// grain driven by darkness, chromatic aberration driven by sanity. Subtle
// by design — it should be felt, not seen.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float grain_strength : hint_range(0.0, 0.3) = 0.06;
uniform float aberration : hint_range(0.0, 8.0) = 0.0; // rises as sanity falls
uniform float desaturate : hint_range(0.0, 1.0) = 0.0; // rises as sanity falls
uniform float time_seed = 0.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center_offset = uv - 0.5;

	// Chromatic aberration: channels drift apart radially.
	vec2 shift = center_offset * aberration * 0.002;
	float r = texture(screen_tex, uv + shift).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv - shift).b;
	vec3 col = vec3(r, g, b);

	// Sensor grain, stronger in the dark.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	float grain = (hash12(uv * vec2(1920.0, 1080.0) + vec2(time_seed * 60.0)) - 0.5)
		* grain_strength * (1.2 - luma);
	col += grain;

	// Desaturation at low sanity.
	col = mix(col, vec3(luma), desaturate);

	// Vignette.
	float vig = smoothstep(0.85, 0.35, length(center_offset));
	col *= mix(1.0 - vignette_strength, 1.0, vig);

	COLOR = vec4(col, 1.0);
}
