#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float aspect;
    float progress;
};
layout(binding = 1) uniform sampler2D source1;
layout(binding = 2) uniform sampler2D source2;

void main() {
    vec2 p = qt_TexCoord0;
    p.x *= aspect;
    vec2 center = vec2(0.5 * aspect, 0.5);
    vec2 diff = p - center;
    
    // Counter-clockwise
    float angle = atan(-diff.x, -diff.y);
    float normAngle = (angle + 3.14159265) / (2.0 * 3.14159265);
    
    float edge = 0.04;
    float pMapped = progress * (1.0 + edge);
    float blend = smoothstep(pMapped - edge, pMapped, normAngle);
    
    vec4 t1 = texture(source1, qt_TexCoord0);
    vec4 t2 = texture(source2, qt_TexCoord0);
    
    fragColor = mix(t2, t1, blend) * qt_Opacity;
}
