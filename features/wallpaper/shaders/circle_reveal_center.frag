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
        origin = vec2(0.18, 0.20);
    else if (variant < 1.5)
        origin = vec2(0.84, 0.18);
    else if (variant < 2.5)
        origin = vec2(0.82, 0.78);
    else if (variant < 3.5)
        origin = vec2(0.18, 0.80);
    else if (variant < 4.5)
        origin = vec2(0.10, 0.48);
    else if (variant < 5.5)
        origin = vec2(0.90, 0.52);
    else if (variant < 6.5)
        origin = vec2(0.48, 0.12);
    else
        origin = vec2(0.55, 0.88);

    vec2 scale = vec2(aspect, 1.0);
    vec2 p = (uv - origin) * scale;
    float distanceFromCenter = length(p);
    vec2 farthestCorner = max(origin, vec2(1.0) - origin) * scale;
    float maxDistance = length(farthestCorner);

    // A small ripple and refraction turn this from a flat PowerPoint iris
    // into a soft lens moving across the two wallpapers.
    float edge = 0.028;
    float radius = mix(-0.10, maxDistance + 0.10, progress);
    float ripple = sin(distanceFromCenter * 56.0 - progress * 16.0) * 0.006;
    float signedDistance = distanceFromCenter - radius + ripple;
    float reveal = 1.0 - smoothstep(-edge, edge, signedDistance);

    float edgeBand = 1.0 - smoothstep(0.0, edge * 2.8, abs(signedDistance));
    vec4 color;
    if (edgeBand <= 0.0) {
        color = reveal < 0.5 ? sample1(uv) : sample2(uv);
    } else {
        vec2 direction = p / max(distanceFromCenter, 0.001);
        vec2 refraction = direction * edgeBand * 0.006;
        color = mix(sample1(uv + refraction), sample2(uv - refraction), reveal);
    }

    // Keep the edge neutral so it works with any generated colour scheme.
    color.rgb += (vec3(1.0) - color.rgb) * edgeBand * 0.08;
    fragColor = vec4(color.rgb * qt_Opacity, 1.0);
}
