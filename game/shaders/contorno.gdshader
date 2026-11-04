// Contorno negro de los personajes: la malla crecida hacia fuera, vista por detrás. Crece
// `grow` por la transparencia del color del vértice: las piezas con alfa 0 (los ojos, la
// boca... del cuerpo nuevo, scripts/actors/cuerpo.gd) no llevan contorno y la cara queda
// limpia. Escribe 1 en el stencil, como el personaje (ver silhouette.gdshader).
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
stencil_mode write, compare_always, 1;

uniform float grow = 0.035;
uniform vec3 color : source_color = vec3(0.08, 0.06, 0.06);

void vertex() {
	VERTEX += NORMAL * grow * COLOR.a;
}

void fragment() {
	ALBEDO = color;
}
