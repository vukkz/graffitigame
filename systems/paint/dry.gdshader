shader_type canvas_item;

// Drying. Covers the whole PaintData buffer and takes a slice off the wetness channel.
//
// A never-cleared buffer has no natural way to fade, so drying has to be drawn like
// everything else. Subtracting rather than multiplying is deliberate: the buffer is 8-bit
// per channel, and a multiplicative decay stalls once the rounding of value*0.99 lands
// back on the same integer — paint would stay faintly, permanently wet.
render_mode blend_sub, unshaded;

// Wetness removed by this pass. The wall computes it from how long it has been since the
// last one, so the drying rate does not change with framerate.
uniform float amount : hint_range(0.0, 1.0) = 0.02;

void fragment() {
	// blend_sub computes dst = dst − src * src.a, so alpha has to be 1 for `amount` to
	// land in full.
	COLOR = vec4(amount, 0.0, 0.0, 1.0);
}
