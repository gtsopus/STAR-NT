Shader "Hidden/OIT/WBOIT/Composition Pass"
{
    Properties
    {
        _AccumTex("_AccumTex", 2D) = "black" {}
        _RevealageTex("_RevealageTex", 2D) = "black" {}
    }

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
            Name "WBOIT Composite"
            
            HLSLPROGRAM
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
                #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

                #pragma vertex Vert
                #pragma fragment frag
                
                TEXTURE2D(_AccumTex);
                TEXTURE2D(_RevealageTex);
                
                half4 frag(Varyings i) : SV_Target
                {
                    half4 bgColour = SAMPLE_TEXTURE2D(_BlitTexture, sampler_PointClamp, i.texcoord);
                    half4 accumulation = SAMPLE_TEXTURE2D(_AccumTex, sampler_PointClamp, i.texcoord);
                    float revealage = SAMPLE_TEXTURE2D(_RevealageTex, sampler_PointClamp, i.texcoord).r;

                    half3 color = lerp(accumulation.rgb/max(accumulation.a, 0.0001), bgColour.rgb, revealage);
                    half4 OUT = float4(color, 1.0);
                    
                    return OUT;
                }
            ENDHLSL
        }
    }
    Fallback "Diffuse"
}