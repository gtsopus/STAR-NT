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

half surfaceDepth(VARYINGS input)
{
    #ifdef UNIVERSAL_PARTICLES_INCLUDED
        float clipZ = input.clipPos.z/input.clipPos.w;
    #else
        float clipZ = input.positionCS.z/input.positionCS.w;
    #endif
    return Linear01Depth(clipZ, _ZBufferParams);
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
        
        float depth = surfaceDepth(input);
        float2 uv = GetNormalizedScreenSpaceUV(positionCS);
        float prevDepth = SAMPLE_TEXTURE2D(_firstFragmentDepth, sampler_PointClamp, uv).r;
    
        clip(depth - (prevDepth + 0.001f));
        
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
        half4 fragment_color = shadeSurface(input);
        if (fragment_color.a < 0.03) discard;
        DFA_out o;

        o.fragmentCount = 1.0h;
        o.pmColorAcc.rgb = fragment_color.rgb * fragment_color.a;
        o.pmColorAcc.a = fragment_color.a;
        o.colorAcc = fragment_color;
        return o;
    }
#else
    struct DFA_out
    {
        half4 pmColorAcc : SV_Target0;
        half fragmentCount : SV_Target1;
        half4 colorAcc : SV_Target2;
    };

    StructuredBuffer<uint> _previousDepth;
    RWStructuredBuffer<uint> _firstFragment : register(u3);
    RWStructuredBuffer<uint> _secondFragment : register(u4);
    RWStructuredBuffer<uint> _currentDepth : register(u5);

    #include "DFAPackUtils.hlsl"

    DFA_out DFAPassFragment (VARYINGS input)
    {
        #ifdef UNIVERSAL_PARTICLES_INCLUDED
            float4 positionCS = input.clipPos;
        #else
            float4 positionCS = input.positionCS;
        #endif

        float2 uv = GetNormalizedScreenSpaceUV(positionCS);
        uint2 pidx = PixelIndexFromUV(uv, (uint2)_ScreenParams.xy);
        uint4 idx = IndexToBufferCoords4(pidx, (uint2)_ScreenParams.xy);

        half4 fragment_color = shadeSurface(input);
        if (fragment_color.a < 0.03) discard;
        half current_depth = surfaceDepth(input);

        uint4 uColor = f32tof16(fragment_color); //convert channels to 16-bit uints
        uint uDepth = f32tof16(current_depth); //convert depth to 16-bit uint
        uint4 pColor = PackDepthNColor4(uDepth, uColor); //pack colors and depth
        
        InsertPackedInterlockedMin4(_firstFragment, idx, pColor);
        InterlockedMin(_currentDepth[idx.x], uDepth);

        uint previous_depth = _previousDepth[idx.x];

        if (uDepth > previous_depth) //if you are further than the oracle then you are a candidate for the second fragment 
        {
            //We want the fragment with the minimum depth
            InsertPackedInterlockedMin4(_secondFragment, idx, pColor);
        }
        
        //Write the rest of the features to MRT
        DFA_out o;
        o.fragmentCount = 1.0h;
        o.pmColorAcc.rgb = fragment_color.rgb * fragment_color.a;
        o.pmColorAcc.a = fragment_color.a;
        o.colorAcc = fragment_color;
        return o;
    }
#endif
