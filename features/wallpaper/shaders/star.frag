#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float aspect;
    float progress;
    float variant;
    vec4 crop1;
    vec4 crop2;
};
layout(binding = 1) uniform sampler2D source1;
layout(binding = 2) uniform sampler2D source2;

vec4 sample1(vec2 uv) { return texture(source1, uv * crop1.xy + crop1.zw); }
vec4 sample2(vec2 uv) { return texture(source2, uv * crop2.xy + crop2.zw); }

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
    vec2 uv = qt_TexCoord0;
    vec2 origin;
    if (variant < 0.5)
        origin = vec2(0.18, 0.22);
    else if (variant < 1.5)
        origin = vec2(0.82, 0.78);
    else if (variant < 2.5)
        origin = vec2(0.80, 0.18);
    else if (variant < 3.5)
        origin = vec2(0.20, 0.80);
    else if (variant < 4.5)
        origin = vec2(0.10, 0.50);
    else
        origin = vec2(0.90, 0.50);
    vec2 scale = vec2(aspect, 1.0);
    vec2 p = (uv - origin) * scale;

    // A restrained turn gives the star a sense of motion without becoming a
    // spinning novelty wipe.
    float startAngle = -0.30 + variant * 0.14;
    float endAngle = startAngle + (mod(variant, 2.0) < 0.5 ? -0.22 : 0.22);
    float angle = mix(startAngle, endAngle, progress);
    float s = sin(angle);
    float c = cos(angle);
    p = vec2(p.x * c - p.y * s, p.x * s + p.y * c);

    float edge = 0.026;
    // The star's inner valleys need more radius than a circle to reach the
    // corners; otherwise a stale corner flashes just before completion.
    vec2 farthestCorner = max(origin, vec2(1.0) - origin) * scale;
    float maxDistance = length(farthestCorner);
    float maxRadius = maxDistance * 2.6;
    float radius = mix(0.0, maxRadius + edge * 2.0, progress);
    float distanceToStar = sdStar5(p, max(radius, 0.001), 0.43);
    float reveal = 1.0 - smoothstep(-edge, edge, distanceToStar);

    float edgeBand = 1.0 - smoothstep(0.0, edge * 2.6, abs(distanceToStar));
    vec4 color;
    if (reveal <= 0.0)
        color = sample1(uv);
    else if (reveal >= 1.0)
        color = sample2(uv);
    else
        color = mix(sample1(uv), sample2(uv), reveal);
    color.rgb += (vec3(1.0) - color.rgb) * edgeBand * 0.10;
    fragColor = vec4(color.rgb * qt_Opacity, 1.0);
}
