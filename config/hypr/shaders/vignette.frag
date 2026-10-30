#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;
// Darkens the edges of the screen.
void main() {
    vec4 c = texture(tex, v_texcoord);
    vec2 p = v_texcoord - 0.5;
    float v = smoothstep(0.85, 0.25, length(p));
    fragColor = vec4(c.rgb * mix(0.45, 1.0, v), c.a);
}
