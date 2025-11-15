// Defines cEyePos
#include "common_ps_fxc.h"

#define EPSILON 1e-6

sampler BOTTOM : register(s0);
sampler TOP : register(s1);

float4 COLOR : register(c0);
float4 BLEND : register(c1);

struct PS_INPUT
{
    float2 uv : TEXCOORD0;             // Position on triangle
};

// Combines the top and bottom colors using normal blending.
// https://en.wikipedia.org/wiki/Blend_modes#Normal_blend_mode
// This performs the same operation as Blend SrcAlpha OneMinusSrcAlpha.
float4 alphaBlend(float4 top, float4 bottom)
{
    float3 color = (top.rgb * top.a) + (bottom.rgb * (1 - top.a));
    float alpha = top.a + bottom.a * (1 - top.a);

    return float4(color, alpha);
}

float4 compare(float a, float b)
{
    float result = abs(a - b) < EPSILON;
    return float4(result, result, result, 1);
}

// local blendModes = {
// 	normal = 0,

// 	darken = 1,
// 	multiply = 2,

// 	lighten = 3,
// 	screen = 4,

// 	overlay = 5,
// 	softLight = 6,
// 	hardLight = 7,
// }

float4 blending(float4 top, float4 bottom, float mode) 
{
    // TODO: Rewrite this at some point
    // It already looks hacky

    float4 normal = alphaBlend(top, bottom) * compare(mode, 0.0);
    float4 darken = min(top, bottom) * compare(mode, 1.0);
    float4 multiply = top * bottom * compare(mode, 2.0);
    float4 lighten = max(top, bottom) * compare(mode, 3.0);
    float4 screen = (1 - (1 - top) * (1 - bottom) )* compare(mode, 4.0);
    float4 overlay = top < 0.5 ? (2.0 * top * bottom) : (1.0 - 2.0 * (1.0 - top) * (1.0 - bottom));
    overlay *= compare(mode, 5.0);
    float4 hardLight = bottom < 0.5 ? (2.0 * top * bottom) : (1.0 - 2.0 * (1.0 - top) * (1.0 - bottom));
    hardLight *= compare(mode, 6.0);
    float4 softLight = bottom < 0.5 ? (2.0 * top * bottom + top * top * (1.0 - 2.0 * bottom)) : (sqrt(top) * (2.0 * bottom - 1.0) + (2.0 * top) * (1.0 - bottom));
    softLight *= compare(mode, 7.0);

    return normal + darken + multiply + lighten + screen + overlay + hardLight + softLight; 
}

float4 main(PS_INPUT frag) : COLOR
{
    float4 bottom = tex2D(BOTTOM, frag.uv);
    float4 top = tex2D(TOP, frag.uv);
    top.rgb = COLOR.rgb * top.rgb;
    top.a = COLOR.a;
    
    //return COLOR;
    // return top;
    return blending(top, bottom, BLEND.x);
}