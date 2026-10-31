// Rayos X compartidos: si un fragmento queda entre la cámara y el jugador,
// se descarta con un tramado para ver a través. world.gd actualiza los uniforms.
uniform vec2 focus_uv = vec2(-10.0);
uniform float focus_depth = 0.0;
uniform float xray_radius = 0.12;
uniform float aspect = 1.7778;

bool xray_hidden(vec2 screen_uv, vec3 view_vertex, vec2 frag_coord) {
	float dist = length((screen_uv - focus_uv) * vec2(aspect, 1.0));
	if (dist >= xray_radius || -view_vertex.z >= focus_depth - 1.5) {
		return false;
	}
	ivec2 p = ivec2(frag_coord) % 2;
	float edge = smoothstep(xray_radius, xray_radius * 0.6, dist);
	return edge > ((p.x == p.y) ? 0.25 : 0.75);
}
