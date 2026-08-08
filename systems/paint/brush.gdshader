shader_type canvas_item;

// Premultiplied alpha, spelled out rather than left to the default.
//
// The buffer this draws into is never cleared, so every quad blends onto whatever is
// already there. blend_premul_alpha means the hardware does exactly:
//
//     dst = src + dst * (1 - src.a)
//
// on BOTH colour and alpha. Feed it rgb already multiplied by a (see below) and that
// one line is the whole paint model:
//   - alpha climbs toward 1 with diminishing returns, so passes build coverage;
//   - colour lerps toward the can colour weighted by how much landed.
//
// Storing rgb premultiplied is why wall_surface.gdshader composites with an ADD and
// not a mix(). Change one and you must change the other.
render_mode blend_premul_alpha, unshaded;

uniform vec4 paint_color : source_color = vec4(1.0);
// Alpha at the dead centre of the cone this frame. The can computes it; see
// spray_can.gd::_spray_tick().
uniform float peak_alpha = 0.15;
// Edge hardness of the SHOULDER — the shell outside the plateau. 1.0 is a soft cloud,
// 4.0 is a crisp disc.
uniform float falloff : hint_range(0.2, 8.0) = 2.4;
// Fraction of the radius that comes out at FULL strength before the shoulder starts.
//
// This is the difference between paint and crayon. A pure pow() falloff peaks at a
// single point, so a moving stroke only ever saturates along its exact centreline and
// everything either side is a ramp: at half a radius out one pass lands about 0.48
// alpha, which composites over grey concrete as mid grey. A line with no body reads as
// a wax crayon no matter what colour is in the can.
//
// A real cone has a core that is genuinely saturated and a shoulder where it breaks up.
// Modelling that as a plateau means the same pass lands ~0.93 at half a radius instead.
//
// 0.0 reproduces the old pure-pow behaviour exactly, which is what makes this safe to
// A/B against: set it to zero and you are back where you were.
uniform float core_frac : hint_range(0.0, 0.95) = 0.5;

// GDD 5.3 step 6: the wall fights back. Pits and rough aggregate take less paint than the
// smooth patches beside them, so a first pass comes out mottled and it takes a second and
// a third to bury the texture. It is a bigger authenticity win than it sounds, and it is
// the difference between painting a wall and painting a canvas.
//
// Procedural because a gray-box wall has no maps yet. When walls arrive from Blender this
// becomes a sample of their own roughness/AO — same line, real data.
//
// The noise is anchored to the BUFFER, not to the brush quad, which is the whole point:
// the same rough spots resist every pass, so they stay visible until you bury them. Tie
// it to the quad and it would just be per-stamp static.
uniform vec2 buffer_size = vec2(2400.0, 1200.0);
uniform float wall_grain : hint_range(0.0, 1.0) = 0.15;
uniform float grain_scale = 420.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	// The quad is a unit square scaled to the cone's diameter, so distance from the
	// centre in "radii" is just how far UV is from (0.5, 0.5), doubled. The quad's
	// own rotation and non-uniform scale turn this circle into the angled ellipse of
	// GDD 5.3 step 5 for free -- the shader never needs to know about the angle.
	float d = length(UV - vec2(0.5)) * 2.0;
	// Plateau out to core_frac, then the shoulder runs the remaining shell down to zero
	// at the rim. The divide is what keeps the shoulder a full pow() curve instead of a
	// clipped one, so `falloff` still means the same thing it always did.
	float shoulder = clamp((1.0 - d) / max(1.0 - core_frac, 0.001), 0.0, 1.0);
	float mask = pow(shoulder, falloff);

	// The clamp is load-bearing, not defensive. Up close one frame can ask for far more
	// than alpha 1.0, and blend_premul_alpha computes dst = src + dst * (1 - src.a) --
	// feed it src.a > 1 and that factor goes NEGATIVE. On the old 8-bit target the
	// hardware clamped for us; on a float target nothing does, and the wall would go
	// inverted the harder you sprayed.
	//
	// Paint clipped off here is not lost, it is over-application: alpha cannot exceed
	// "fully covered". Slice 3 sends the excess into PaintData.G as thickness, which is
	// exactly what makes a drip form when you hold on one spot (GDD 5.4).
	// FRAGCOORD, not UV: this has to be the position on the WALL, not on the quad.
	vec2 wall_uv = FRAGCOORD.xy / buffer_size;
	float grain = value_noise(wall_uv * grain_scale) * 0.6
		+ value_noise(wall_uv * grain_scale * 2.7) * 0.4;
	// Centred on 1.0 so the wall redistributes paint rather than swallowing it — rough
	// spots take less, smooth spots take more, and the total stays honest.
	float resist = max(1.0 + (grain - 0.5) * 2.0 * wall_grain, 0.0);

	float a = clamp(peak_alpha * mask * resist, 0.0, 1.0);
	COLOR = vec4(paint_color.rgb * a, a);
}
