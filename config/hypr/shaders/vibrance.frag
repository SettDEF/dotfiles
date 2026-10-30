#version 300 es
// Vibrance — from hyprshade (https://github.com/loqusion/hyprshade), MIT License,
// Copyright (c) 2023 loqusion. Based on SweetFX Vibrance by CeeJay.
// Tuned for FPS visibility: Strength 0.30 (template default 0.15). Range -1..1.
/*
 * Vibrance
 *
 * Enhance color saturation.
 * Also supports per-channel multipliers.
 *
 * Source: https://github.com/hyprwm/Hyprland/issues/1140#issuecomment-1614863627
 */

precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

// see https://github.com/CeeJayDK/SweetFX/blob/a792aee788c6203385a858ebdea82a77f81c67f0/Shaders/Vibrance.fx#L20-L30

/**
 * Per-channel multiplier to vibrance strength.
 *
 * @min 0.0
 * @max 10.0
 */
const vec3 Balance = vec3(
    float(1.0),
    float(1.0),
    float(1.0)
);

/**
 * Strength of filter.
 * (Negative values will reduce vibrance.)
 *
 * @min -1.0
 * @max 1.0
 */
const float Strength = float(0.30);

const vec3 VIB_coeffVibrance = Balance * -Strength;

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    vec3 color = pixColor.rgb;

    vec3 VIB_coefLuma = vec3(0.212656, 0.715158, 0.072186);
    float luma = dot(VIB_coefLuma, color);

    float max_color = max(color.r, max(color.g, color.b));
    float min_color = min(color.r, min(color.g, color.b));
    float color_saturation = max_color - min_color;

    vec3 p_col = (sign(VIB_coeffVibrance) * color_saturation - 1.0) * VIB_coeffVibrance + 1.0;

    vec3 adjustedColor = mix(vec3(luma), color, p_col);
    fragColor = vec4(adjustedColor, pixColor.a);
}

// vim: ft=glsl
