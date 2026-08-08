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
    float rows = 11.25;
    vec2 size = vec2(floor(rows * aspect + 0.5), rows);
    vec2 grid = floor(qt_TexCoord0 * size);
    
    // Checkerboard parity
    float parity = mod(grid.x + grid.y, 2.0);
    float r = hash(grid);
    
    float val = parity * 0.4 + r * 0.6;
    
    float edge = 0.12;
    float p = progress * (1.0 + 2.0 * edge) - edge;
    float blend = smoothstep(p - edge, p, val);
    
    vec4 t1 = texture(source1, qt_TexCoord0);
    vec4 t2 = texture(source2, qt_TexCoord0);
    
    fragColor = mix(t2, t1, blend) * qt_Opacity;
}
