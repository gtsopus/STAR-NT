Shader "Hidden/DFA/DepthDownsample"
{
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }

        // Pass 0 — max-downsample _CameraDepthTexture into an RFloat render target.
        // Reads URP's globally-bound depth texture (always shader-readable, never
        // a raw hardware sink) so no platform-specific sampling issues.
        Pass
        {
            Name "DepthDownsampleMax"
            ZWrite Off
            ZTest Always
            Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            TEXTURE2D_X_FLOAT(_CameraDepthTexture);
            float4 _CameraDepthTexture_TexelSize;

            float frag(Varyings i) : SV_Target
            {
                float2 uv = i.texcoord;
                float2 t  = _CameraDepthTexture_TexelSize.xy * 0.5;

                float d0 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_PointClamp, uv + float2(-t.x, -t.y)).r;
                float d1 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_PointClamp, uv + float2( t.x, -t.y)).r;
                float d2 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_PointClamp, uv + float2(-t.x,  t.y)).r;
                float d3 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_PointClamp, uv + float2( t.x,  t.y)).r;

                // Max = farthest depth = most conservative (keeps opaque geometry blocking)
                // Note: in reversed-Z pipelines max = farthest, in non-reversed max is also correct
                // because we want the most restrictive depth for transparent occlusion.
                return max(max(d0, d1), max(d2, d3));
            }
            ENDHLSL
        }
    }
}