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
    vec2 center = vec2(0.0, 1.0); // Bottom-Left corner
    float dist = distance(p, center);
    
    float maxDist = length(vec2(aspect, 1.0));
    float edge = 0.08;
    
    float currentRadius = progress * (maxDist + edge);
    float blend = smoothstep(currentRadius - edge, currentRadius, dist);
    
    vec4 t1 = texture(source1, qt_TexCoord0);
    vec4 t2 = texture(source2, qt_TexCoord0);
    
    fragColor = mix(t2, t1, blend) * qt_Opacity;
}
