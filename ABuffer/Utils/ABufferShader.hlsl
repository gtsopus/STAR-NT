#define MAX_ABUFFER_FRAGMENTS 100

struct Fragment
{
    float4 color;
    float4 depth;
};

RWStructuredBuffer<Fragment> aBuffer : register(u1);
RWStructuredBuffer<uint> atomicsBuffer : register(u2);

int _width;
int _height;
int _maxLayers;

#ifdef UNIVERSAL_PARTICLES_INCLUDED
    #define VARYINGS VaryingsParticle 
#else
    #define VARYINGS Varyings
    TEXTURE2D(_CameraDepthTexture);
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
        float clipZ = input.clipPos.z;
    #else
        float clipZ = input.positionCS.z;
    #endif
    return Linear01Depth(clipZ, _ZBufferParams);
}

half4 ABUFFERPassFragment (VARYINGS input) : SV_Target
{
    half4 fragment_color = shadeSurface(input);
    float depth = surfaceDepth(input);

    Fragment f;
    f.color = fragment_color;
    f.depth = float4(depth, depth, depth, depth);

    #ifdef UNIVERSAL_PARTICLES_INCLUDED
        float4 positionCS = input.clipPos;
    #else
        float4 positionCS = input.positionCS;
    #endif
    
    float2 uv = GetNormalizedScreenSpaceUV(positionCS);
    int2 pixel_position = int2(float2(_width, _height) * saturate(uv)); //Pixel position
    pixel_position = clamp(pixel_position, int2(0, 0), int2(_width - 1, _height - 1));
    int pixel_idx = pixel_position.x + pixel_position.y * _width; //1d pixel index
    int slice_stride = _width * _height;//Pixel stride
    uint layers = min(MAX_ABUFFER_FRAGMENTS, _maxLayers);

    //Manual zTest because writing to a-Buffer disables early z-testing
    float opaqueDepth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_PointClamp, uv), _ZBufferParams);
    if (opaqueDepth < depth) discard;

    //Increment fragment counter
    uint pixel_counter;
    InterlockedAdd(atomicsBuffer[pixel_idx], 1, pixel_counter);

    if (pixel_counter >= layers) discard; //Discard overflown fragments 
                    
    aBuffer[pixel_idx + pixel_counter * slice_stride] = f;
    return half4(0, 0, 0, 0);
}