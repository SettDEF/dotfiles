// PS3 Edition · tide: a night sea of light. A grid surface in perspective rolls in slow swells,
// its lines glowing out to a bright horizon, a soft glow mirrored in it, stars above. Own code.
#import "lib/hash"
#import "lib/month"

// the swell: a few slow waves crossing (x across, z into the distance)
float swell(vec2 w, float t) {
    return 0.22 * sin(w.y * 0.55 - t * 0.9)
         + 0.13 * sin(w.x * 0.35 + w.y * 0.31 - t * 0.6)
         + 0.07 * sin(w.x * 0.9 - w.y * 0.8 + t * 1.3);
}

// a glowing grid line where `v` crosses a whole number, `fw` wide (its pixel footprint)
float gridline(float v, float fw) {
    float d = abs(fract(v + 0.5) - 0.5);
    return exp(-d * d / (fw * fw));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord + iOrigin * camera) / iScreen.y;
    float px = 1.0 / iScreen.y;
    float t = iPhase * 0.35 * speed;
    vec3 tc = tint(month);
    vec2 uv = fragCoord / iResolution.xy;
    float mx = iScreen.x / iScreen.y * 0.5;
    float below = height - p.y;

    // the sky: dark, the tint gathering low over the water
    vec3 c = mix(iPanel.rgb * 0.65, iPanel.rgb * 0.55 + tc * 0.25 * glow, exp(-abs(below) * 4.0));

    if (below > 0.0) {
        // the sea: each pixel below the horizon is a point on the plane, farther the nearer the horizon
        float z = 0.35 / below;
        vec2 w = vec2((p.x - mx) * z * 2.2, z * 3.0 + t * 1.5);
        float h = swell(w, t) * waves;
        // how much plane one pixel covers, so the lines stay a pixel or two at every distance
        float fz = 0.35 / (below * below) * px * 3.0;
        float fx = z * px * 2.2;
        float rows = gridline(w.y * 0.5 + h, fz * 0.5 + 0.02);
        float cols = gridline(w.x * 0.5 + h * 0.4, fx * 0.5 + 0.02);
        // lines brighter on a crest, gone into the haze far out
        float crest = 0.6 + 0.8 * smoothstep(-0.2, 0.3, h);
        float haze = smoothstep(0.0, 0.08, below);
        float lines = max(rows, cols * 0.7) * crest * haze * grid;
        c += mix(tc, vec3(1.0), 0.35) * lines * 0.75;
        // the glow mirrored in the water: a column under it, broken by the swell
        float column = exp(-pow((p.x - mx) * (3.0 + 6.0 * below), 2.0)) * exp(-below * 2.5);
        float ripple = 0.5 + 0.5 * sin(w.y * 2.3 + h * 9.0 - t * 2.0);
        c += tc * column * ripple * 0.45 * glow * moon;
    } else {
        // stars: sparse, twinkling, thinning towards the horizon
        vec2 cell = floor(p * 60.0);
        float s = hash(cell);
        vec2 at = (cell + vec2(hash(cell + 1.7), hash(cell + 3.1))) / 60.0;
        float tw = 0.5 + 0.5 * sin(t * (1.5 + 3.0 * s) + s * 40.0);
        float star = step(0.985, s) * exp(-dot(p - at, p - at) / (px * px * 2.5)) * tw;
        c += mix(tc, vec3(1.0), 0.8) * star * stars * smoothstep(0.0, 0.25, -below);
        // the glow itself, low over the water
        c += tc * exp(-dot(vec2((p.x - mx) * 1.4, -below * 3.0), vec2((p.x - mx) * 1.4, -below * 3.0)) * 6.0) * 0.5 * glow * moon;
    }

    // the horizon: a thin bright line, its bloom slowly breathing
    float breath = 0.85 + 0.15 * sin(t * 0.9);
    c += mix(tc, vec3(1.0), 0.6) * exp(-pow(below / (1.5 * px + 0.0012), 2.0)) * exp(-pow(p.x - mx, 2.0) * 0.6) * horizon * breath;
    c += tc * exp(-abs(below) * 18.0) * 0.35 * horizon * glow * breath;

    // calm at the panel's bottom, where the text sits
    c = mix(c, iPanel.rgb, smoothstep(0.35, 0.0, uv.y) * calm);
    fragColor = vec4(clamp(c, 0.0, 1.0), 1.0);
}
