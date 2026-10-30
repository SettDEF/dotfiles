#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;
// Clearsight: visibility for dark shooters — clarity, shadow lift, then vibrance on muted colours.
// Tune the three constants; 0 turns a stage off.
const float CLARITY  = 0.40;  // edge/detail boost, 0..1 — silhouettes against backgrounds
const float SHADOWS  = 1.20;  // dark lift, 0..4 — black stays black, white stays white
const float VIBRANCE = 0.25;  // muted-colour boost, 0..1 — leaves saturated colours alone

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

// The shadow curve, x + k·x·(1−x)^4: 0 and 1 stay put, never exceeds 1, monotonic for k < 4.6.
float lift(float x) { float i = 1.0 - x; return x + SHADOWS * x * i * i * i * i; }

void main() {
    vec2 px = 1.0 / vec2(textureSize(tex, 0));
    vec4 src = texture(tex, v_texcoord);
    vec3 c = src.rgb;

    // 1. CLARITY — clamped unsharp mask: push the pixel away from its 4-neighbour average, then clamp
    //    to the neighbourhood's own min/max so a boosted edge can never overshoot into a halo.
    vec3 n = texture(tex, v_texcoord + vec2(0.0, px.y)).rgb;
    vec3 s = texture(tex, v_texcoord - vec2(0.0, px.y)).rgb;
    vec3 e = texture(tex, v_texcoord + vec2(px.x, 0.0)).rgb;
    vec3 w = texture(tex, v_texcoord - vec2(px.x, 0.0)).rgb;
    vec3 lo = min(c, min(min(n, s), min(e, w)));
    vec3 hi = max(c, max(max(n, s), max(e, w)));
    c = clamp(c + (c - (n + s + e + w) * 0.25) * CLARITY * 2.0, lo, hi);

    // 2. SHADOWS — the lift is decided on luminance AND on the brightest channel, taking the smaller.
    //    Luminance alone treats a saturated red as a shadow (pure red is ~21% luma) and drives its red
    //    channel past 1; capping at 1 still maps every bright red to the same value and flattens the
    //    gradient. lift(peak) never exceeds 1 and stays monotonic, so bright colours keep their order.
    //    Channels scale together, so hue survives.
    float l = dot(c, LUMA);
    float peak = max(c.r, max(c.g, c.b));
    c *= min(lift(l) / max(l, 1e-4), lift(peak) / max(peak, 1e-4));

    // 3. VIBRANCE — saturation boost weighted by how UNsaturated the pixel already is.
    float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
    float y = dot(c, LUMA);
    float k = 1.0 + VIBRANCE * (1.0 - sat);
    // same gamut limit: the saturation push stops where a channel would leave 0..1
    float cmax = max(c.r, max(c.g, c.b)), cmin = min(c.r, min(c.g, c.b));
    if (cmax > y) k = min(k, (1.0 - y) / (cmax - y));
    if (cmin < y) k = min(k, y / (y - cmin));
    c = mix(vec3(y), c, max(k, 1.0));

    fragColor = vec4(clamp(c, 0.0, 1.0), src.a);
}
