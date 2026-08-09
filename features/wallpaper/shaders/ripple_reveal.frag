#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float aspect;
    float progress;
    float variant;
};
layout(binding = 1) uniform sampler2D source1;
layout(binding = 2) uniform sampler2D source2;

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 origin;
    if (variant < 0.5)
        origin = vec2(0.16, 0.76);
    else if (variant < 1.5)
        origin = vec2(0.84, 0.24);
    else if (variant < 2.5)
        origin = vec2(0.18, 0.20);
    else if (variant < 3.5)
        origin = vec2(0.82, 0.80);
    else if (variant < 4.5)
        origin = vec2(0.10, 0.48);
    else
        origin = vec2(0.90, 0.52);
    vec2 scale = vec2(aspect, 1.0);
    vec2 p = (uv - origin) * scale;
    float distanceFromCenter = length(p);
    float maxDistance = max(
        max(length(-origin * scale), length((vec2(1.0, 0.0) - origin) * scale)),
        max(length((vec2(0.0, 1.0) - origin) * scale), length((vec2(1.0) - origin) * scale))
    );
    float radius = mix(-0.12, maxDistance + 0.12, progress);

    // Constrain the ripple to the moving front, so the wallpaper remains
    // readable instead of looking like it is permanently under water.
    float distanceToFront = distanceFromCenter - radius;
    float rippleBand = 1.0 - smoothstep(0.0, 0.18, abs(distanceToFront));
    float ripple = sin(distanceFromCenter * 78.0 - progress * 24.0) * 0.010 * rippleBand;
    float edge = 0.030;
    float signedDistance = distanceToFront + ripple;
    float reveal = 1.0 - smoothstep(-edge, edge, signedDistance);

    float edgeBand = 1.0 - smoothstep(0.0, edge * 3.0, abs(signedDistance));
    vec2 direction = p / max(distanceFromCenter, 0.001);
    vec2 refraction = direction * edgeBand * 0.010;
    vec4 outgoing = texture(source1, uv + refraction);
    vec4 incoming = texture(source2, uv - refraction);
    vec4 color = mix(outgoing, incoming, reveal);
    color.rgb += (vec3(1.0) - color.rgb) * edgeBand * 0.06;
    fragColor = color * qt_Opacity;
}
