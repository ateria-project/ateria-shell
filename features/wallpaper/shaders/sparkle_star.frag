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
    vec2 p = qt_TexCoord0 - vec2(0.5, 0.5);
    p.x *= aspect;
    
    // A crisp four-point sparkle using only absolute/min/max arithmetic. This
    // avoids three per-pixel pow() calls from the previous superellipse.
    vec2 ap = abs(p);
    float d = max(ap.x, ap.y) + min(ap.x, ap.y) * 2.4;
    
    vec2 corner = vec2(0.5 * aspect, 0.5);
    float maxDist = max(corner.x, corner.y) + min(corner.x, corner.y) * 2.4;
    float edge = 0.05;
    float currentRadius = progress * (maxDist + 2.0 * edge) - edge;
    
    float blend = smoothstep(currentRadius - edge, currentRadius + edge, d);
    
    vec4 t1 = texture(source1, qt_TexCoord0);
    vec4 t2 = texture(source2, qt_TexCoord0);
    
    float envelope = 4.0 * progress * (1.0 - progress);
    float glow = (1.0 - smoothstep(0.0, edge * 3.0, abs(d - max(currentRadius, 0.0)))) * envelope;
    
    vec4 color = mix(t2, t1, blend);
    color.rgb += vec3(0.4, 0.8, 1.0) * glow;
    
    fragColor = color * qt_Opacity;
}
