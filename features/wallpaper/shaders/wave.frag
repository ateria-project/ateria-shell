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

    // Two low-amplitude waves make a fluid front without the harsh, regular
    // sine wave that made the previous wipe feel mechanical. Variants change
    // the travel direction instead of merely mirroring the same frame.
    float coordinate;
    float perpendicular;
    vec2 travelDirection;
    if (variant < 0.5) {
        coordinate = uv.x;
        perpendicular = uv.y;
        travelDirection = vec2(1.0, 0.0);
    } else if (variant < 1.5) {
        coordinate = 1.0 - uv.x;
        perpendicular = uv.y;
        travelDirection = vec2(-1.0, 0.0);
    } else if (variant < 2.5) {
        coordinate = uv.y;
        perpendicular = uv.x;
        travelDirection = vec2(0.0, 1.0);
    } else {
        coordinate = 1.0 - uv.y;
        perpendicular = uv.x;
        travelDirection = vec2(0.0, -1.0);
    }
    float wave = sin(perpendicular * 8.0 + progress * 1.7 + variant * 0.7) * 0.024
        + sin(perpendicular * 18.0 - progress * 2.4 + 0.8 + variant * 1.1) * 0.010;
    float edge = 0.032;
    float waveAmplitude = 0.034;
    float front = mix(0.0, 1.0 + edge + waveAmplitude, progress);
    float signedDistance = coordinate - front + wave;
    float reveal = 1.0 - smoothstep(-edge, edge, signedDistance);

    float edgeBand = 1.0 - smoothstep(0.0, edge * 2.5, abs(signedDistance));
    vec4 color;
    if (edgeBand <= 0.0) {
        color = reveal < 0.5 ? sample1(uv) : sample2(uv);
    } else {
        vec2 refraction = travelDirection * edgeBand * 0.008;
        color = mix(sample1(uv + refraction), sample2(uv - refraction), reveal);
    }
    color.rgb += (vec3(1.0) - color.rgb) * edgeBand * 0.07;
    fragColor = vec4(color.rgb * qt_Opacity, 1.0);
}
