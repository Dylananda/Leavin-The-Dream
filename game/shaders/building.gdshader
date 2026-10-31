// Edificios caricaturizados: fachadas del atlas facade.png teñidas con el color de
// cada edificio (COLOR), azoteas, estilos especiales para monumentos, ventanas
// encendidas de noche y "rayos X" con tramado cuando el edificio tapa al jugador.
//
// Atributos que pone building_mesher.gd:
//   COLOR   color de la fachada
//   UV      x: vanos a lo largo de la pared, y: plantas desde el suelo
//   UV2     x: estilo (0 normal, 1 liso, 2 cristal, 3 celosía), y: semilla del edificio
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_back;

#include "res://shaders/xray.gdshaderinc"

uniform sampler2D facade : source_color, filter_linear, repeat_disable;
uniform float night = 0.0;

varying vec3 w_normal;
varying vec3 w_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	w_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float style = UV2.x;
	float seed = UV2.y;
	vec3 tint = COLOR.rgb;
	vec3 col;
	vec3 emit = vec3(0.0);
	vec2 cell = floor(UV);
	vec2 f = fract(UV);
	float lit = step(hash(cell + seed * 7.31), 0.35) * night;

	if (w_normal.y > 0.5) {
		// azotea: terracota mezclada con el color del edificio, con baldosas
		vec2 tile = fract(w_pos.xz * 0.5);
		float joint = step(0.94, max(tile.x, tile.y));
		vec3 terracotta = mix(vec3(0.56, 0.33, 0.25), vec3(0.5, 0.46, 0.42), step(0.6, fract(seed * 5.3)));
		col = mix(tint * 0.7, terracotta, 0.6) * (0.92 + 0.08 * hash(floor(w_pos.xz * 0.5))) * (1.0 - joint * 0.15);
	} else if (style < 0.5) {
		bool ground = cell.y < 0.5;
		float v;
		if (ground) {
			v = floor(hash(vec2(cell.x, seed)) * 4.0);
		} else {
			// cada edificio tiene un tipo de ventana; algunos vanos varían (ropa tendida, persianas cerradas)
			float base = mod(floor(seed * 4.0), 4.0) == 1.0 ? 0.0 : mod(floor(seed * 4.0), 4.0);
			float r = hash(cell + seed * 3.17);
			v = r < 0.18 ? 1.0 : (r < 0.36 ? 2.0 : base);
		}
		vec2 tuv = vec2((v + f.x) / 4.0, (ground ? 0.5 : 0.0) + (1.0 - f.y) * 0.5);
		vec4 t = texture(facade, tuv);
		if (t.a < 0.25) {
			col = tint * t.r * 2.0;
		} else if (t.a < 0.75) {
			col = mix(t.rgb, vec3(1.0, 0.82, 0.5), lit);
			emit = vec3(1.0, 0.7, 0.35) * lit * 1.4;
		} else {
			col = t.rgb;
		}
	} else if (style < 1.5) {
		// liso (piedra, hormigón): sillares y ventanas altas
		float joint = step(0.93, fract(UV.y * 3.0)) * 0.08;
		col = tint * (1.0 - joint);
		if (abs(f.x - 0.5) < 0.12 && f.y > 0.25 && f.y < 0.85) {
			col = mix(vec3(0.18, 0.22, 0.3), vec3(1.0, 0.82, 0.5), lit);
			emit = vec3(1.0, 0.7, 0.35) * lit;
		}
	} else if (style < 2.5) {
		// muro cortina de cristal
		float frame = step(0.94, max(f.x, f.y));
		col = mix(tint, vec3(0.75, 0.85, 0.95), 0.25 + 0.2 * f.y) * (1.0 - frame * 0.6);
		col = mix(col, vec3(1.0, 0.85, 0.6), lit * (1.0 - frame));
		emit = vec3(0.9, 0.75, 0.5) * lit * (1.0 - frame);
	} else {
		// celosía metálica (Barceló Raval)
		float d1 = abs(fract((UV.x + UV.y) * 0.5) - 0.5);
		float d2 = abs(fract((UV.x - UV.y) * 0.5) - 0.5);
		float line = 1.0 - step(0.06, min(d1, d2));
		col = mix(tint, vec3(0.75, 0.75, 0.78), line);
		emit = vec3(0.8, 0.6, 1.0) * night * line * 0.6;
	}

	ALBEDO = col;
	EMISSION = emit;

	if (xray_hidden(SCREEN_UV, VERTEX, FRAGCOORD.xy)) {
		discard;
	}
}
