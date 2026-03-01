#ifdef UNIVERSAL_PARTICLES_INCLUDED
#define VARYINGS VaryingsParticle 
#else
#define VARYINGS Varyings
#endif

half4 shadeSurface(VARYINGS input)
{
    //Unlit Pass
#ifdef URP_UNLIT_FORWARD_PASS_INCLUDED
    half4 fragment_color;
    UnlitPassFragment(input, fragment_color);
    return fragment_color;
#endif
    //Simple Lit Pass
#ifdef UNIVERSAL_SIMPLE_LIT_PASS_INCLUDED
    half4 fragment_color;
    LitPassFragmentSimple(input, fragment_color);
    return fragment_color;
#endif
    //Lit/Complex Lit Pass
#ifdef UNIVERSAL_FORWARD_LIT_PASS_INCLUDED
    half4 fragment_color;
    LitPassFragment(input, fragment_color);
    return fragment_color;
#endif
    //Baked Lit Pass
#ifdef UNIVERSAL_BAKEDLIT_PASS_INCLUDED
    half4 fragment_color;
    BakedLitForwardPassFragment(input, fragment_color);
    return fragment_color;
#endif
    //Particles Unlit Pass
#ifdef UNIVERSAL_PARTICLES_UNLIT_FORWARD_PASS_INCLUDED
    return fragParticleUnlit(input);
#endif
    //Particles Simple Lit Pass
#ifdef UNIVERSAL_PARTICLES_FORWARD_SIMPLE_LIT_PASS_INCLUDED
    return ParticlesLitFragment(input);
#endif
    //Particles Lit Pass
#ifdef UNIVERSAL_PARTICLES_FORWARD_LIT_PASS_INCLUDED
    return ParticlesLitFragment(input);
#endif 
}

// Returns Linear01 depth — used for depth peel comparison against _firstFragmentDepth.
half surfaceDepth(VARYINGS input)
{
#ifdef UNIVERSAL_PARTICLES_INCLUDED
    float clipZ = input.clipPos.z;
#else
    float clipZ = input.positionCS.z / input.positionCS.w;
#endif
    return Linear01Depth(clipZ, _ZBufferParams);
}

// Returns raw device depth — same value the GPU writes to the depth buffer
// and that _CameraDepthTexture / _OpaqueDepthDS contains.
// Used for ClipBehindOpaques so both sides are in the same space.
float surfaceRawDepth(VARYINGS input)
{
#ifdef UNIVERSAL_PARTICLES_INCLUDED
    // Particles interpolate clipPos so divide is needed
    return input.clipPos.z;
#else
    // SV_Position.z is the raw device depth written to the depth buffer
    return input.positionCS.z;
#endif
}

// Clips the current fragment if it falls behind opaque geometry.
//
// Full-res passes (_IsScaledPass == 0):
//   Early return — hardware depth sink seeded with real opaque depth via
//   CopyTexture, GPU depth test handles occlusion automatically.
//
// Scaled passes (_IsScaledPass == 1):
//   Hardware sink cleared to far, all fragments pass GPU depth test.
//   _OpaqueDepthDS is an RFloat colour texture containing max-downsampled
//   raw device depth from _CameraDepthTexture at scaled resolution.
//   rawSurfDepth and _OpaqueDepthDS are both raw device depth — same space,
//   no Linear01 conversion needed, no platform mismatch possible.

TEXTURE2D(_OpaqueDepthDS);
int _IsScaledPass;

void ClipBehindOpaques(float2 uv, float rawSurfDepth)
{
    if (_IsScaledPass == 0) return;

    float rawOpaque = SAMPLE_TEXTURE2D(_OpaqueDepthDS, sampler_PointClamp, uv).r;

    // Sky / no-opaque: allow transparent through.
    // Reversed-Z (Vulkan/Metal/DX12): near=1, far=0, sky=0.
    // Non-reversed (DX11):            near=0, far=1, sky=1.
#if UNITY_REVERSED_Z
    if (rawOpaque < 0.0001) return;
    // Fragment is behind opaque when its depth is smaller (further from camera).
    // clip() discards when argument < 0.
    clip(rawSurfDepth - rawOpaque);
#else
    if (rawOpaque > 0.9999) return;
    if (rawOpaque < 0.0001) return;
    // Fragment is behind opaque when its depth is larger (further from camera).
    clip(rawOpaque - rawSurfDepth);
#endif
}

#if defined(DFA_DEPTH_PASS1)
struct DFA_out
{
    half4 color : SV_Target0;
    float depth : SV_Target1;
};
DFA_out DFAPassFragment(VARYINGS input)
{
    DFA_out o;
    half4 fragment_color = shadeSurface(input);
    if (fragment_color.a < 0.03) discard;
    o.color = fragment_color;
    o.depth = surfaceDepth(input);
    return o;
}

#elif defined(DFA_DEPTH_PASS2)
Texture2D _firstFragmentDepth;
struct DFA_out
{
    half4 color : SV_Target0;
    float depth : SV_Target1;
};
DFA_out DFAPassFragment(VARYINGS input)
{
#ifdef UNIVERSAL_PARTICLES_INCLUDED
    float4 positionCS = input.clipPos;
#else
    float4 positionCS = input.positionCS;
#endif
    float depth = surfaceDepth(input);    // Linear01 — for depth peel
    float rawDepth = surfaceRawDepth(input); // raw device — for opaque clip
    float2 uv = GetNormalizedScreenSpaceUV(positionCS);

    float prevDepth = SAMPLE_TEXTURE2D(_firstFragmentDepth, sampler_PointClamp, uv).r;
    // Depth peel: discard fragments at or in front of the first layer
    clip(depth - (prevDepth));
    // Discard fragments behind opaques (scaled passes only)
    ClipBehindOpaques(uv, rawDepth);

    half4 fragment_color = shadeSurface(input);
    if (fragment_color.a < 0.03) discard;
    DFA_out o;
    o.color = fragment_color;
    o.depth = depth;
    return o;
}

#elif defined(DFA_FEATURE_FETCH)
struct DFA_out
{
    half4 pmColorAcc : SV_Target0;
    half fragmentCount : SV_Target1;
    half4 colorAcc : SV_Target2;
};
DFA_out DFAPassFragment(VARYINGS input)
{
#ifdef UNIVERSAL_PARTICLES_INCLUDED
    float4 positionCS = input.clipPos;
#else
    float4 positionCS = input.positionCS;
#endif
    float rawDepth = surfaceRawDepth(input); // raw device — for opaque clip
    float2 uv = GetNormalizedScreenSpaceUV(positionCS);
    // Discard fragments behind opaques (scaled passes only)
    ClipBehindOpaques(uv, rawDepth);

    half4 fragment_color = shadeSurface(input);
    if (fragment_color.a < 0.03) discard;
    DFA_out o;
    o.fragmentCount = 1.0h;
    o.pmColorAcc.rgb = fragment_color.rgb * fragment_color.a;
    o.pmColorAcc.a = fragment_color.a;
    o.colorAcc = fragment_color;
    return o;
}
#endif
