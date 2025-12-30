shader_type spatial;
uniform sampler2D multipurpose_texture: filter_nearest_mipmap, repeat_enable;
uniform vec4 var_color: source_color;
uniform vec2 scale = vec2(1, 1);
uniform vec2 offset = vec2(0, 0);
uniform float specular = 0.5f;

void vertex() { }
/*
	Costruisco un vettore per campionare la texture in uno spazio planare ( planar projection/mapping ),
	cioé spalmo la texture come se fosse una tovaglia da pranzo infinita sul tavolo,
	uso il canale VERDE della texture per estrarre la griglia, applico il colore facendo la somma
*/
void fragment() {
	// calcolo la posizione nello spazio del frammento
	vec4 vertex = INV_VIEW_MATRIX * vec4(VERTEX, 1.0);
	// creo un vettore per il sampling
	vec2 sample_uv = (vertex.zx * (1.0f/scale)) + offset;
	// estraggo la griglia
	vec3 grid = texture(multipurpose_texture, sample_uv).ggg;
	// aggiungo il colore desiderato
	vec3 color = grid + var_color.rgb;
	// color = normalize(color);
	ALBEDO = color;
	SPECULAR = specular;
	// Called for every pixel the material is visible on.
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
