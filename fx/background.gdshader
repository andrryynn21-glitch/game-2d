shader_type canvas_item;

// Latar bergradien yang bergerak sangat lambat. Sengaja hanya memakai
// aritmetika fragment sederhana supaya pasti jalan di renderer Compatibility
// (WebGL2) dan murah di GPU ponsel.

uniform vec4 top_color : source_color = vec4(0.07, 0.17, 0.27, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.02, 0.05, 0.10, 1.0);
uniform vec4 glow_color : source_color = vec4(0.35, 0.70, 0.90, 1.0);

// Kecepatan gelombang gradien. Kecil = tenang.
uniform float wave_speed : hint_range(0.0, 1.0) = 0.12;

// Kekuatan cahaya lembut di bagian atas layar.
uniform float halo_strength : hint_range(0.0, 1.0) = 0.25;

// Kekuatan vignette di tepi layar.
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 uv = UV;

	// Gradien vertikal, dilengkungkan sedikit oleh dua gelombang berbeda fase
	// supaya tidak terlihat seperti garis lurus yang mati.
	float wave = sin(uv.x * 3.1 + TIME * wave_speed) * 0.035
	           + sin(uv.x * 1.7 - TIME * wave_speed * 0.7) * 0.025;
	float t = smoothstep(0.0, 1.0, clamp(uv.y + wave, 0.0, 1.0));
	vec3 col = mix(top_color.rgb, bottom_color.rgb, t);

	// Sumber cahaya lembut yang berdenyut pelan dari atas.
	float halo = 1.0 - clamp(distance(uv, vec2(0.5, 0.12)) * 1.6, 0.0, 1.0);
	halo = pow(halo, 3.0) * (0.55 + 0.45 * sin(TIME * 0.35));
	col += glow_color.rgb * halo * halo_strength;

	// Vignette menjaga mata tetap terfokus ke tengah arena.
	float edge = clamp(distance(uv, vec2(0.5)) * 1.35, 0.0, 1.0);
	col *= 1.0 - vignette_strength * pow(edge, 2.2);

	COLOR = vec4(col, 1.0);
}
