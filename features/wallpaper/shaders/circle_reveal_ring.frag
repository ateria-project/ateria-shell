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
    float dist = distance(p, center);
    
    float maxDist = length(vec2(0.5 * aspect, 0.5));
    float ringWidth = 0.12;
    
    float currentRadius = progress * (maxDist + ringWidth);
    float blend = smoothstep(currentRadius - ringWidth, currentRadius, dist);
    
    vec4 t1 = texture(source1, qt_TexCoord0);
    vec4 t2 = texture(source2, qt_TexCoord0);
    
    float envelope = 4.0 * progress * (1.0 - progress);
    float borderHighlight = (smoothstep(currentRadius - ringWidth, currentRadius - ringWidth * 0.5, dist) -
                            smoothstep(currentRadius - ringWidth * 0.5, currentRadius, dist)) * envelope;
                            
    vec4 color = mix(t2, t1, blend);
    color.rgb += vec3(0.15, 0.15, 0.2) * borderHighlight;
    
    fragColor = color * qt_Opacity;
}
