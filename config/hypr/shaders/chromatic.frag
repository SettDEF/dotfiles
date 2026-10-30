#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;
// Chromatic aberration: RGB channels split toward the edges.
void main() {
    vec2 d = (v_texcoord - 0.5) * 0.004;
    float r = texture(tex, v_texcoord + d).r;
    float g = texture(tex, v_texcoord).g;
    float b = texture(tex, v_texcoord - d).b;
    fragColor = vec4(r, g, b, texture(tex, v_texcoord).a);
}
