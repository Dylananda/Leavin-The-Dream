// Viñeta de pantalla completa: roja con el mono, de colores con el colocón.
shader_type canvas_item;

uniform float mono = 0.0;
uniform float high = 0.0;

void fragment() {
	float d = distance(UV, vec2(0.5));
	float pulse = 0.75 + 0.25 * sin(TIME * 3.0);
	float red = smoothstep(0.3, 0.75, d) * mono * pulse;
	vec3 trip = 0.5 + 0.5 * cos(TIME * 1.5 + UV.xyx * 4.0 + vec3(0.0, 2.0, 4.0));
	float trip_a = smoothstep(0.2, 0.8, d) * high * 0.5;
	vec3 col = mix(trip, vec3(0.6, 0.0, 0.05), red / max(red + trip_a, 0.001));
	COLOR = vec4(col, clamp(red + trip_a, 0.0, 0.85));
}
