 Shader "Hidden/OIT/A-Buffer/Composition Pass"
{
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }
        ZTest Off
        ZWrite Off 
        Cull Off
        
        Pass
        {
            Name "A-Buffer Composite"
            
            HLSLPROGRAM
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
                #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

                #pragma target 5.0
                #pragma vertex Vert
                #pragma fragment frag

                #define MAX_ABUFFER_FRAGMENTS 100

                int _width;
                int _height;
                
                struct Fragment
                {
                    float4 color;
                    float4 depth;
                };

                StructuredBuffer<Fragment> aBuffer;
                StructuredBuffer<uint> atomicsBuffer;
                
                half4 frag(Varyings i) : SV_Target
                {
                    float2 uv = GetNormalizedScreenSpaceUV(i.positionCS);
                    float2 pixel = int2(float2(_width, _height) * saturate(uv)); //Pixel position
                    pixel = clamp(pixel, int2(0, 0), int2(_width - 1, _height - 1));
    
                    int pixel_idx = pixel.x + pixel.y * _width;
                    int slice_stride = _width * _height;

                    int layers = min(MAX_ABUFFER_FRAGMENTS, atomicsBuffer[pixel_idx]);

                    Fragment pixel_fragments[MAX_ABUFFER_FRAGMENTS];

                    int layer;
                    //Fetch
                    [loop]
                    for (layer = 0; layer < layers; layer++)
                    {
                        int idx = pixel_idx + layer * slice_stride;
                        pixel_fragments[layer].color = aBuffer[idx].color;
                        pixel_fragments[layer].depth = aBuffer[idx].depth;
                    }

                    //Sort by depth (Back to Front)
                    [loop]
                    for (int j = 0; j < layers - 1; j++)
                    {
                        [loop]
                        for (int k = 0 ; k < layers - j - 1; k++)
                        {
                            if (pixel_fragments[k].depth.r < pixel_fragments[k+1].depth.r)
                            {
                                Fragment tmp = pixel_fragments[k];
                                pixel_fragments[k] = pixel_fragments[k+1];
                                pixel_fragments[k + 1] = tmp;
                            }
                        }
                    }

                    //Composite
                    half4 accum;
                    accum = SAMPLE_TEXTURE2D(_BlitTexture, sampler_PointClamp, i.texcoord);
                    [loop]
                    for (layer = 0; layer < layers; layer++)
                    {
                        float4 fragment_color =  pixel_fragments[layer].color;
                        accum.rgb = lerp(accum.rgb, fragment_color.rgb, fragment_color.a);
                    }
                    return half4(accum.rgb, 1.0);
                }
            ENDHLSL
        }
    }
    Fallback "Diffuse"
}