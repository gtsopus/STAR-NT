struct WBOIT_out
{
    half4 accumulation : SV_Target0;
    half4 revealage : SV_Target1;
};

//Equation 10 
float weight(float z, float a)
{
    float fz3 = (1-z)*(1-z)*(1-z);
    return a * max(1e-2, 3e3*fz3);
}

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

WBOIT_out WBOITPassFragment (VARYINGS input)
{
    half4 fragment_color = shadeSurface(input);
    float depth =  surfaceDepth(input);

    WBOIT_out output;
    output.accumulation = half4(fragment_color.rgb * fragment_color.a, fragment_color.a) * weight(depth, fragment_color.a);
    output.revealage = half4(fragment_color.a, fragment_color.a, fragment_color.a, fragment_color.a);
    return output;
}