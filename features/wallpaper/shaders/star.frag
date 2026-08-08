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

float sdStar5(in vec2 p, in float r, in float rf) {
    const vec2 k1 = vec2(0.809016994375, -0.587785252292);
    const vec2 k2 = vec2(-k1.x, k1.y);
    p.x = abs(p.x);
    p -= 2.0*max(dot(k1,p),0.0)*k1;
    p -= 2.0*max(dot(k2,p),0.0)*k2;
    p.x = abs(p.x);
    p.y -= r;
    vec2 ba = rf*vec2(-k1.y,k1.x) - vec2(0,1);
    float h = clamp( dot(p,ba)/dot(ba,ba), 0.0, r );
    return length(p-ba*h) * sign(p.y*ba.x-p.x*ba.y);
}

void main() {
    vec2 p = qt_TexCoord0 - 0.5;
    p.x *= aspect;
    
    float angle = progress * 3.14159 * 1.5;
    float s = sin(angle);
    float c = cos(angle);
    p = vec2(p.x * c - p.y * s, p.x * s + p.y * c);
    
    float maxDist = length(vec2(0.5 * aspect, 0.5)) * 2.5;
    float edge = 0.04;
    float radius = progress * (maxDist + 2.0 * edge) - edge;
    
    float dist = sdStar5(p, max(radius, 0.001), 0.4); 
    if (radius < 0.0) dist = edge * 2.0;
    
    float blend = smoothstep(-edge, edge, dist); 
    
    vec4 t1 = texture(source1, qt_TexCoord0);
    vec4 t2 = texture(source2, qt_TexCoord0);
    
    float envelope = 4.0 * progress * (1.0 - progress);
    float glow = (1.0 - smoothstep(0.0, edge * 2.0, abs(dist))) * envelope;
    
    vec4 color = mix(t2, t1, blend);
    color.rgb += vec3(1.0, 0.8, 0.2) * glow;
    
    fragColor = color * qt_Opacity;
}
