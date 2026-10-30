// PS3 Edition · coldboot: the console's start-up in spirit: streaks of light rushing in to a glowing
// horizon, a slow sheen breathing above it. Own code.
#import "lib/hash"
#import "lib/month"

const float TAU = 6.2831853;

// one ring of streaks round the vanishing point, each rushing in on its own clock
float streak_ring(vec2 d, float t, float n, float seed, float px) {
    float r = length(d);
    float a = atan(d.y, d.x) / TAU + 0.5;
    float cell = floor(a * n);
    float h = hash(vec2(cell, seed));
    float h2 = hash(vec2(seed, cell * 1.7));
    float across = abs(a - (cell + 0.2 + 0.6 * h) / n) * TAU * r;
    // the head comes in from far out; brightest at it, the tail longer the farther it is
    float head = 1.5 * (1.0 - fract(t * (0.18 + 0.3 * h2) + h));
    float len = 0.04 + 0.4 * head;
    float along = smoothstep(head + len, head, r) * smoothstep(head - 2.0 * px, head, r);
    float w = 1.2 * px + 0.003 * r;
    float line = exp(-across * across / (w * w));
    // not every cell has one; none right at the middle or farthest out
    return line * along * smoothstep(0.03, 0.18, r) * smoothstep(1.5, 1.0, head) * step(0.3, h2);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord + iOrigin * camera) / iScreen.y;
    float px = 1.0 / iScreen.y;
    float t = iPhase * 0.35;
    vec3 tc = tint(month);
    vec2 uv = fragCoord / iResolution.xy;
    vec2 mid = vec2(iScreen.x / iScreen.y * 0.5, height);
    float near = abs(p.y - height);

    // background: dark, the tint gathering at the horizon
    vec3 c = mix(iPanel.rgb * 0.7, iPanel.rgb * 0.6 + tc * 0.22 * glow, exp(-near * 3.5));

    // the sheen above the horizon, drifting
    float sheen = noise(vec2(p.x * 1.6 + t * 0.12, (p.y - height) * 5.0 - t * 0.05));
    c += tc * sheen * sheen * smoothstep(0.0, 0.25, p.y - height) * smoothstep(0.9, 0.25, p.y - height) * 0.35 * aurora;

    // streaks, flattened towards the horizon for depth
    vec2 d = vec2(p.x - mid.x, (p.y - mid.y) * 1.8);
    float s = streak_ring(d, t, 23.0, 1.0, px) + streak_ring(d, t * 0.8 + 0.37, 37.0, 2.0, px) * 0.6;
    c += mix(tc, vec3(1.0), 0.55) * s * streaks * (0.8 + 0.2 * iFocus);

    // the horizon: a thin bright line fading to the sides, its bloom breathing
    float breath = 0.85 + 0.15 * sin(t * 1.3);
    float line = exp(-pow(near / (1.5 * px + 0.0015), 2.0)) * exp(-pow(p.x - mid.x, 2.0) * 1.2);
    c += mix(tc, vec3(1.0), 0.7) * line * horizon * breath;
    c += tc * exp(-near * 16.0) * exp(-pow(p.x - mid.x, 2.0) * 0.8) * 0.4 * horizon * glow * breath;

    // calm at the panel's bottom, where the text sits
    c = mix(c, iPanel.rgb, smoothstep(0.35, 0.0, uv.y) * calm);
    fragColor = vec4(clamp(c, 0.0, 1.0), 1.0);
}
