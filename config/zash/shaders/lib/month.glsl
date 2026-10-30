// lib/month: the PS3's colour for each month (roughly); tint(k): the accent at 0, the month's at 1.
vec3 month_color() {
    vec3 m[12] = vec3[12](
        vec3(0.75, 0.78, 0.82), vec3(0.85, 0.70, 0.25), vec3(0.45, 0.75, 0.25), vec3(0.90, 0.50, 0.65),
        vec3(0.25, 0.65, 0.30), vec3(0.65, 0.35, 0.75), vec3(0.20, 0.70, 0.75), vec3(0.30, 0.55, 0.90),
        vec3(0.50, 0.35, 0.85), vec3(0.85, 0.55, 0.20), vec3(0.60, 0.35, 0.25), vec3(0.85, 0.25, 0.25));
    return m[iMonth - 1];
}

vec3 tint(float k) {
    return mix(iAccent.rgb, month_color(), k);
}
