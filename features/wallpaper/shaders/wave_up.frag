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
    // Wave moving bottom-to-top
    float wave = sin(qt_TexCoord0.x * 12.5664) * 0.04;
    float d = (1.0 - qt_TexCoord0.y) + wave;
    
    float edge = 0.06;
    float minD = -0.04;
    float maxD = 1.04;
    
    float p = minD + progress * (maxD - minD + 2.0 * edge);
    float blend = smoothstep(p - edge, p, d);
    
    vec4 t1 = texture(source1, qt_TexCoord0);
    vec4 t2 = texture(source2, qt_TexCoord0);
    
    fragColor = mix(t2, t1, blend) * qt_Opacity;
}
