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
    // Distance from center vertically
    float distFromCenter = abs(qt_TexCoord0.y - 0.5);
    float wave = sin(qt_TexCoord0.x * 18.8495) * 0.03;
    
    float d = distFromCenter + wave;
    
    float edge = 0.06;
    float maxDist = 0.5;
    float p = progress * (maxDist + edge * 2.0);
    float blend = smoothstep(p - edge, p, d);
    
    vec4 t1 = texture(source1, qt_TexCoord0);
    vec4 t2 = texture(source2, qt_TexCoord0);
    
    fragColor = mix(t2, t1, blend) * qt_Opacity;
}
