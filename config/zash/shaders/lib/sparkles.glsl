// lib/sparkles: points that twinkle near a height, drifting right (amount 0–2), each fading in
// on its own, their brightness exponential like stars.
#import "lib/hash"

float sparkles(vec2 p, float t, float h, float amount) {
    vec2 g = p * 14.0 + vec2(-t * 0.8, 0.0);
    vec2 id = floor(g);
    vec2 f = fract(g) - 0.5;
    float r = hash(id);
    // each fades in as amount passes it
    float on = smoothstep(1.0 - 0.18 * amount, 1.0 - 0.18 * amount + 0.03, r);
    if (on <= 0.0) return 0.0;
    // exponential brightness: a few bright among many faint
    float bright = exp(-5.0 * hash(id + 4.2)) * 1.6 + 0.1;
    vec2 o = vec2(hash(id + 1.3), hash(id + 2.7)) - 0.5;
    float s = exp(-length(f - o * 0.6) * 38.0) * (0.5 + 0.5 * sin(iTime * (1.5 + r * 3.0) + r * 40.0));
    return on * bright * s * smoothstep(0.35, 0.0, abs(p.y - h)) * 0.8;
}
