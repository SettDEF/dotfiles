#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;
void main() {
    vec4 c = texture(tex, v_texcoord);
    float l = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
    fragColor = vec4(clamp(vec3(l * 0.15, l * 1.5, l * 0.25), 0.0, 1.0), c.a);
}
