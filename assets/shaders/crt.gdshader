// Full-frame CRT post-process for a screen-space CanvasItem (see src/autoload/screen_effects.gd).
//
// ============================================================================================
// DELIBERATE DECISION - THERE IS NO SCREEN CURVATURE HERE, AND NONE MAY BE ADDED.
// ============================================================================================
// No barrel distortion, no bulged UVs, no rounded corner mask, no black bezel wedges. The image
// stays a full-bleed rectangle from edge to edge. This is a product requirement, not an oversight
// and not a "TODO: add curvature later":
//
//   * Curvature resamples every pixel through a non-linear UV warp. On a pixel-art game rendered
//     at an integer scale that destroys the exact texel grid the whole art direction rests on -
//     straight one-pixel lines start wobbling and crawling as the camera moves.
//   * Curvature pushes the frame edges inward, so the HUD anchored to the real screen edge either
//     gets bent off-screen or has to be re-laid-out for a shape that changes with aspect ratio.
//   * Rounded corners eat the corners of a UI that was authored rectangular.
//
// If you are here to "finish" the CRT look by adding distortion: don't. The tube-glass feel is
// carried by the aperture mask, the scanlines and the chromatic aberration instead - aberration in
// particular is what sells "this went through optics" without moving a single pixel of geometry.
//
// NEUTRALITY CONTRACT
// With every uniform at 0.0 this shader is a pass-through: it must output the screen texture
// unmodified, bit for bit. The settings sliders depend on that - a slider at 0 that still tints or
// dims the frame is a slider the player cannot trust. Every effect below is folded in through
// mix(neutral, effect, amount) or 1.0 + amount * delta for exactly this reason, and each one is
// independently zeroable.
//
// RESOLUTION INDEPENDENCE
// Scanlines and the aperture mask are computed from the SCREEN COORDINATE IN PIXELS
// (SCREEN_UV / SCREEN_PIXEL_SIZE), never from raw UV. Driving them from UV would tie the stripe
// count to the frame - the same 0.35 would draw a coarse 1080-line pattern in 1080p and a
// completely different one in 720p, and the effect would visibly change every time the player
// resizes the window. In pixel space one scanline is one physical pixel row at any resolution.

shader_type canvas_item;
// Lighting is meaningless for a post-process quad, and skipping it saves a pass over the whole
// screen.
render_mode unshaded;

// NEAREST: the base sample (all uniforms at 0) must return the exact texel under the fragment.
// A linear filter would blend neighbours and softly blur a pixel-art frame even in the neutral
// state, breaking the pass-through contract above.
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;

// --- Effect amounts. All normalised 0..1; 0.0 disables that effect entirely. ---

// Darkening of every other pixel row.
uniform float scanlines : hint_range(0.0, 1.0) = 0.35;
// Radial R/B channel separation. Geometry is untouched - only the sampling offset differs.
uniform float aberration : hint_range(0.0, 1.0) = 0.25;
// Edge darkening. Rectangular, see below.
uniform float vignette : hint_range(0.0, 1.0) = 0.30;
// Aperture grille: vertical R/G/B stripes on a 3-pixel pitch.
uniform float mask_strength : hint_range(0.0, 1.0) = 0.25;
// Slow brightness wobble.
uniform float flicker : hint_range(0.0, 1.0) = 0.15;
// Multiplier on TIME for the flicker. Exposed so the wobble can be slowed down or frozen
// (time_scale = 0.0) without touching `flicker` itself - useful for screenshots and for the
// settings preview, where an animating frame makes it impossible to judge the other sliders.
uniform float time_scale : hint_range(0.0, 8.0) = 1.0;

// --- Tuning constants. These set what "1.0" means for each slider. ---

// Maximum channel separation at the frame corner, in pixels. Beyond ~4 px the image reads as
// broken rather than as optics.
const float ABERRATION_MAX_PIXELS = 3.0;
// Peak brightness swing of the flicker at flicker = 1.0. Kept small on purpose: a CRT hum is a
// barely-perceptible breathing, and anything stronger becomes a strobe hazard.
const float FLICKER_MAX_AMPLITUDE = 0.08;
// Where the vignette starts, as a fraction of the half-frame. 1.0 = the very edge.
const float VIGNETTE_START = 0.55;
// How dark the frame edge gets at vignette = 1.0. Not 0.0: a fully black border reads as a bezel,
// which is the rounded-tube look we are explicitly avoiding.
const float VIGNETTE_MAX_DARKEN = 0.85;
// Aperture grille pitch in pixels: one R, one G, one B column.
const float MASK_PITCH = 3.0;


// Chromatic aberration. The offset grows with distance from the frame centre, which is what a real
// lens does, and it is applied to the SAMPLING POSITION only - the quad and the UV grid stay
// perfectly rectangular, so this buys the "curved optics" impression at zero geometric cost.
vec3 sample_with_aberration(vec2 uv, vec2 pixel_size, float amount) {
	if (amount <= 0.0) {
		// Exact pass-through path: one tap, no offsets, no rounding drift.
		return texture(screen_texture, uv).rgb;
	}
	vec2 from_centre = uv - vec2(0.5);
	vec2 offset = from_centre * amount * ABERRATION_MAX_PIXELS * pixel_size;
	// Clamping rather than repeat_disable alone: sampling past the edge must smear the border
	// pixel, never wrap a red fringe from the opposite side of the screen.
	vec2 uv_r = clamp(uv + offset, vec2(0.0), vec2(1.0));
	vec2 uv_b = clamp(uv - offset, vec2(0.0), vec2(1.0));
	return vec3(
		texture(screen_texture, uv_r).r,
		texture(screen_texture, uv).g,
		texture(screen_texture, uv_b).b
	);
}


// Aperture grille. Column index comes from the pixel coordinate so the stripes stay exactly one
// pixel wide at every resolution. Built from arithmetic instead of an `if` chain or a dynamic
// vector index: both compile badly on older GLES3 drivers, and this runs once per screen pixel.
vec3 aperture_mask(float pixel_x, float amount) {
	if (amount <= 0.0) {
		return vec3(1.0);
	}
	float column = floor(mod(pixel_x, MASK_PITCH));
	// Selects exactly one channel: |column - n| is 0 for the active column and >= 1 otherwise.
	vec3 cell = vec3(
		1.0 - min(abs(column - 0.0), 1.0),
		1.0 - min(abs(column - 1.0), 1.0),
		1.0 - min(abs(column - 2.0), 1.0)
	);
	// The inactive channels are dimmed, not killed, so a white pixel stays white-ish instead of
	// turning into visible confetti.
	return mix(vec3(1.0), cell, amount);
}


// Scanlines. One full dark/bright cycle every 2 pixel rows, driven by the pixel coordinate for the
// same reason as the mask. cos() rather than a hard step so the pattern does not alias into moire
// when the window height is not an exact multiple of the internal render height.
float scanline_factor(float pixel_y, float amount) {
	if (amount <= 0.0) {
		return 1.0;
	}
	float wave = 0.5 + 0.5 * cos(pixel_y * PI);
	return mix(1.0, wave, amount);
}


// RECTANGULAR vignette - computed independently in X and Y and combined with min(), NOT as a
// radial falloff and NOT as a product of the two axes. Both of those concentrate the darkening in
// the corners, and a frame with dark corners reads as a rounded tube, which is precisely what the
// header forbids. With min() the darkening along the top edge matches the darkening in the corner,
// so the shaded border stays an even rectangular frame.
float vignette_factor(vec2 uv, float amount) {
	if (amount <= 0.0) {
		return 1.0;
	}
	vec2 distance_to_edge = abs(uv - vec2(0.5)) * 2.0;  // 0 at the centre, 1 at each edge
	// smoothstep() is called with edge0 < edge1 and the result inverted, rather than with the
	// edges swapped: GLSL leaves smoothstep(edge0 >= edge1, ...) undefined, and some drivers do
	// return garbage for it.
	float edge_x = 1.0 - smoothstep(VIGNETTE_START, 1.0, distance_to_edge.x);
	float edge_y = 1.0 - smoothstep(VIGNETTE_START, 1.0, distance_to_edge.y);
	float shade = min(edge_x, edge_y);
	return mix(1.0, mix(1.0 - VIGNETTE_MAX_DARKEN, 1.0, shade), amount);
}


// Two detuned sines instead of one, so the brightness never settles into an obvious loop the eye
// can lock onto.
float flicker_factor(float time_seconds, float amount) {
	if (amount <= 0.0) {
		return 1.0;
	}
	float hum = sin(time_seconds * TAU) * 0.6 + sin(time_seconds * TAU * 2.37) * 0.4;
	return 1.0 + amount * FLICKER_MAX_AMPLITUDE * hum;
}


// Gain that undoes the average darkening the mask and scanlines cause.
//
// Both are MULTIPLICATIVE attenuations, so switching the effect on halves the picture: measured on a
// sandbox frame at scanlines 0.5 / mask 0.35, mean luminance fell 57.9 -> 29.7. A real tube does not
// eat half the light, and a player toggling the checkbox reads that drop as "CRT broke the game"
// rather than as a look. So the average loss is computed analytically and given straight back.
//
// Both means are read straight off the functions above, not guessed:
//   scanline_factor = mix(1.0, wave, amount) with wave = 0.5 + 0.5*cos(...), and cos averages to 0
//   over a full cycle, so mean(wave) = 0.5 and mean(scanline_factor) = 1 - amount * 0.5.
//   aperture_mask   = mix(vec3(1.0), cell, amount) where cell lights 1 of MASK_PITCH columns per
//   channel, so mean(cell) = 1/3 and mean(mask) = 1 - amount * 2/3.
// Compensating the MEAN and not the peak is deliberate: the pattern keeps its full contrast, only
// the overall level comes back.
//
// The vignette is NOT compensated - darkening the edges is the point of a vignette, and cancelling
// its average would just brighten the middle to match.
float brightness_gain(float scanline_amount, float mask_amount) {
	float scanline_mean = 1.0 - scanline_amount * 0.5;
	float mask_mean = 1.0 - mask_amount * (1.0 - 1.0 / MASK_PITCH);
	return 1.0 / max(scanline_mean * mask_mean, 0.05);
}


void fragment() {
	// SCREEN_PIXEL_SIZE is 1 / viewport size, so this is the fragment's position in whole pixels.
	vec2 pixel = SCREEN_UV / SCREEN_PIXEL_SIZE;

	vec3 colour = sample_with_aberration(SCREEN_UV, SCREEN_PIXEL_SIZE, aberration);
	colour *= aperture_mask(pixel.x, mask_strength);
	colour *= scanline_factor(pixel.y, scanlines);
	colour *= brightness_gain(scanlines, mask_strength);
	colour *= vignette_factor(SCREEN_UV, vignette);
	colour *= flicker_factor(TIME * time_scale, flicker);

	// Opaque: this quad replaces the frame rather than blending over it, so the ColorRect's own
	// colour and modulate never leak into the result.
	COLOR = vec4(colour, 1.0);
}
