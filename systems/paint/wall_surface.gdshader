shader_type spatial;

// The paint buffer: a live SubViewport texture owned by PaintSurface.
uniform sampler2D paint_tex : filter_linear, repeat_disable, hint_default_transparent;
// PaintData (§5.2). R = wetness, decaying over ~30 s.
uniform sampler2D wet_tex : filter_linear, repeat_disable, hint_default_black;
uniform vec4 base_color : source_color = vec4(0.42, 0.41, 0.39, 1.0);
uniform float base_roughness : hint_range(0.0, 1.0) = 0.92;
// Roughness of paint that has just landed. Concrete is near matte; fresh enamel is a
// mirror by comparison, and that gap is the whole effect.
uniform float wet_roughness : hint_range(0.0, 1.0) = 0.12;
// Wet paint also reads darker and deeper than the same paint dry.
uniform float wet_darkening : hint_range(0.0, 1.0) = 0.14;
// Metres. Must match PaintSurface.size -- the script pushes it, do not set it by hand.
uniform vec2 wall_size = vec2(6.0, 3.0);

varying vec2 paint_uv;

void vertex() {
	// VERTEX is in model space here, so this is the wall's own local position. It is
	// the same formula as PaintSurface.world_to_uv(), deliberately -- see the long
	// comment on that function for why we derive UV instead of reading the mesh's
	// UV channel.
	paint_uv = vec2(
		VERTEX.x / wall_size.x + 0.5,
		0.5 - VERTEX.y / wall_size.y
	);
}

void fragment() {
	vec4 paint = texture(paint_tex, paint_uv);

	// paint.rgb is PREMULTIPLIED by paint.a (brush.gdshader writes it that way), so
	// the composite is an add, not a blend. If you "fix" this to
	// mix(base_color.rgb, paint.rgb, paint.a) the paint comes out dark and muddy,
	// because you would be multiplying by alpha a second time.
	// Gate wetness on coverage: bare wall never shines, however recently the haze drifted
	// over it.
	float wet = texture(wet_tex, paint_uv).r * paint.a;

	ALBEDO = (base_color.rgb * (1.0 - paint.a) + paint.rgb)
		* mix(1.0, 1.0 - wet_darkening, wet);

	// GDD 5.2 calls this out as the single line that does most of the convincing, and it
	// is: a wet mark catches the light and a dry one does not, so a piece stops being a
	// texture on a wall and starts being something that just happened.
	ROUGHNESS = mix(base_roughness, wet_roughness, wet);
	METALLIC = 0.0;
}
