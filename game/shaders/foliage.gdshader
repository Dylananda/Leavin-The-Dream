// Copas de árbol: color por instancia (MultiMesh) y rayos X como los edificios.
shader_type spatial;
render_mode diffuse_toon, specular_disabled;

#include "res://shaders/xray.gdshaderinc"

void fragment() {
	ALBEDO = COLOR.rgb;
	if (xray_hidden(SCREEN_UV, VERTEX, FRAGCOORD.xy)) {
		discard;
	}
}
