#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float aspect;
    float progress;
    float variant;
    vec4 crop1;
    vec4 crop2;
};
layout(binding = 1) uniform sampler2D source1;
layout(binding = 2) uniform sampler2D source2;

vec4 sample1(vec2 uv) { return texture(source1, uv * crop1.xy + crop1.zw); }
vec4 sample2(vec2 uv) { return texture(source2, uv * crop2.xy + crop2.zw); }

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
    vec2 farthestCorner = max(origin, vec2(1.0) - origin) * scale;
    float maxDistance = length(farthestCorner);
    float edge = 0.030;
    float rippleAmount = 0.010;
    float radius = mix(0.0, maxDistance + edge + rippleAmount, progress);

    // Constrain the ripple to the moving front, so the wallpaper remains
    // readable instead of looking like it is permanently under water.
    float distanceToFront = distanceFromCenter - radius;
    float rippleBand = 1.0 - smoothstep(0.0, 0.18, abs(distanceToFront));
    float ripple = sin(distanceFromCenter * 78.0 - progress * 24.0) * rippleAmount * rippleBand;
    float signedDistance = distanceToFront + ripple;
    float reveal = 1.0 - smoothstep(-edge, edge, signedDistance);

    float edgeBand = 1.0 - smoothstep(0.0, edge * 3.0, abs(signedDistance));
    vec4 color;
    if (edgeBand <= 0.0) {
        color = reveal < 0.5 ? sample1(uv) : sample2(uv);
    } else {
        vec2 direction = p / max(distanceFromCenter, 0.001);
        vec2 refraction = direction * edgeBand * 0.010;
        color = mix(sample1(uv + refraction), sample2(uv - refraction), reveal);
    }
    color.rgb += (vec3(1.0) - color.rgb) * edgeBand * 0.06;
    fragColor = vec4(color.rgb * qt_Opacity, 1.0);
}
