// Filtro de pantalla completa con lo que le pasa al personaje (ver GameState.effects()):
// viñeta roja que late con el mono, bordes de colores con mucho colocón, colores chillones
// con pastillas, visión doble con alcohol, brillo con la euforia de la base, túnel oscuro
// con hambre o bajón, párpados que se cierran con sueño, aberración cromática con la
// salud mental por los suelos, bordes duros y contraste con speed y, con MDMA, todo cálido,
// con un halo suave que late al ritmo de la música.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float mono = 0.0;
uniform float high = 0.0;
uniform float saturate = 0.0;
uniform float double_vision = 0.0;
uniform float glow = 0.0;
uniform float tunnel = 0.0;
uniform float drowsy = 0.0;
uniform float paranoia = 0.0;
uniform float sharp = 0.0;
uniform float love = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	float ab = paranoia * 0.006 * (0.6 + 0.4 * sin(t * 2.3));
	vec3 c = vec3(
		texture(screen, uv + vec2(ab, 0.0)).r,
		texture(screen, uv).g,
		texture(screen, uv - vec2(ab, 0.0)).b);
	// visión doble: una copia desplazada que va y viene
	vec2 ghost = vec2(sin(t * 0.8), cos(t * 0.6)) * 0.012 * double_vision;
	c = mix(c, texture(screen, uv + ghost).rgb, 0.4 * double_vision);
	// colores chillones con un leve giro de tono
	float gray = dot(c, vec3(0.299, 0.587, 0.114));
	c = clamp(mix(vec3(gray), c, 1.0 + saturate * 1.4), 0.0, 1.0);
	c = mix(c, c.gbr, saturate * 0.15 * (0.5 + 0.5 * sin(t * 0.7)));
	// euforia: todo brilla
	c += glow * 0.12 * (0.7 + 0.3 * sin(t * 5.0));
	// speed: bordes marcados, contraste y un punto frío
	if (sharp > 0.0) {
		vec2 px = vec2(0.0015, 0.0025);
		vec3 around = (texture(screen, uv + vec2(px.x, 0.0)).rgb + texture(screen, uv - vec2(px.x, 0.0)).rgb
			+ texture(screen, uv + vec2(0.0, px.y)).rgb + texture(screen, uv - vec2(0.0, px.y)).rgb) * 0.25;
		c += (c - around) * 1.6 * sharp;
		c = mix(c, (c - 0.5) * 1.3 + 0.5, 0.6 * sharp);
		c = mix(c, c * vec3(0.94, 1.0, 1.06), 0.5 * sharp);
	}
	// MDMA: halo suave, tono cálido y un latido a unos 128 golpes por minuto
	if (love > 0.0) {
		float beat = pow(0.5 + 0.5 * sin(t * 13.4), 4.0);
		vec2 r = vec2(0.006, 0.01) * (1.0 + beat);
		vec3 halo = (texture(screen, uv + r).rgb + texture(screen, uv - r).rgb
			+ texture(screen, uv + vec2(r.x, -r.y)).rgb + texture(screen, uv + vec2(-r.x, r.y)).rgb) * 0.25;
		c = mix(c, max(c, halo), 0.6 * love);
		c = mix(c, c * vec3(1.15, 0.96, 1.02) + vec3(0.05, 0.0, 0.04), love * 0.7);
		c += vec3(0.08, 0.02, 0.06) * beat * love;
	}

	float d = distance(UV, vec2(0.5));
	c *= 1.0 - smoothstep(0.25, 0.7, d) * tunnel * 0.85;
	vec3 trip = 0.5 + 0.5 * cos(t * 1.5 + UV.xyx * 4.0 + vec3(0.0, 2.0, 4.0));
	c = mix(c, trip, smoothstep(0.2, 0.8, d) * high * 0.5);
	float pulse = 0.75 + 0.25 * sin(t * 3.0);
	c = mix(c, vec3(0.6, 0.0, 0.05), smoothstep(0.3, 0.75, d) * mono * pulse * 0.8);
	// párpados: se cierran de vez en cuando, más cuanto más sueño
	float blink = drowsy * pow(max(0.0, sin(t * 0.7)), 6.0) * 0.55;
	float lid = smoothstep(0.5 - blink - 0.05, 0.5 - blink, abs(UV.y - 0.5)) * step(0.001, blink);
	c = mix(c, vec3(0.0), lid);
	COLOR = vec4(c, 1.0);
}
