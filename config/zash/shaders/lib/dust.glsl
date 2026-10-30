// lib/dust: light in four layers of depth, nearer ones bigger and faster; each point's brightness
// is exponential (many faint, few bright, like stars). size 0: points … 1: bokeh, large soft discs
// in their own fixed grid (the points fade and widen as the discs come, nothing slides). amount
// fades points in and out one by one. camera (0–1): how much the layers move with the panel.
#import "lib/hash"

// brightness of a star from its random number: exponential, a few bright ones among many faint
float star_bright(float u) {
    return exp(-5.0 * u) * 1.6 + 0.08;
}

float dust_points(vec2 fragCoord, float t, float amount, float grow, float camera) {
    float sum = 0.0;
    for (int l = 0; l < 4; l++) {
        float z = float(l) / 3.0;
        vec2 p = (fragCoord + iOrigin * camera * mix(0.35, 1.0, z)) / iScreen.y;
        vec2 g = p * mix(22.0, 7.0, z) + vec2(t * mix(1.0, 3.0, z), sin(t + z * 5.0) * 0.3) + float(l) * 17.0;
        vec2 id = floor(g);
        vec2 f = fract(g) - 0.5;
        float r = hash(id);
        // each point fades in as amount passes its own threshold
        float on = smoothstep(r, r + 0.04, 0.16 * amount);
        if (on <= 0.0) continue;
        vec2 o = (vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5) * 0.7;
        float tw = 0.75 + 0.25 * sin(iTime * (0.8 + r * 6.0) + r * 50.0);
        float sharp = mix(40.0, 18.0, z) / (1.0 + 3.0 * grow);
        sum += on * exp(-length(f - o) * sharp) * tw * star_bright(hash(id + 5.3)) * mix(0.35, 0.9, z);
    }
    return sum;
}

float bokeh_discs(vec2 fragCoord, float t, float camera) {
    float sum = 0.0;
    for (int l = 0; l < 2; l++) {
        float z = float(l);
        vec2 p = (fragCoord + iOrigin * camera * mix(0.5, 1.0, z)) / iScreen.y;
        vec2 g = p * mix(5.0, 2.8, z) + vec2(t * mix(0.6, 1.2, z), sin(t * 0.7 + z * 3.0) * 0.2) + 41.0 * z;
        vec2 id = floor(g);
        vec2 f = fract(g) - 0.5;
        float r = hash(id + 9.1);
        if (r > 0.45) continue;
        vec2 o = (vec2(hash(id + 3.3), hash(id + 6.6)) - 0.5) * 0.35;
        float d = length(f - o);
        float rad = mix(0.18, 0.32, hash(id + 1.9));
        float disc = (1.0 - smoothstep(rad * 0.82, rad, d)) * 0.22 + exp(-abs(d - rad * 0.92) * 60.0) * 0.16;
        sum += disc * star_bright(hash(id + 2.4)) * mix(0.6, 1.0, z);
    }
    return sum;
}

float dust_light(vec2 fragCoord, float t, float amount, float size, float camera) {
    return dust_points(fragCoord, t, amount * (1.0 - size), size, camera) + bokeh_discs(fragCoord, t, camera) * amount * size;
}
