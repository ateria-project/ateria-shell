#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf { mat4 qt_Matrix; float qt_Opacity; float aspect; float progress; };
layout(binding = 1) uniform sampler2D source1;
layout(binding = 2) uniform sampler2D source2;
const float PI = 3.14159265359;
float hexDist(vec2 p) {
    p = abs(p);
    return max(p.y, p.x * 0.866025 + p.y * 0.5);
}
void main() {
    vec2 p = qt_TexCoord0 - vec2(0.5);
    p.x *= aspect;
    
    float scale = 15.0;
    vec2 hp = p * scale;
    
    vec2 grid1 = vec2(hp.x, hp.y / 0.866025);
    vec2 grid2 = vec2(hp.x + 0.5, hp.y / 0.866025 + 0.5);
    vec2 f1 = fract(grid1) - 0.5;
    vec2 f2 = fract(grid2) - 0.5;
    
    vec2 hexCenter = dot(f1, f1) < dot(f2, f2) ? floor(grid1) : (floor(grid2) - vec2(0.5));
    float d = hexDist(hp - hexCenter * vec2(1.0, 0.866025));
    
    float angle = atan(hexCenter.y * 0.866025, hexCenter.x);
    float normAngle = (angle / (2.0 * PI)) + 0.5;
    float r = length(hexCenter * vec2(1.0, 0.866025)) / scale;
    
    float spiral = r * 0.5 + normAngle * 0.2 + d * 0.05;
    float edge = 0.08;
    // Derive the furthest possible value from the surface aspect ratio. The
    // previous 16:9 constant could leave islands of source1 on ultrawide screens.
    float maxVal = length(vec2(0.5 * aspect, 0.5)) * 0.5 + 0.275;
    float threshold = progress * (maxVal + edge);
    float blend = smoothstep(threshold - edge, threshold, spiral);
    
    fragColor = mix(texture(source2, qt_TexCoord0), texture(source1, qt_TexCoord0), blend) * qt_Opacity;
}
