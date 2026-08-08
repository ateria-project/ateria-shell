#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf { mat4 qt_Matrix; float qt_Opacity; float aspect; float progress; };
layout(binding = 1) uniform sampler2D source1;
layout(binding = 2) uniform sampler2D source2;

void main() {
    vec2 uv = qt_TexCoord0;
    
    // Top-Right corner curl (1,0 to 0,1)
    float d = (uv.x + (1.0 - uv.y)) * 0.5;
    
    float edge = 0.08;
    float p = (1.0 - progress) * (1.0 + 2.0 * edge) - edge;
    
    float blend = smoothstep(p - edge, p + edge, d);
    
    vec4 t1 = texture(source1, uv);
    vec4 t2 = texture(source2, uv);
    
    float envelope = 4.0 * progress * (1.0 - progress);
    float fold = smoothstep(p - edge * 2.0, p, d) * (1.0 - smoothstep(p, p + edge, d));
    float highlight = (1.0 - smoothstep(0.0, edge * 0.35, abs(d - p))) * envelope;
    
    vec4 color = mix(t1, t2, blend);
    color.rgb *= 1.0 - fold * envelope * 0.35;
    color.rgb += vec3(0.12) * highlight;
    
    fragColor = color * qt_Opacity;
}
