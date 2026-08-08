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

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main() {
    vec2 p = qt_TexCoord0;
    p.x *= aspect;
    
    float scale = 15.0;
    vec2 sp = p * scale;
    
    vec2 r = vec2(1.0, 1.732);
    vec2 h = r * 0.5;
    vec2 a = mod(sp, r) - h;
    vec2 b = mod(sp - h, r) - h;
    
    vec2 gv = dot(a, a) < dot(b, b) ? a : b;
    vec2 id = sp - gv; 
    
    float val = hash(id);
    
    vec2 center = vec2(0.5 * aspect * scale, 0.5 * scale);
    float maxLen = length(center);
    float dist = length(id - center) / maxLen;
    
    float cascade = dist * 0.5 + val * 0.5;
    
    float edge = 0.15;
    float prog = progress * (1.0 + edge * 2.0);
    float blend = smoothstep(prog - edge, prog, cascade);
    
    vec4 t1 = texture(source1, qt_TexCoord0);
    vec4 t2 = texture(source2, qt_TexCoord0);
    
    fragColor = mix(t2, t1, blend) * qt_Opacity;
}
