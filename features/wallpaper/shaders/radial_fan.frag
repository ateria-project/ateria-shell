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

const float PI = 3.14159265359;

void main() {
    vec2 p = qt_TexCoord0 - vec2(0.5, 0.5);
    p.x *= aspect;
    
    float angle = atan(p.x, p.y);
    float normAngle = (angle + PI) / (2.0 * PI);
    float blades = 8.0;
    
    float sector = fract(normAngle * blades);
    
    float edge = 0.05;
    float prog = progress * (1.0 + edge);
    float blend = smoothstep(prog - edge, prog, sector);
    
    vec4 t1 = texture(source1, qt_TexCoord0);
    vec4 t2 = texture(source2, qt_TexCoord0);
    
    fragColor = mix(t2, t1, blend) * qt_Opacity;
}
