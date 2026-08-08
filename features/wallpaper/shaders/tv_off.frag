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
    vec2 center = vec2(0.5, 0.5);
    
    // Uniform, branch-free two-stage collapse: height first, then width.
    float phaseY = clamp(progress * 2.0, 0.0, 1.0);
    float phaseX = clamp((progress - 0.5) * 2.0, 0.0, 1.0);
    float yScale = max(1.0 - phaseY * phaseY, 0.001);
    float xScale = max(1.0 - phaseX * phaseX, 0.001);
    
    vec2 uv = center + (p - center) / vec2(xScale, yScale);
    
    vec4 color;
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        color = texture(source2, p);
    } else {
        color = texture(source1, uv);
    }
    
    float flash1 = smoothstep(0.40, 0.50, progress) * (1.0 - smoothstep(0.50, 0.60, progress));
    float lineGlow = 1.0 - smoothstep(0.002, 0.009, abs(p.y - 0.5));
    color.rgb += vec3(0.8) * flash1 * lineGlow;
    
    float flash2 = smoothstep(0.90, 0.96, progress) * (1.0 - smoothstep(0.96, 1.0, progress));
    vec2 dotOffset = p - vec2(0.5);
    dotOffset.x *= aspect;
    float dotGlow = 1.0 - smoothstep(0.004, 0.026, length(dotOffset));
    color.rgb += vec3(1.0) * flash2 * dotGlow;

    // The minimum scale keeps division finite; ensure it cannot leave the
    // center pixel visible on the final transition frame.
    if (progress >= 0.999) {
        color = texture(source2, p);
    }
    
    fragColor = color * qt_Opacity;
}
