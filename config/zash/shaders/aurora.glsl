// A slow aurora in the panel's own colours (zash panel shader, Shadertoy style).
// iPanel: the panel's colour, iAccent: the accent, iFocus: 1 while it has the keyboard.
float wave(vec2 p, float t, float k) {
    return sin(p.x * k + t) * 0.5 + sin(p.x * k * 0.37 - t * 1.3 + p.y * 2.0) * 0.5;
}

// a ribbon: a sharp core (about 2 px) plus a narrow glow, so it reads as a line, not a smear
float ribbon(float d, float px) {
    float core = 1.0 - smoothstep(0.0, 1.5 * px, d);
    float glow = exp(-d / (14.0 * px)) * 0.45;
    return max(core, glow);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float px = 1.0 / iResolution.y;
    float t = iTime * 0.25;
    // two ribbons drifting across the upper part
    float a = ribbon(abs(uv.y - 0.72 - 0.08 * wave(uv, t, 3.0)), px);
    float b = ribbon(abs(uv.y - 0.55 - 0.10 * wave(uv + 3.1, t * 0.8, 2.2)), px);
    float glow = (a * 0.6 + b * 0.4) * (0.45 + 0.15 * iFocus);
    vec3 c = mix(iPanel.rgb, iAccent.rgb, glow);
    // a faint darkening towards the bottom, so the text there stays calm
    c *= mix(0.92, 1.0, uv.y);
    fragColor = vec4(c, 1.0);
}
