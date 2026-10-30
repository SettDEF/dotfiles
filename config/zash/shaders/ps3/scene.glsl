// PS3 Edition · scene: every element in one scene (background, the wave band and its silk
// ribbons, sparkles, dust and its bokeh, rings), each with its own options. The presets (pack.toml) are this scene with values;
// switching preset morphs them, so the band can break up into the dust and back.
#import "lib/hash"
#import "lib/month"
#import "lib/band"
#import "lib/sparkles"
#import "lib/dust"
#import "lib/rings"

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // the scene in window units (1 = the window's height): the panel is a camera over it
    vec2 p = (fragCoord + iOrigin * camera) / iScreen.y;
    float px = 1.0 / iScreen.y;
    float t = iPhase * 0.35;
    vec3 tc = tint(month);
    vec2 uv = fragCoord / iResolution.xy;

    // background: the panel colour, a little of the tint towards the top of the window
    vec3 c = mix(iPanel.rgb * 0.85, mix(iPanel.rgb, tc, 0.18 * glow), smoothstep(0.0, 1.2, p.y + p.x * 0.15));

    // the band (breaking up as it scatters) and its sheen
    float b = band_light(p, t, lines, height, width, scatter, px) * band;
    c = mix(c, tc, clamp(band_sheen(p, t, lines, height) * band * (1.0 - scatter) * (1.0 - width), 0.0, 1.0));
    c += tc * 0.9 * b * (0.75 + 0.25 * iFocus) + vec3(b * 0.15);

    // sparkles caught near the band
    c += vec3(sparkles(p, t, height, sparkles_amount));

    // dust in depth
    c += mix(tc, vec3(1.0), 0.35) * dust_light(fragCoord, iPhase * 0.05, dust, size, camera) * glow;

    // rings spreading from the middle of the window
    c += mix(tc, vec3(1.0), 0.25) * rings_light(p, vec2(iScreen.x / iScreen.y * 0.5, height), iPhase, px) * rings;

    // calm at the panel's bottom, where the text sits
    c = mix(c, iPanel.rgb, smoothstep(0.35, 0.0, uv.y) * calm);
    fragColor = vec4(clamp(c, 0.0, 1.0), 1.0);
}
