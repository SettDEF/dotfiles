#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;
// Banded / poster colours.
void main() {
    vec4 c = texture(tex, v_texcoord);
    fragColor = vec4(floor(c.rgb * 6.0) / 6.0, c.a);
}
