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
    vec2 beamOrigin;
    if (variant < 0.5)
        beamOrigin = vec2(0.5);
    else if (variant < 1.5)
        beamOrigin = vec2(0.34, 0.42);
    else if (variant < 2.5)
        beamOrigin = vec2(0.66, 0.58);
    else if (variant < 3.5)
        beamOrigin = vec2(0.50, 0.30);
    else
        beamOrigin = vec2(0.50, 0.70);
    vec2 distanceFromCenter = abs(uv - beamOrigin);

    // Let a horizontal CRT beam form first, then open vertically. The wide
    // soft edges are deliberate; narrow hard beams read as a rendering glitch.
    float horizontal = smoothstep(0.0, 0.28, progress);
    float vertical = smoothstep(0.18, 1.0, progress);
    float halfWidth = mix(0.0, 0.76, horizontal);
    float halfHeight = mix(0.0, 0.76, vertical);
    float edge = 0.024;
    float outsideX = smoothstep(halfWidth, halfWidth + edge, distanceFromCenter.x);
    float outsideY = smoothstep(halfHeight, halfHeight + edge, distanceFromCenter.y);
    float reveal = 1.0 - max(outsideX, outsideY);

    float horizontalEdge = (1.0 - smoothstep(0.0, edge, abs(distanceFromCenter.x - halfWidth))) * (1.0 - outsideY);
    float verticalEdge = (1.0 - smoothstep(0.0, edge, abs(distanceFromCenter.y - halfHeight))) * (1.0 - outsideX);
    float glow = max(horizontalEdge, verticalEdge) * smoothstep(0.03, 0.16, progress) * (1.0 - smoothstep(0.84, 1.0, progress));

    vec4 color;
    if (reveal <= 0.0)
        color = sample1(uv);
    else if (reveal >= 1.0)
        color = sample2(uv);
    else
        color = mix(sample1(uv), sample2(uv), reveal);
    color.rgb += (vec3(1.0) - color.rgb) * glow * 0.12;
    fragColor = vec4(color.rgb * qt_Opacity, 1.0);
}
