// PS3 Edition · xmb: the menu as it looks. A deep gradient in the month's colour, lighter at the
// top; soft see-through sheets of light gliding over each other, their edges bright; faint specks
// of light drifting. Own code.
#import "lib/hash"
#import "lib/month"

// one sheet: its middle line and half its thickness across x, at time t
vec2 sheet(float x, float t, float seed) {
    float mid = 0.035 * sin(x * 1.7 + t * 0.55 + seed * 2.1)
              + 0.022 * sin(x * 3.1 - t * 0.38 + seed * 5.3)
              + 0.010 * sin(x * 6.3 + t * 0.9 + seed);
    float half_ = 0.055 + 0.04 * sin(x * 2.3 - t * 0.47 + seed * 3.7) + 0.015 * sin(x * 5.1 + t * 0.31 + seed);
    return vec2(mid, max(half_, 0.006));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord + iOrigin * camera) / iScreen.y;
    vec2 uv = fragCoord / iResolution.xy;
    float px = 1.0 / iScreen.y;
    float t = iPhase * 0.35 * speed;
    float aspect = iScreen.x / iScreen.y;
    // the base colour: the month's (the PS3's), or the theme's accent; strong and deep
    vec3 hue = tint(month);

    // the background: dark at the bottom, the colour rising to the top, a soft light up and left
    // of the middle, the corners darker
    float sy = clamp(p.y, 0.0, 1.0);
    vec3 c = mix(hue * 0.16, hue * 0.62, smoothstep(0.0, 1.05, sy));
    vec2 lp = vec2(p.x - aspect * 0.42, p.y - 0.78);
    c += hue * 0.38 * exp(-dot(lp, lp) * 2.2) * glow;
    vec2 v = uv - 0.5;
    c *= 1.0 - 0.55 * dot(v, v);

    // the sheets: each a band of soft light, brightest at its two edges, see-through in between
    float y0 = height;
    vec3 light = vec3(0.0);
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        vec2 s = sheet(p.x * (1.0 + 0.15 * fi), t * (1.0 - 0.18 * fi), fi * 1.37);
        float d = p.y - (y0 + s.x + (fi - 1.0) * 0.012);
        float inside = smoothstep(s.y + 2.0 * px, s.y - 2.0 * px, abs(d));
        // the edges: a fine bright line and a softer glow round it
        float e = abs(abs(d) - s.y);
        float edge = exp(-e * e / (px * px * 2.2)) * 0.45 + exp(-e * e / (px * px * 80.0)) * 0.18;
        // the body: a faint wash, a little brighter towards its top edge (light from above)
        float body = inside * (0.10 + 0.16 * smoothstep(-s.y, s.y, d));
        // sheets fade out towards the sides and come and go slowly
        float side = smoothstep(-0.1, 0.35, p.x) * smoothstep(aspect + 0.1, aspect - 0.35, p.x);
        float breathe = 0.75 + 0.25 * sin(t * 0.33 + fi * 2.0);
        light += (body + edge * waves) * side * breathe * (1.0 - 0.22 * fi);
    }
    c += mix(vec3(1.0), hue * 1.4 + 0.3, 0.25) * light;

    // specks of light drifting slowly up and sideways, faint, twinkling
    vec2 q = p * 14.0 + vec2(t * 0.25, t * 0.12);
    vec2 cell = floor(q);
    float h = hash(cell);
    vec2 at = cell + vec2(hash(cell + 2.3), hash(cell + 5.1));
    float tw = 0.5 + 0.5 * sin(t * (1.2 + 2.5 * h) + h * 30.0);
    float speck = step(0.93, h) * exp(-dot(q - at, q - at) * 60.0) * tw;
    c += vec3(1.0) * speck * 0.35 * specks * smoothstep(0.0, 0.25, abs(p.y - y0));

    // calm at the panel's bottom, where the text sits: the colour deepens, the light stays out
    c = mix(c, hue * 0.12, smoothstep(0.35, 0.0, uv.y) * calm);
    // made as it should look on screen: back to linear, as the panel is written out as sRGB (the
    // dark depths came out milky otherwise)
    fragColor = vec4(pow(clamp(c, 0.0, 1.0), vec3(2.2)), 1.0);
}
