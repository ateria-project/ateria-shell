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
    // Bottom-Right to Top-Left
    float d = ((1.0 - qt_TexCoord0.x) + (1.0 - qt_TexCoord0.y)) * 0.5;
    
    float edge = 0.08;
    float p = progress * (1.0 + 2.0 * edge) - edge;
    float blend = smoothstep(p - edge, p + edge, d);
    
    vec4 t1 = texture(source1, qt_TexCoord0);
    vec4 t2 = texture(source2, qt_TexCoord0);
    
    fragColor = mix(t2, t1, blend) * qt_Opacity;
}
