Shader "Hidden/DFA/DepthCopy"
{
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }

        // Pass 0 — copy an RFloat colour texture into a hardware depth buffer.
        // Used after DepthDownsample to seed _pass2DepthTex / _pass3DepthTex
        // so the GPU depth test rejects transparent fragments behind opaques.
        Pass
        {
            Name "ColourToDepth"
            ColorMask 0
            ZWrite On
            ZTest Always
            Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            TEXTURE2D(_DepthTex);
            //SAMPLER(sampler_PointClamp);

            struct FragOut { float depth : SV_Depth; };

            FragOut frag(Varyings i)
            {
                FragOut o;
                o.depth = SAMPLE_TEXTURE2D(_DepthTex, sampler_PointClamp, i.texcoord).r;
                return o;
            }
            ENDHLSL
        }
    }
}