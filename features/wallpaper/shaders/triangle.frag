#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf { mat4 qt_Matrix; float qt_Opacity; float aspect; float progress; };
layout(binding = 1) uniform sampler2D source1;
layout(binding = 2) uniform sampler2D source2;
void main() {
    vec2 p = qt_TexCoord0 - vec2(0.5);
    p.x *= aspect;
    float dist = max(abs(p.x) * 0.866025 + p.y * 0.5, -p.y);
    float maxDist = max(aspect, 1.0) * 1.5;
    float edge = 0.05;
    float currentSize = progress * (maxDist + edge);
    float blend = smoothstep(currentSize - edge, currentSize, dist);
    fragColor = mix(texture(source2, qt_TexCoord0), texture(source1, qt_TexCoord0), blend) * qt_Opacity;
}
