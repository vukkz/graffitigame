shader_type canvas_item;

// Writes into PaintData (GDD §5.2), the second buffer. R = wetness.
//
// blend_mix, not premultiplied: dst.r = 1.0*a + dst.r*(1-a), so fresh paint pushes
// wetness toward full where it lands and leaves what is around it alone. That is a lerp
// toward wet, which is what laying paint on top of paint actually does — it does NOT
// accumulate past 1, because a surface cannot be wetter than wet.
//
// Note this also drags G and B toward 0 wherever it draws, since blend_mix touches every
// channel. Harmless while R is all we use; when §5.2's thickness and age move into G and
// B they need writing here too rather than being left to decay.
render_mode blend_mix, unshaded;

// How wet this stamp leaves the wall, 0..1. The can scales it by how much paint the
// stamp actually laid, so a solid pass soaks the wall and an overspray haze barely
// dampens it — haze is microns thick and dry almost on contact.
uniform float wetness : hint_range(0.0, 1.0) = 1.0;
uniform float falloff : hint_range(0.2, 8.0) = 2.0;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float mask = pow(max(1.0 - d, 0.0), falloff);
	COLOR = vec4(1.0, 0.0, 0.0, clamp(wetness * mask, 0.0, 1.0));
}
