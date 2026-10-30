// lib/rings: rings of light spreading from a centre (window units), fading as they go out.
float rings_light(vec2 p, vec2 centre, float t, float px) {
    float d = length(p - centre);
    float wave = fract(d * 6.0 - t * 0.5);
    // a thin bright front, a soft trail behind it
    float front = exp(-abs(wave - 0.98) / (2.0 * px * 6.0)) * 0.6 + smoothstep(0.6, 0.98, wave) * 0.12;
    return front * exp(-d * 1.4);
}
