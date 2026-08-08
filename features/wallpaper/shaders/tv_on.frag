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
    vec2 uv = qt_TexCoord0;
    
    // Phase 1 (0% to 30%): Horizontal beam grows left & right beyond screen edges
    float pX = clamp(progress * 3.333, 0.0, 1.0);
    float distX = abs(uv.x - 0.5);
    float limitX = pX * 0.55;
    
    // Phase 2 (20% to 100%): Vertical beam expands top & bottom beyond screen edges
    float pY = clamp((progress - 0.2) * 1.25, 0.0, 1.0);
    float distY = abs(uv.y - 0.5);
    float limitY = pY * 0.55;
    
    float edge = 0.02;
    float maskX = smoothstep(limitX - edge, limitX, distX);
    float maskY = smoothstep(limitY - edge, limitY, distY);
    
    float blend = max(maskX, maskY);
    
    vec4 t1 = texture(source1, uv);
    vec4 t2 = texture(source2, uv);
    
    vec4 color = mix(t2, t1, blend);
    float envelope = 4.0 * progress * (1.0 - progress);
    float beamDistance = min(abs(distX - limitX), abs(distY - limitY));
    float beamGlow = (1.0 - smoothstep(0.0, edge * 0.65, beamDistance)) * envelope;
    color.rgb += vec3(0.16, 0.20, 0.24) * beamGlow;

    fragColor = color * qt_Opacity;
}
