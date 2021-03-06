﻿#ifndef SRP_INCLUDE
#define SRP_INCLUDE

#define UNITY_MATRIX_M unity_ObjectToWorld

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"

#include "ComputeUtils.hlsl"

static const float DITHER_THRESHOLDS_64[64] = {
    1, 33, 9, 41, 3, 35, 11, 43, 
    49, 17, 57, 25, 51, 19, 59, 27,
    13, 45, 5, 37, 15, 47, 7, 39,
    61, 29, 53, 21, 63, 31, 55, 23,
    4, 36, 12, 44, 2, 34, 10, 42,
    52, 20, 60, 28, 50, 18, 58, 26,
    16, 48, 8, 40, 14, 48, 6, 38,
    64, 32, 56, 24, 62, 30, 54, 22
};

static const float4 POINT_LIGHT_PCF_OFFSET_6[6] = {
    float4(1, 0, 0, 0.1666667), float4(-1, 0, 0, 0.1666667), float4(0, 1, 0, 0.1666667), float4(0, -1, 0, 0.1666667), float4(0, 0, 1, 0.1666667), float4(0, 0, -1, 0.1666667)
};

static const float4 POINT_LIGHT_PCF_OFFSET_20[20] = {
    float4(1, 1, 1, 1.861362E-11), float4(1, -1, 1, 1.861362E-11), float4(-1, -1, 1, 1.861362E-11), float4(-1, 1, 1, 1.861362E-11),
    float4(1, 1, -1, 1.861362E-11), float4(1, -1, -1, 1.861362E-11), float4(-1, -1, -1, 1.861362E-11), float4(-1, 1, -1, 1.861362E-11),
    float4(1, 1, 0, 0.08333334), float4(1, -1, 0, 0.08333334), float4(-1, -1, 0, 0.08333334), float4(-1, 1, 0, 0.08333334),
    float4(1, 0, 1, 0.08333334), float4(-1, 0, 1, 0.08333334), float4(1, 0, -1, 0.08333334), float4(-1, 0, -1, 0.08333334),
    float4(0, 1, 1, 0.08333334), float4(0, -1, 1, 0.08333334), float4(0, -1, -1, 0.08333334), float4(0, 1, -1, 0.08333334)
};

StructuredBuffer<PointLight> _PointLightBuffer;
StructuredBuffer<SpotLight> _SpotLightBuffer;

StructuredBuffer<float4x4> pointLight_InverseVPBuffer;
StructuredBuffer<float4x4> spotLight_InverseVPBuffer;

Texture3D<uint> _CulledPointLightTexture;
Texture3D<uint> _CulledSpotLightTexture;

TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);

TEXTURE2D(_OpaqueNormalTexture);
SAMPLER(sampler_OpaqueNormalTexture);

TEXTURE2D(_OpaqueDepthTexture);
SAMPLER(sampler_OpaqueDepthTexture);

TEXTURE2D_SHADOW(_SunlightShadowmap);
SAMPLER_CMP(sampler_SunlightShadowmap);

TEXTURE2D_ARRAY_SHADOW(_SunlightShadowmapArray);
SAMPLER_CMP(sampler_SunlightShadowmapArray);

TEXTURECUBE_SHADOW(_PointLightShadowmap);
SAMPLER(sampler_PointLightShadowmap);

TEXTURECUBE_ARRAY_SHADOW(_PointLightShadowmapArray);
SAMPLER(sampler_PointLightShadowmapArray);

TEXTURE2D_ARRAY_SHADOW(_SpotLightShadowmapArray);
SAMPLER_CMP(sampler_SpotLightShadowmapArray);

CBUFFER_START(UnityPerFrame)
    float4 _OpaqueDepthTexture_ST;
    float4 _OpaqueNormalTexture_ST;
    float _AlphaTestDepthCutoff;
CBUFFER_END

CBUFFER_START(UnityPerDraw)
    float4x4 unity_ObjectToWorld;
    float4x4 unity_WorldToObject;
    float4 unity_LODFade;
    real4 unity_WorldTransformParams;
CBUFFER_END

CBUFFER_START(UnityPerMaterial)
    float4 _MainTex_ST;
    float4 _MainTex_TexelSize;
CBUFFER_END

CBUFFER_START(Shadow)
    float _ShadowBias;
    float _ShadowNormalBias;
    float _PointLightShadowmap_ST;
    float _SpotLightShadowmap_ST;
    float4 _PointLightShadowmapSize;
    float4 _SpotLightShadowmapSize;
    float4 _LightPos;
CBUFFER_END

CBUFFER_START(Sunlight)
    float4x4 sunlight_InverseVP;
    float4x4 sunlight_InverseVPArray[4];
    float4 _SunlightShadowSplitBoundArray[4];
    float4 _SunlightShadowmap_ST;
    float4 _SunlightShadowmapSize;
    float3 _SunlightColor;
    float3 _SunlightDirection;
    float _SunlightShadowDistance;
    float _SunlightShadowStrength;
CBUFFER_END

//////////////////////////////////////////
// Built-in Vertex Input/Output Structs //
//////////////////////////////////////////

struct BasicVertexInput {
    float4 pos : POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct SimpleVertexInput {
    float4 pos : POSITION;
    float3 normal : NORMAL;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct ImageVertexInput {
    float4 pos : POSITION;
    float2 uv : TEXCOORD0;
};

struct BasicVertexOutput {
    float4 clipPos : SV_POSITION;
};

struct SimpleVertexOutput {
    float4 clipPos : SV_POSITION;
    float3 normal : TEXCOORD0;
};

struct ImageVertexOutput {
    float4 clipPos : SV_POSITION;
    float2 uv : TEXCOORD0;
};

struct ShadowVertexOutput {
    float4 clipPos : SV_POSITION;
    float3 worldPos : TEXCOORD0;
};

///////////////////////////////
// Built-in Helper Functions //
///////////////////////////////

inline float4 GetWorldPosition(float3 pos) {
    return mul(UNITY_MATRIX_M, float4(pos, 1.0));
}

inline float4 GetClipPosition(float4 worldPos) {
    return mul(unity_MatrixVP, worldPos);
}

inline float3 GetWorldNormal(float3 normal) {
    return mul((float3x3) UNITY_MATRIX_M, normal);
}

inline float4 ComputeScreenPosition(float4 clipPos) {
    float4 output = clipPos * .5;
    output.xy = float2(output.x, output.y * _ProjectionParams.x) + output.w;
    output.zw = clipPos.zw;
    return output;
}

inline float3 WorldSpaceViewDirection(float4 localPos) {
    return _WorldSpaceCameraPos.xyz - mul(UNITY_MATRIX_M, localPos).xyz;
}

inline float3 WorldSpaceViewDirection(float3 worldPos) {
    return _WorldSpaceCameraPos.xyz - worldPos;
}

inline float IsDithered64(uint2 screenIndex, float alpha) {
    uint index = (screenIndex.x % 8) * 8 + screenIndex.y % 8;
    return alpha - DITHER_THRESHOLDS_64[index] / 65.0;
}

inline void DitherClip64(uint2 screenIndex, float alpha) {
    clip(IsDithered64(screenIndex, alpha));
}

inline float2 TransformTriangleVertexToUV(float4 vertex) {
    float2 uv = (vertex.xy + 1.0) * .5;
    return uv;
}

////////////////////////
// Lighting Functions //
////////////////////////
 
inline float SlopeScaleShadowBias(float3 worldNormal, float biasStrength, float maxBias) {
    // return clamp(biasStrength * dot(mul(unity_MatrixVP, float4(worldNormal, 1)), mul(unity_MatrixVP, float4(_SunlightDirection, 1))), 0, maxBias);
    return clamp(biasStrength * TanBetween(worldNormal, _SunlightDirection), 0, maxBias);
}

inline float LegacySlopeScaleShadowBias(float3 worldNormal, float constantBias, float maxBias) {
    return constantBias + clamp(TanBetween(worldNormal, _SunlightDirection), 0, maxBias);
}

inline float4 ShadowNormalBias(float4 worldPos, float3 worldNormal) {
    float shadowCos = CosBetween(worldNormal, _SunlightDirection);
    float shadowSin = SinOf(shadowCos);
    float normalBias = _ShadowNormalBias * shadowSin;
    worldPos -= float4(worldNormal * normalBias, 0);
    return worldPos;
}

inline float4 ClipSpaceShadowBias(float4 clipPos) {
#if UNITY_REVERSED_Z
	clipPos.z -= saturate(_ShadowBias / clipPos.w);
	clipPos.z = min(clipPos.z, clipPos.w * UNITY_NEAR_CLIP_VALUE);
#else
    clipPos.z += saturate(_ShadowBias / clipPos.w);
	clipPos.z = max(clipPos.z, clipPos.w * UNITY_NEAR_CLIP_VALUE)
#endif
    return clipPos;
}

inline float CascadedDirectionalHardShadow(float3 shadowPos, float cascadeIndex) {
    return SAMPLE_TEXTURE2D_ARRAY_SHADOW(_SunlightShadowmapArray, sampler_SunlightShadowmapArray, shadowPos, cascadeIndex);
}

float CascadedDirectionalSoftShadow(float3 shadowPos, float cascadeIndex) {
    real tentWeights[9];
    real2 tentUVs[9];
    SampleShadow_ComputeSamples_Tent_5x5(_SunlightShadowmapSize, shadowPos.xy, tentWeights, tentUVs);
    float attenuation = 0;
    [unroll]
    for (uint i = 0; i < 9; i++) attenuation += tentWeights[i] * CascadedDirectionalHardShadow(float3(tentUVs[i].xy, shadowPos.z), cascadeIndex);
    return attenuation;
}

inline float DefaultDirectionalShadow(float3 worldPos) {
    float4 shadowPos = mul(sunlight_InverseVP, float4(worldPos, 1));
    shadowPos.xyz /= shadowPos.w;
    return lerp(1, SAMPLE_TEXTURE2D_SHADOW(_SunlightShadowmap, sampler_SunlightShadowmap, shadowPos.xyz), _SunlightShadowStrength);
}

float DefaultCascadedDirectionalShadow(float3 worldPos) {
#if !defined(_SUNLIGHT_SHADOWS)
    return 1;
#else
    float3 diff = worldPos - _WorldSpaceCameraPos.xyz; 
    if (dot(diff, diff) > _SunlightShadowDistance * _SunlightShadowDistance) return 1;
    float4 cascadeFlags = float4(VertexInsideSphere(worldPos, _SunlightShadowSplitBoundArray[0]), VertexInsideSphere(worldPos, _SunlightShadowSplitBoundArray[1]), VertexInsideSphere(worldPos, _SunlightShadowSplitBoundArray[2]), VertexInsideSphere(worldPos, _SunlightShadowSplitBoundArray[3]));
    cascadeFlags.yzw = saturate(cascadeFlags.yzw - cascadeFlags.xyz);
    float cascadeIndex = 4 - dot(cascadeFlags, float4(4, 3, 2, 1));
    float4 shadowPos = mul(sunlight_InverseVPArray[cascadeIndex], float4(worldPos, 1));
    shadowPos.xyz /= shadowPos.w;
#if !defined(_SUNLIGHT_SOFT_SHADOWS)
    float shadowAttenuation = CascadedDirectionalHardShadow(shadowPos, cascadeIndex);
#else
    float shadowAttenuation = CascadedDirectionalSoftShadow(shadowPos, cascadeIndex);
#endif
    return lerp(1, shadowAttenuation, _SunlightShadowStrength);
#endif
}

inline float PointHardShadow(float4 shadowPos, float index) {
    float shadow = _PointLightShadowmapArray.Sample(sampler_PointLightShadowmapArray, float4(shadowPos.xyz, index));
    float depth = shadowPos.w;
    return depth < shadow;
}

float PointSoftShadow(float4 shadowPos, float index, float viewDist) {
    //todo gonna replace this naive PCF method (terrible shadow bands & performance)
    float diskRadius = (1.0 - viewDist * _ZBufferParams.w) * 0.002;
    float attenuation = 0;
    [unroll]
    for (uint i = 0; i < 20; i++) attenuation += PointHardShadow(float4(shadowPos.xyz + POINT_LIGHT_PCF_OFFSET_20[i].xyz * diskRadius, shadowPos.w), index);
    attenuation /= 20.0;
    /* low sample count but much more terrible shadow bands
    [unroll]
    for (uint i = 0; i < 6; i++) attenuation += PointHardShadow(float4(shadowPos.xyz + POINT_LIGHT_PCF_OFFSET_6[i].xyz * diskRadius, shadowPos.w), index) * POINT_LIGHT_PCF_OFFSET_6[i].w; 
    */
    return attenuation;
}

float DefaultPointShadow(float viewDist, float3 lightDir, float depth, uint3 lightIndex) {
#if !defined(_POINT_LIGHT_SHADOWS)
    return 1;
#else
    PointLight light = _PointLightBuffer[_CulledPointLightTexture[lightIndex]];
    uint shadowIndex = light.shadowIndex;
    if (shadowIndex == 0) return 1;
    shadowIndex--;
    float4 shadowPos = float4(lightDir, depth);
#if !defined(_POINT_LIGHT_SOFT_SHADOWS)
    float shadowAttenuation = PointHardShadow(shadowPos, shadowIndex);
#else
    float shadowAttenuation = PointSoftShadow(shadowPos, shadowIndex, viewDist);
#endif
    return lerp(1, shadowAttenuation, light.shadowStrength);
#endif
}

inline float SpotHardShadow(float3 shadowPos, uint index) {
    return SAMPLE_TEXTURE2D_ARRAY_SHADOW(_SpotLightShadowmapArray, sampler_SpotLightShadowmapArray, shadowPos, index);
}

float SpotSoftShadow(float3 shadowPos, uint index) {
    real tentWeights[9];
    real2 tentUVs[9];
    SampleShadow_ComputeSamples_Tent_5x5(_SpotLightShadowmapSize, shadowPos.xy, tentWeights, tentUVs);
    float attenuation = 0;
    [unroll]
    for (uint i = 0; i < 9; i++) attenuation += tentWeights[i] * SpotHardShadow(float3(tentUVs[i].xy, shadowPos.z), index);
    return attenuation;
}

float DefaultSpotShadow(float3 worldPos, uint3 lightIndex) {
#if !defined(_SPOT_LIGHT_SHADOWS)
    return 1;
#else
    SpotLight light = _SpotLightBuffer[_CulledSpotLightTexture[lightIndex]];
    uint shadowIndex = light.shadowIndex;
    if (shadowIndex == 0) return 1;
    shadowIndex--;
    float4 shadowPos = mul(spotLight_InverseVPBuffer[shadowIndex], float4(worldPos, 1));
    shadowPos.xyz /= shadowPos.w;
#if !defined(_SPOT_LIGHT_SOFT_SHADOWS)
    float shadowAttenuation = SpotHardShadow(shadowPos, shadowIndex);
#else
    float shadowAttenuation = SpotSoftShadow(shadowPos, shadowIndex);
#endif
    return lerp(1, shadowAttenuation, light.shadowStrength);
#endif
}

inline float3 DefaultDirectionalLit(float3 worldPos, float3 worldNormal) {
    float diffuse = saturate(dot(worldNormal, _SunlightDirection));
    float shadow = DefaultCascadedDirectionalShadow(worldPos);
    return diffuse * _SunlightColor * shadow;
}

inline float3 DefaultPointLit(float3 worldPos, float3 worldNormal, uint3 lightIndex) {
    PointLight light = _PointLightBuffer[_CulledPointLightTexture[lightIndex]];
    float3 lightDir = light.sphere.xyz - worldPos;
    float lightDist = length(lightDir);
    lightDir /= lightDist;
    float distanceSqr = lightDist * lightDist;
    float rangeFade = distanceSqr * 1.0 / max(light.sphere.w * light.sphere.w, .00001);
    rangeFade = saturate(1.0 - rangeFade * rangeFade);
    rangeFade *= rangeFade;
    float diffuse = saturate(dot(worldNormal, lightDir));
    diffuse *= rangeFade / distanceSqr;
    float radius = light.sphere.w;
    float shadow = DefaultPointShadow(distance(worldPos, _WorldSpaceCameraPos), -lightDir, lightDist / radius, lightIndex);
    return diffuse * light.color * shadow;
}

inline float3 DefaultSpotLit(float3 worldPos, float3 worldNormal, uint3 lightIndex) {
    SpotLight light = _SpotLightBuffer[_CulledSpotLightTexture[lightIndex]];
    float3 lightDir = light.cone.vertex - worldPos;
    float lightDist = length(lightDir);
    lightDir /= lightDist;
    float distanceSqr = lightDist * lightDist;
    float rangeFade = distanceSqr * 1.0 / max(light.cone.height * light.cone.height, .00001);
    rangeFade = saturate(1.0 - rangeFade * rangeFade);
    rangeFade *= rangeFade;
    float cosAngle = cos(light.cone.angle);
    float angleRangeInv = 1.0 / max(cos(light.smallAngle) - cosAngle, .00001);
    float spotFade = dot(light.cone.direction, lightDir);
    spotFade = saturate((spotFade - cosAngle) * angleRangeInv);
    float diffuse = saturate(dot(worldNormal, lightDir));
    diffuse *= rangeFade * spotFade / distanceSqr;
    float shadow = DefaultSpotShadow(worldPos, lightIndex);
    return diffuse * light.color * shadow;
}

//////////////////////////////////////
// Built-in Vertex/Fragment Shaders //
//////////////////////////////////////

BasicVertexOutput UnlitVertex(BasicVertexInput input) {
    UNITY_SETUP_INSTANCE_ID(input);
    BasicVertexOutput output;
	output.clipPos = GetClipPosition(GetWorldPosition(input.pos.xyz));
	return output;
}

ImageVertexOutput ImageVertex(ImageVertexInput input) {
    ImageVertexOutput output;
    output.clipPos = GetClipPosition(GetWorldPosition(input.pos.xyz));
    // output.uv = TRANSFORM_TEX(input.uv, _MainTex);
    output.uv = input.uv;
    return output;
}

float4 UnlitFragment(BasicVertexOutput input) : SV_TARGET {
    return 1;
}

float4 NoneFragment(BasicVertexOutput input) : SV_TARGET {
    return 0;
}

ShadowVertexOutput ShadowCasterVertex(SimpleVertexInput input) {
    UNITY_SETUP_INSTANCE_ID(input);
    ShadowVertexOutput output;
    float3 worldNormal = GetWorldNormal(input.normal);
    float4 worldPos = GetWorldPosition(input.pos.xyz);
    output.worldPos = worldPos;
    output.clipPos = ClipSpaceShadowBias(GetClipPosition(ShadowNormalBias(worldPos, worldNormal)));
    return output;
}

float4 ShadowCasterFragment(ShadowVertexOutput input) : SV_TARGET {
    return distance(input.worldPos.xyz, _LightPos.xyz) / _LightPos.w;
}

#endif // SRP_INCLUDE