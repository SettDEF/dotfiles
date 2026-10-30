// lib/band: the menu wave. n lines (fractional: a line fades in or out as n passes it), width
// 0 thin lines … 1 broad silk ribbons that fold and catch light where they lie flat, scatter
// 0 … 1 breaks the lines into pieces that shrink to points and drift apart (into dust).
#import "lib/hash"

float band_wave(float x, float t, float k) {
    return 0.10 * sin(x * 2.1 + t * 0.9 + k * 0.35)
         + 0.05 * sin(x * 4.7 - t * 0.6 + k * 0.80)
         + 0.025 * sin(x * 9.3 + t * 1.4 + k * 1.30);
}

// light of the band at p (window units), centre height h, px one pixel
float band_light(vec2 p, float t, float n, float h, float width, float scatter, float px) {
    // ribbons sit further apart than lines
    float gap = mix(0.008, 0.07, width);
    float sum = 0.0;
    for (int i = 0; i < 32; i++) {
        float k = float(i);
        float here = clamp(n - k, 0.0, 1.0);
        if (here <= 0.0) break;
        // numbered from the middle out, up and down in turn: fewer lines close in on the middle
        float o = mod(k, 2.0) < 0.5 ? k * 0.5 : -(k + 1.0) * 0.5;
        float piece = floor(p.x * 18.0 + k * 3.1);
        float drift = (hash(vec2(piece, k)) - 0.5) * 0.35 * scatter * scatter;
        float y = h + o * gap + band_wave(p.x, t, o) + drift;
        float d = abs(p.y - y);
        float w = 1.0 - abs(o) / (n * 0.5 + 1.0);
        // pieces shorten as it scatters, down to a point each
        float f = fract(p.x * 18.0 + k * 3.1);
        float len = mix(1.0, 0.06, scatter);
        float keep = 1.0 - smoothstep(len * 0.5 - 0.02, len * 0.5 + 0.02, abs(f - 0.5));
        // a line: a sharp core and a halo
        float line = (1.0 - smoothstep(0.0, mix(1.2, 2.5, scatter) * px, d)) * 0.55 + exp(-d / (10.0 * px)) * 0.10;
        // a ribbon: a sheet of half-width hw, light at its edges and where it lies flat (its fold)
        float hw = 0.035;
        float slope = (band_wave(p.x + 0.01, t, o) - band_wave(p.x - 0.01, t, o)) / 0.02;
        float sheet = (1.0 - smoothstep(hw * 0.7, hw, d)) * (0.10 + 0.35 * exp(-abs(slope) * 3.0));
        float rim = exp(-abs(d - hw) / (1.5 * px)) * 0.35;
        sum += here * w * keep * mix(line, sheet + rim, width);
    }
    return sum * 14.0 / max(mix(n, 4.0, width), 1.0);
}

// the wide soft sheen under the band, so it reads as one ribbon of light
float band_sheen(vec2 p, float t, float n, float h) {
    return exp(-abs(p.y - h - band_wave(p.x, t, 0.0)) * 9.0) * 0.18;
}
