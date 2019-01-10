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

#ifndef RAYTRACINGHLSLCOMPAT_H
#define RAYTRACINGHLSLCOMPAT_H

//**********************************************************************************************
//
// RaytracingHLSLCompat.h
//
// A header with shared definitions for C++ and HLSL source files. 
//
//**********************************************************************************************
#define ENABLE_RAYTRACING 1
#define RUNTIME_AS_UPDATES 0
#define USE_GPU_TRANSFORM 1

#define DEBUG_AS 0

#define PBRT_APPLY_INITIAL_TRANSFORM_TO_VB_ATTRIBUTES 1

#define ALLOW_MIRRORS 1

// ToDo set max recursion
// Give opacity to mirrors and shade. Some mirrors are tesselated in the kitchen and its not clear from pure reflections.
#if ALLOW_MIRRORS
// Use anyhit instead??
#define TURN_MIRRORS_SEETHROUGH 0
#endif

#define CAMERA_PRESERVE_UP_ORIENTATION 1

#define DOUBLE_ALL_FACES 0
#define ADD_INVERTED_FACE 0
#define CORRECT_NORMALS 0


// ToDo 16bit per component normals?
#define FLOAT_TEXTURE_AS_R8_UNORM_1BYTE_FORMAT 1

#define GBUFFER_AO_NORMAL_VISUALIZATION 0
#define GBUFFER_AO_COUNT_AO_HITS 0
#define AO_ANY_HIT_FULL_OCCLUSION 0
#define TWO_STAGE_AO_BLUR 1
#define AO_RANDOM_SEED_EVERY_FRAME 0
#define AO_HITPOSITION_BASED_SEED 1
#define VARIANCE_APPROXIMATION 1

#define COMPRES_NORMALS 1
#define PACK_NORMAL_AND_DEPTH 1

#define BLUR_AO 1
#define ATROUS_DENOISER 1
#define ATROUS_DENOISER_MAX_PASSES 10
#define RENDER_RNG_SAMPLE_VISUALIZATION 1   // ToDo doesn't render for all AA settings
#define ATROUS_ONELEVEL_ONLY 0

#define CAMERA_JITTER 0
#define APPLY_SRGB_CORRECTION 0
#define AO_ONLY 0
// ToDO this wasn't necessary before..
#define VBIB_AS_NON_PIXEL_SHADER_RESOURCE 0

#define ONLY_SQUID_SCENE_BLAS 1
#if ONLY_SQUID_SCENE_BLAS
#define PBRT_SCENE 1
#define FACE_CULLING !PBRT_SCENE
#if PBRT_SCENE
#define DISTANCE_FALLOFF 0.000002
#define AO_RAY_T_MAX 2
#else
#define DISTANCE_FALLOFF 0
#define AO_RAY_T_MAX 35
#endif
#define CAMERA_Y_SCALE 1
#define FLAT_FACE_NORMALS 0
#define INDEX_FORMAT_UINT 1
#define NUM_GEOMETRIES 1
#else
#define AO_RAY_T_MAX 0.06
#define FACE_CULLING 1
#define INDEX_FORMAT_UINT 0
#define FLAT_FACE_NORMALS 1
#define CAMERA_Y_SCALE 1.3f
#define NUM_GEOMETRIES 100000

#endif

#define AO_OVERDOSE_BEND_NORMALS_DOWN 0
#define TESSELATED_GEOMETRY_BOX 1
#define TESSELATED_GEOMETRY_TEAPOT 1
#define TESSELATED_GEOMETRY_BOX_TETRAHEDRON 1
#define TESSELATED_GEOMETRY_BOX_TETRAHEDRON_REMOVE_BOTTOM_TRIANGLE 1
#define TESSELATED_GEOMETRY_THIN 1
#define TESSELATED_GEOMETRY_TILES 0
#define TESSELATED_GEOMETRY_TILES_WIDTH 4
#define TESSELATED_GEOMETRY_ASPECT_RATIO_DIMENSIONS 1


// ToDo separate per-vertex attributes from VB

// ToDo move
namespace ReduceSumCS {
	namespace ThreadGroup {
		enum Enum { Width = 8, Height = 16, Size = Width * Height, NumElementsToLoadPerThread = 10 };	
	}
}

namespace AtrousWaveletTransformFilterCS {
    namespace ThreadGroup {
        enum Enum { Width = 16, Height = 16, Size = Width * Height };
    }
}

namespace CalculateVariance_Bilateral {
    namespace ThreadGroup {
        enum Enum { Width = 16, Height = 8, Size = Width * Height };
    }
}

namespace PerPixelMeanSquareError {
    namespace ThreadGroup {
        enum Enum { Width = 8, Height = 8, Size = Width * Height};
    }
}

namespace DownsampleBoxFilter2x2 {
	namespace ThreadGroup {
		enum Enum { Width = 8, Height = 8 };
	}
}
// ToDo cleanup
namespace DownsampleGaussianFilter {
	namespace ThreadGroup {
		enum Enum { Width = 8, Height = 8 };
	}
}

namespace DownsampleBilateralFilter {
    namespace ThreadGroup {
        enum Enum { Width = 8, Height = 8 };
    }
}

namespace UpsampleBilateralFilter {
    namespace ThreadGroup {
        enum Enum { Width = 8, Height = 8 };
    }
}

namespace GaussianFilter {
    namespace ThreadGroup {
        enum Enum { Width = 8, Height = 8 };
    }
}

namespace RootMeanSquareError {
    namespace ThreadGroup {
        enum Enum { Width = 8, Height = 8 };
    }
}

namespace ComposeRenderPassesCS {
	namespace ThreadGroup {
		enum Enum { Width = 8, Height = 8, Size = Width * Height };
	}
}

namespace AoBlurCS {
    namespace ThreadGroup {
		enum Enum { Width = 8, Height = 8 };
    }
}

#ifdef HLSL
#include "util\HlslCompat.h"
#if INDEX_FORMAT_UINT
typedef UINT Index;
#endif
#else
using namespace DirectX;

#if INDEX_FORMAT_UINT
typedef UINT Index;
#else
typedef UINT16 Index;
#endif
#endif


// ToDo revise
// PERFORMANCE TIP: Set max recursion depth as low as needed
// as drivers may apply optimization strategies for low recursion depths.
#define MAX_RAY_RECURSION_DEPTH 3    // ~ primary rays + reflections + shadow rays from reflected geometry.  

// ToDo:
// Options:
// - shading - simple/complex
// - instanced/unique goemetry
// - deformed geometry
// - Dynamic options
// - Update/Build
#define ALBEDO_SHADING 0
#define NORMAL_SHADING 0
#define DEPTH_SHADING 0
#define SINGLE_COLOR_SHADING 0

struct ProceduralPrimitiveAttributes
{
    XMFLOAT3 normal;
};

struct RayPayload
{
    XMFLOAT4 color;
    UINT   recursionDepth;
};

struct GBufferRayPayload
{
	UINT hit;
	XMUINT2 materialInfo;   // {materialID, 16b 2D texCoord}
	XMFLOAT3 hitPosition;
	XMFLOAT3 surfaceNormal;	// ToDo test encoding normal into 2D
#if ALLOW_MIRRORS
	UINT rayRecursionDepth;
#endif
};

struct ShadowRayPayload
{
    UINT hit;
};

struct RNGConstantBuffer
{
    XMUINT2 uavOffset;     // offset where [0,0] thread should write to.
    XMUINT2 dispatchDimensions;  // for 2D dispatches
	UINT sampleSetBase;
    UINT numSamples;
    UINT numSampleSets;
    UINT numSamplesToShow; 
    // TODo: Why is padding to 16 needed? cb gets corrupted otherwise. Put a static_assert in ConstantBuffer
    XMUINT2 stratums;      // Stratum resolution
    XMUINT2 grid;      // Grid resolution
};


struct AtrousWaveletTransformFilterConstantBuffer
{
    // ToDo pad?
    XMINT2 textureDim;
    UINT kernelStepShift;
    UINT scatterOutput;
    float valueSigma;
    float depthSigma;
    float normalSigma;
    UINT useCalculatedVariance;
    XMFLOAT3 padding;
    UINT useApproximateVariance;
};


struct SceneConstantBuffer
{
    XMMATRIX projectionToWorldWithCameraEyeAtOrigin;	// projection to world matrix with Camera at (0,0,0).
    XMVECTOR cameraPosition;
	XMVECTOR lightPosition;
    float    reflectance;
    float    elapsedTime;                 // Elapsed application time.
	float Zmin;
	float Zmax;
    UINT seed;
    UINT numSamples;
    UINT numSampleSets;
    UINT numSamplesToUse;    
    XMFLOAT2 cameraJitter;
	XMFLOAT2 padding;
};
 
// ToDo explain padding
struct ComposeRenderPassesConstantBuffer
{
	XMUINT2 rtDimensions;
	XMFLOAT2 padding1;
	XMFLOAT3 cameraPosition;
    UINT renderAOonly;
	XMFLOAT3 lightPosition;     // ToDo cb doesn't match if XMFLOAT starts at offset 1. Can this be caught?
    UINT enableAO;
	XMFLOAT3 lightAmbientColor;
	float padding4;
	XMFLOAT3 lightDiffuseColor;		
	float padding5;
};

struct AoBlurConstantBuffer
{
	XMFLOAT2 kRcpBufferDim;
	float kDistanceTolerance;
};

struct DownsampleFilterConstantBuffer
{
	XMUINT2 inputTextureDimensions;
	XMFLOAT2 invertedInputTextureDimensions;
};

struct GaussianFilterConstantBuffer
{
    XMUINT2 textureDim;
    XMFLOAT2 invTextureDim;
};

// Attributes per primitive type.
struct PrimitiveConstantBuffer
{
	UINT     materialID;
    XMUINT3   padding;
};

struct PrimitiveMaterialBuffer
{
	XMFLOAT3 diffuse;
	XMFLOAT3 specular;
    float specularPower;
    // ToDo use a bitmask?
    UINT hasDiffuseTexture;
    UINT hasNormalTexture;
    UINT hasPerVertexTangents;
    UINT isMirror;
    UINT padding;
};

// Attributes per primitive instance.
struct PrimitiveInstanceConstantBuffer
{
    UINT instanceIndex;  
    UINT primitiveType; // Procedural primitive type
};

// Dynamic attributes per primitive instance.
struct PrimitiveInstancePerFrameBuffer
{
    XMMATRIX localSpaceToBottomLevelAS;   // Matrix from local primitive space to bottom-level object space.
    XMMATRIX bottomLevelASToLocalSpace;   // Matrix from bottom-level object space to local primitive space.
};

struct AlignedUnitSquareSample2D
{
    XMFLOAT2 value;
    XMUINT2 padding;  // Padding to 16B
};

struct AlignedHemisphereSample3D
{
    XMFLOAT3 value;
    UINT padding;  // Padding to 16B
};

struct Vertex
{
    XMFLOAT3 position;
    XMFLOAT3 normal;
};

struct VertexPositionNormalTexture
{
	XMFLOAT3 position;
	XMFLOAT3 normal;
	XMFLOAT2 uv;
};

struct VertexPositionNormalTextureTangent
{
	XMFLOAT3 position;
	XMFLOAT3 normal;
	XMFLOAT2 textureCoordinate;
	XMFLOAT3 tangent;
};


namespace RayGenShaderType {
	enum Enum {
		GBuffer = 0,
		AOFullRes,
        AOQuarterRes,
		Visibility,
		Count
	};
}


// Ray types traced in this sample.
namespace RayType {
    enum Enum {
        Radiance = 0,   // ~ Primary, reflected camera/view rays calculating color for each hit.
        Shadow,         // ~ Shadow/visibility rays, only testing for occlusion
		GBuffer,		// ~ Primary camera ray generating GBuffer data.
        Count
    };
}

namespace TraceRayParameters
{
    static const UINT InstanceMask = ~0;   // Everything is visible.
    namespace HitGroup {
        static const UINT Offset[RayType::Count] =
        {
            0, // Radiance ray
            1, // Shadow ray
			2  // GBuffer ray
        };
		// ToDo For now all geometries reusing shader records
		static const UINT GeometryStride = RayType::Count;
    }
    namespace MissShader {
        static const UINT Offset[RayType::Count] =
        {
            0, // Radiance ray
            1, // Shadow ray
			2, // GBuffer ray
        };
    }
}

static const XMFLOAT4 BackgroundColor = XMFLOAT4(0.79f, 0.88f, 0.98f, 1.0f);
// ToDo
static const float InShadowRadiance = 0.35f;

#endif // RAYTRACINGHLSLCOMPAT_H