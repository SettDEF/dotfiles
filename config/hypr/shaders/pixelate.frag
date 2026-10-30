#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;
// Chunky pixels.
void main() {
    vec2 px = vec2(1.0) / vec2(320.0, 200.0);
    fragColor = texture(tex, floor(v_texcoord / px) * px + px * 0.5);
}
