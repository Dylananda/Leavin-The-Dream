// Silueta de un personaje a través de los edificios: se pinta en `color` solo donde
// el propio personaje no se ve. Las piezas del personaje escriben 1 en el stencil
// (Actor._mat) y esta pasada, sin prueba de profundidad, solo pinta donde no hay ese 1:
// es decir, donde algo lo tapa. Así no se pinta encima de sí mismo.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_back, shadows_disabled;
stencil_mode read, compare_not_equal, 1;

uniform vec4 color : source_color = vec4(0.85, 0.88, 1.0, 0.35);

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
