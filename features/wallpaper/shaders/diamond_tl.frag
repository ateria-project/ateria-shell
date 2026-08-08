#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf { mat4 qt_Matrix; float qt_Opacity; float aspect; float progress; };
layout(binding = 1) uniform sampler2D source1;
layout(binding = 2) uniform sampler2D source2;
void main() {
    vec2 p = qt_TexCoord0; p.x *= aspect;
    vec2 center = vec2(0.0, 0.0); // Top-Left corner
    vec2 diff = abs(p - center);
    float dist = diff.x + diff.y;
    float maxDist = aspect + 1.0;
    float edge = 0.08;
    float currentRadius = progress * (maxDist + edge);
    float blend = smoothstep(currentRadius - edge, currentRadius, dist);
    fragColor = mix(texture(source2, qt_TexCoord0), texture(source1, qt_TexCoord0), blend) * qt_Opacity;
}
