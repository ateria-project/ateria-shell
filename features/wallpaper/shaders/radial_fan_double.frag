#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf { mat4 qt_Matrix; float qt_Opacity; float aspect; float progress; };
layout(binding = 1) uniform sampler2D source1;
layout(binding = 2) uniform sampler2D source2;
const float PI = 3.14159265359;
void main() {
    vec2 p = qt_TexCoord0 - vec2(0.5);
    p.x *= aspect;
    float angle = atan(p.y, p.x);
    float normAngle = (angle + PI) / (2.0 * PI);
    float fan = fract(normAngle * 2.0);
    
    float edge = 0.04;
    float threshold = progress * (1.0 + edge);
    float blend = smoothstep(threshold - edge, threshold, fan);
    
    fragColor = mix(texture(source2, qt_TexCoord0), texture(source1, qt_TexCoord0), blend) * qt_Opacity;
}
