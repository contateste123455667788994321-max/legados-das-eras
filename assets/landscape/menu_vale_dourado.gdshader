shader_type canvas_item;

// Retangulo normalizado da arte original, sem deformacao.
uniform vec4 art_rect = vec4(0.0, 0.0, 1.0, 1.0);

// Cada máscara cobre um detalhe já pintado na tela de 1280 x 720.
float spot(vec2 uv, vec2 center, vec2 radius) {
	return 1.0 - smoothstep(0.15, 1.0, length((uv - center) / radius));
}

void fragment() {
	vec2 original_uv = (UV - art_rect.xy) / art_rect.zw;
	// Reflexao continua das extremidades, mantendo a escala original.
	vec2 p = 1.0 - abs(mod(original_uv, vec2(2.0)) - 1.0);
	float river = spot(p, vec2(0.60, 0.74), vec2(0.06, 0.035))
			+ spot(p, vec2(0.50, 0.84), vec2(0.055, 0.045))
			+ spot(p, vec2(0.58, 0.90), vec2(0.075, 0.045))
			+ spot(p, vec2(0.69, 0.98), vec2(0.095, 0.05));
	float falls = spot(p, vec2(0.309, 0.607), vec2(0.016, 0.043));
	float flag = spot(p, vec2(0.205, 0.265), vec2(0.029, 0.019));
	float smoke = spot(p, vec2(0.163, 0.62), vec2(0.017, 0.04))
			+ spot(p, vec2(0.92, 0.538), vec2(0.018, 0.035));
	vec2 offset;
	offset.x = river * 0.00075 * sin(p.y * 380.0 - TIME * 2.3)
			+ flag * 0.0008 * sin(p.x * 220.0 + TIME * 2.4)
			+ smoke * 0.00065 * sin(p.y * 180.0 - TIME * 1.1);
	offset.y = falls * 0.0011 * sin(p.y * 480.0 - TIME * 5.0)
			+ flag * 0.0011 * sin(p.x * 270.0 - TIME * 3.0);
	vec4 color = texture(TEXTURE, p + offset);
	float torches = spot(p, vec2(0.162, 0.519), vec2(0.009, 0.016))
			+ spot(p, vec2(0.272, 0.519), vec2(0.009, 0.016));
	color.rgb += torches * vec3(0.035, 0.018, 0.003) * (0.5 + 0.5 * sin(TIME * 6.3 + p.x * 70.0));
	COLOR = color;
}
