//*********************************************************
//
// Copyright (c) Microsoft. All rights reserved.
// This code is licensed under the MIT License (MIT).
// THIS CODE IS PROVIDED *AS IS* WITHOUT WARRANTY OF
// ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY
// IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR
// PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.
//
//*********************************************************

#ifndef RAYTRACINGSHADERHELPER_H
#define RAYTRACINGSHADERHELPER_H

#include "RayTracingHlslCompat.h"

#define INFINITY (1.0/0.0)

#define FLT_EPSILON     1.192092896e-07 // Smallest number such that 1.0 + FLT_EPSILON != 1.0
#define FLT_MIN         1.175494351e-38 
#define FLT_MAX         3.402823466e+38 

struct Ray
{
    float3 origin;
    float3 direction;
};

float length_toPow2(float2 p)
{
    return dot(p, p);
}

float length_toPow2(float3 p)
{
    return dot(p, p);
}

uint Float2ToHalf(in float2 val)
{
    uint result = 0;
    result = f32tof16(val.x);
    result |= f32tof16(val.y) << 16;
    return result;
}

float2 HalfToFloat2(in uint val)
{
    float2 result;
    result.x = f16tof32(val);
    result.y = f16tof32(val >> 16);
    return result;
}

uint2 EncodeMaterial16b(uint materialID, float3 diffuse)
{
    uint2 result;
    result.x = materialID;
    result.x |= f32tof16(diffuse.r) << 16;
    result.y = Float2ToHalf(diffuse.gb);

    return result;
}

void DecodeMaterial16b(in uint2 material, out uint materialID, out float3 diffuse)
{
    materialID = material.x & 0xffff;
    diffuse.r = f16tof32(material.x >> 16);
    diffuse.gb = HalfToFloat2(material.y);
}

// Remaps a value to [0,1] for a given range.
float RemapToRange(in float value, in float rangeMin, in float rangeMax)
{
	return saturate((value - rangeMin) / (rangeMax - rangeMin));
}

// Returns a cycling <0 -> 1 -> 0> animation interpolant 
float CalculateAnimationInterpolant(in float elapsedTime, in float cycleDuration)
{
    float curLinearCycleTime = fmod(elapsedTime, cycleDuration) / cycleDuration;
    curLinearCycleTime = (curLinearCycleTime <= 0.5f) ? 2 * curLinearCycleTime : 1 - 2 * (curLinearCycleTime - 0.5f);
    return smoothstep(0, 1, curLinearCycleTime);
}

void swap(inout float a, inout float b)
{
    float temp = a;
    a = b;
    b = temp;
}

bool IsInRange(in float val, in float min, in float max)
{
    return (val >= min && val <= max);
}

// Load three 16 bit indices from a byte addressed buffer.
static
uint3 Load3x16BitIndices(uint offsetBytes, ByteAddressBuffer Indices)
{
    uint3 indices;

    // ByteAdressBuffer loads must be aligned at a 4 byte boundary.
    // Since we need to read three 16 bit indices: { 0, 1, 2 } 
    // aligned at a 4 byte boundary as: { 0 1 } { 2 0 } { 1 2 } { 0 1 } ...
    // we will load 8 bytes (~ 4 indices { a b | c d }) to handle two possible index triplet layouts,
    // based on first index's offsetBytes being aligned at the 4 byte boundary or not:
    //  Aligned:     { 0 1 | 2 - }
    //  Not aligned: { - 0 | 1 2 }
    const uint dwordAlignedOffset = offsetBytes & ~3;
    const uint2 four16BitIndices = Indices.Load2(dwordAlignedOffset);

    // Aligned: { 0 1 | 2 - } => retrieve first three 16bit indices
    if (dwordAlignedOffset == offsetBytes)
    {
        indices.x = four16BitIndices.x & 0xffff;
        indices.y = (four16BitIndices.x >> 16) & 0xffff;
        indices.z = four16BitIndices.y & 0xffff;
    }
    else // Not aligned: { - 0 | 1 2 } => retrieve last three 16bit indices
    {
        indices.x = (four16BitIndices.x >> 16) & 0xffff;
        indices.y = four16BitIndices.y & 0xffff;
        indices.z = (four16BitIndices.y >> 16) & 0xffff;
    }

    return indices;
}

// Retrieve hit world position.
float3 HitWorldPosition()
{
    return WorldRayOrigin() + RayTCurrent() * WorldRayDirection();
}

// Retrieve attribute at a hit position interpolated from vertex attributes using the hit's barycentrics.
float3 HitAttribute(float3 vertexAttribute[3], BuiltInTriangleIntersectionAttributes attr)
{
    return vertexAttribute[0] +
        attr.barycentrics.x * (vertexAttribute[1] - vertexAttribute[0]) +
        attr.barycentrics.y * (vertexAttribute[2] - vertexAttribute[0]);
}

// Retrieve attribute at a hit position interpolated from vertex attributes using the hit's barycentrics.
float2 HitAttribute(float2 vertexAttribute[3], BuiltInTriangleIntersectionAttributes attr)
{
    return vertexAttribute[0] +
        attr.barycentrics.x * (vertexAttribute[1] - vertexAttribute[0]) +
        attr.barycentrics.y * (vertexAttribute[2] - vertexAttribute[0]);
}


// ToDo merge with GenerateCameraRay?
inline Ray GenerateForwardCameraRay(in float3 cameraPosition, in float4x4 projectionToWorldWithCameraEyeAtOrigin)
{
	float2 screenPos = float2(0, 0);
	
	// Unproject the pixel coordinate into a world positon.
	float4 world = mul(float4(screenPos, 0, 1), projectionToWorldWithCameraEyeAtOrigin);
	//world.xyz /= world.w;

	Ray ray;
	ray.origin = cameraPosition;
	// Since the camera's eye was at 0,0,0 in projectionToWorldWithCameraEyeAtOrigin 
	// the world.xyz is the direction.
	ray.direction = normalize(world.xyz);

	return ray;
}

// Generate a ray in world space for a camera pixel corresponding to an index from the dispatched 2D grid.
inline Ray GenerateCameraRay(uint2 index, in float3 cameraPosition, in float4x4 projectionToWorldWithCameraEyeAtOrigin, float2 jitter = float2(0, 0))
{
    float2 xy = index + 0.5f; // center in the middle of the pixel.
	xy += jitter;
    float2 screenPos = xy / DispatchRaysDimensions().xy * 2.0 - 1.0;

    // Invert Y for DirectX-style coordinates.
    screenPos.y = -screenPos.y;

    // Unproject the pixel coordinate into a world positon.
    float4 world = mul(float4(screenPos, 0, 1), projectionToWorldWithCameraEyeAtOrigin);
    //world.xyz /= world.w;

    Ray ray;
    ray.origin = cameraPosition;
	// Since the camera's eye was at 0,0,0 in projectionToWorldWithCameraEyeAtOrigin 
	// the world.xyz is the direction.
	ray.direction = normalize(world.xyz);

    return ray;
}

// Test if a hit is culled based on specified RayFlags.
bool IsCulled(in Ray ray, in float3 hitSurfaceNormal)
{
    float rayDirectionNormalDot = dot(ray.direction, hitSurfaceNormal);

    bool isCulled = 
        ((RayFlags() & RAY_FLAG_CULL_BACK_FACING_TRIANGLES) && (rayDirectionNormalDot > 0))
        ||
        ((RayFlags() & RAY_FLAG_CULL_FRONT_FACING_TRIANGLES) && (rayDirectionNormalDot < 0));

    return isCulled; 
}

// Test if a hit is valid based on specified RayFlags and <RayTMin, RayTCurrent> range.
bool IsAValidHit(in Ray ray, in float thit, in float3 hitSurfaceNormal)
{
    return IsInRange(thit, RayTMin(), RayTCurrent()) && !IsCulled(ray, hitSurfaceNormal);
}

// Texture coordinates on a horizontal plane.
float2 TexCoords(in float3 position)
{
    return position.xz;
}

// Calculate ray differentials.
void CalculateRayDifferentials(out float2 ddx_uv, out float2 ddy_uv, in float2 uv, in float3 hitPosition, in float3 surfaceNormal, in float3 cameraPosition, in float4x4 projectionToWorldWithCameraEyeAtOrigin)
{
    // Compute ray differentials by intersecting the tangent plane to the  surface.
    Ray ddx = GenerateCameraRay(DispatchRaysIndex().xy + uint2(1, 0), cameraPosition, projectionToWorldWithCameraEyeAtOrigin);
    Ray ddy = GenerateCameraRay(DispatchRaysIndex().xy + uint2(0, 1), cameraPosition, projectionToWorldWithCameraEyeAtOrigin);

    // Compute ray differentials.
    float3 ddx_pos = ddx.origin - ddx.direction * dot(ddx.origin - hitPosition, surfaceNormal) / dot(ddx.direction, surfaceNormal);
    float3 ddy_pos = ddy.origin - ddy.direction * dot(ddy.origin - hitPosition, surfaceNormal) / dot(ddy.direction, surfaceNormal);

    // Calculate texture sampling footprint.
    ddx_uv = TexCoords(ddx_pos) - uv;
    ddy_uv = TexCoords(ddy_pos) - uv;
}

// Forward declaration.
float CheckersTextureBoxFilter(in float2 uv, in float2 dpdx, in float2 dpdy, in UINT ratio);

// Return analytically integrated checkerboard texture (box filter).
float AnalyticalCheckersTexture(in float3 hitPosition, in float3 surfaceNormal, in float3 cameraPosition, in float4x4 projectionToWorldWithCameraEyeAtOrigin )
{
    float2 ddx_uv;
    float2 ddy_uv;
    float2 uv = TexCoords(hitPosition);

    CalculateRayDifferentials(ddx_uv, ddy_uv, uv, hitPosition, surfaceNormal, cameraPosition, projectionToWorldWithCameraEyeAtOrigin);
    return CheckersTextureBoxFilter(uv, ddx_uv, ddy_uv, 50);
}

// Fresnel reflectance - schlick approximation.
float3 FresnelReflectanceSchlick(in float3 I, in float3 N, in float3 f0)
{
    float cosi = saturate(dot(-I, N));
    return f0 + (1 - f0)*pow(1 - cosi, 5);
}

float3 RemoveSRGB(float3 x)
{
#if APPLY_SRGB_CORRECTION
	return x < 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4);
#else
	return x;
#endif
}

float3 ApplySRGB(float3 x)
{
#if APPLY_SRGB_CORRECTION
	return x < 0.0031308 ? 12.92 * x : 1.055 * pow(abs(x), 1.0 / 2.4) - 0.055;
#else
	return x;
#endif
}


// TODo
/***************************************************************/
// Normal encoding
// The MIT License
// Copyright � 2017 Inigo Quilez
// Ref: https://www.shadertoy.com/view/Mtfyzl
uint octahedral_32(in float3 nor, uint sh)
{
    nor /= (abs(nor.x) + abs(nor.y) + abs(nor.z));
    nor.xy = (nor.z >= 0.0) ? nor.xy : (1.0 - abs(nor.yx))*sign(nor.xy);
    float2 v = 0.5 + 0.5*nor.xy;

    uint mu = (1u << sh) - 1u;
    uint2 d = uint2(floor(v*float(mu) + 0.5));
    return (d.y << sh) | d.x;
}

float3 i_octahedral_32(uint data, uint sh)
{
    uint mu = (1u << sh) - 1u;

    uint2 d = uint2(data, data >> sh) & mu;
    float2 v = float2(d) / float(mu);

    v = -1.0 + 2.0*v;

    // Rune Stubbe's version, much faster than original
    float3 nor = float3(v, 1.0 - abs(v.x) - abs(v.y));
    float t = max(-nor.z, 0.0);
    nor.x += (nor.x > 0.0) ? -t : t;
    nor.y += (nor.y > 0.0) ? -t : t;

    return normalize(nor);
}
/***************************************************************/


/***************************************************************/
// Normal encoding
// Ref: https://knarkowicz.wordpress.com/2014/04/16/octahedron-normal-vector-encoding/
float2 OctWrap(float2 v)
{
    return (1.0 - abs(v.yx)) * (v.xy >= 0.0 ? 1.0 : -1.0);
}

float2 Encode(float3 n)
{
    n /= (abs(n.x) + abs(n.y) + abs(n.z));
    n.xy = n.z >= 0.0 ? n.xy : OctWrap(n.xy);
    n.xy = n.xy * 0.5 + 0.5;
    return n.xy;
}

float3 Decode(float2 f)
{
    f = f * 2.0 - 1.0;

    // https://twitter.com/Stubbesaurus/status/937994790553227264
    float3 n = float3(f.x, f.y, 1.0 - abs(f.x) - abs(f.y));
    float t = saturate(-n.z);
    n.xy += n.xy >= 0.0 ? -t : t;
    return normalize(n);
}
/***************************************************************/



/***************************************************************/
// ToDo
// 3D value noise
// Ref: https://www.shadertoy.com/view/XsXfRH
#if 1
float hash(float3 p)  // replace this by something better
{
    p = frac(p*0.3183099 + .1);
    p *= 17.0;
    return frac(p.x*p.y*p.z*(p.x + p.y + p.z));
}

float noise(in float3 x)
{
    float3 p = floor(x);
    float3 f = frac(x);
    f = f * f*(3.0 - 2.0*f);

    return lerp(lerp(lerp(hash(p + float3(0, 0, 0)),
        hash(p + float3(1, 0, 0)), f.x),
        lerp(hash(p + float3(0, 1, 0)),
            hash(p + float3(1, 1, 0)), f.x), f.y),
        lerp(lerp(hash(p + float3(0, 0, 1)),
            hash(p + float3(1, 0, 1)), f.x),
            lerp(hash(p + float3(0, 1, 1)),
                hash(p + float3(1, 1, 1)), f.x), f.y), f.z);
}
#endif

/***************************************************************/


// Sample normal map, convert to signed, apply tangent-to-world space transform.
float3 BumpMapNormalToWorldSpaceNormal(float3 bumpNormal, float3 surfaceNormal, float3 tangent)
{
    // Compute tangent frame.
    surfaceNormal = normalize(surfaceNormal);
    tangent = normalize(tangent);

    float3 binormal = normalize(cross(tangent, surfaceNormal));
    float3x3 tangentSpaceToWorldSpace = float3x3(tangent, binormal, surfaceNormal);

    return mul(bumpNormal, tangentSpaceToWorldSpace);
}


// Calculate a tangent from triangle's vertices and their uv coordinates.
// Ref: http://www.opengl-tutorial.org/intermediate-tutorials/tutorial-13-normal-mapping/
float3 CalculateTangent(in float3 v0, in float3 v1, in float3 v2, in float2 uv0, in float2 uv1, in float2 uv2)
{
    // Calculate edges
    // Position delta
    float3 deltaPos1 = v1 - v0;
    float3 deltaPos2 = v2 - v0;

    // UV delta
    float2 deltaUV1 = uv1 - uv0;
    float2 deltaUV2 = uv2 - uv0;

    float r = 1.0f / (deltaUV1.x * deltaUV2.y - deltaUV1.y * deltaUV2.x);
    return (deltaPos1 * deltaUV2.y - deltaPos2 * deltaUV1.y)*r;
}

#endif // RAYTRACINGSHADERHELPER_H