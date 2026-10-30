#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;
// Animated-looking film grain (static per frame, cheap).
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void main() {
    vec4 c = texture(tex, v_texcoord);
    float n = (hash(gl_FragCoord.xy) - 0.5) * 0.09;
    fragColor = vec4(clamp(c.rgb + n, 0.0, 1.0), c.a);
}
