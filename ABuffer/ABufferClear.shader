Shader "Hidden/OIT/A-Buffer/Clear Pass"
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
            Name "A-Buffer Clear"
            
            HLSLPROGRAM
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
                #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

                #pragma target 5.0
                #pragma vertex Vert
                #pragma fragment frag
                
                int _width;
                int _height;
                
                struct Fragment
                {
                    float4 color;
                    float4 depth;
                };
                
                RWStructuredBuffer<uint> atomicsBuffer : register(u2);
                
                half4 frag(Varyings i) : SV_Target
                {
                    float2 uv = GetNormalizedScreenSpaceUV(i.positionCS);
                    uint2 pixel = uint2(float2(_width, _height) * saturate(uv)); //Pixel position
                    pixel = clamp(pixel, int2(0, 0), int2(_width - 1, _height - 1));
    
                    int pixel_idx = pixel.x + pixel.y * _width;
                    atomicsBuffer[pixel_idx] = 0;
                    return 0;
                }
            ENDHLSL
        }
    }
    Fallback "Diffuse"
}