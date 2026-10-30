#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;
// CRT: scanlines + subtle RGB mask + vignette.
void main() {
    vec4 c = texture(tex, v_texcoord);
    float sl = 0.88 + 0.12 * sin(v_texcoord.y * 1400.0);
    vec3 col = c.rgb * sl;
    float m = mod(gl_FragCoord.x, 3.0);
    col *= vec3(m < 1.0 ? 1.06 : 0.96, (m >= 1.0 && m < 2.0) ? 1.06 : 0.96, m >= 2.0 ? 1.06 : 0.96);
    vec2 p = v_texcoord - 0.5;
    col *= mix(0.55, 1.0, smoothstep(0.95, 0.2, length(p)));
    fragColor = vec4(clamp(col, 0.0, 1.0), c.a);
}
