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
    float y = qt_TexCoord0.y;
    
    float edge = 0.02;
    float linePos = progress * (1.0 + edge * 2.0) - edge;
    
    float blend = smoothstep(linePos - edge, linePos, y);
    
    vec4 t1 = texture(source1, qt_TexCoord0);
    vec4 t2 = texture(source2, qt_TexCoord0);
    
    // Laser line highlight
    float envelope = 4.0 * progress * (1.0 - progress);
    float laserGlow = (1.0 - smoothstep(0.0, 0.015, abs(y - linePos))) * envelope;
    
    vec4 color = mix(t2, t1, blend);
    color.rgb += vec3(0.2, 0.9, 1.0) * laserGlow * 2.0; // Cyan laser beam
    
    fragColor = color * qt_Opacity;
}
