Shader "Hidden/OIT/DFA/Depth Peeling/Infer Pass"
{
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }
        
        Pass
        {
            Name "DFADPInferPass"
            ZTest Off
            ZWrite Off
            Cull Off
            Blend Off
            
            HLSLPROGRAM
                #pragma target 5.0
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
                #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

                #pragma vertex Vert
                #pragma fragment frag

                #include "../Utils/DFANetwork.hlsl"

                TEXTURE2D(_firstFragment);
                TEXTURE2D(_secondFragment);
                TEXTURE2D(_pmAccumulation);
                TEXTURE2D(_accumulation);
                TEXTURE2D(_fragmentCount);
                TEXTURE2D(_CornerMask);
                SAMPLER(sampler_CornerMask);

                half4 frag(Varyings i) : SV_Target
                {
                    float s = SAMPLE_TEXTURE2D(_CornerMask, sampler_CornerMask, i.texcoord).r;
                    if (s == 0) {
                        discard;
                    }

                    uint fragmentCount = uint(round(SAMPLE_TEXTURE2D(_fragmentCount, sampler_PointClamp, i.texcoord)).r);
                    half4 bgColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_PointClamp, i.texcoord);
                    //bgColor = half4(1,1,1,0);


                    // if (fragmentCount == 0) return bgColor;
                    if (fragmentCount == 0) return float4(bgColor.rgb,1);

                    half4 firstFragment = SAMPLE_TEXTURE2D(_firstFragment, sampler_PointClamp, i.texcoord);
                    
                    if (fragmentCount == 1)
                    {
                        half3 blend = firstFragment.a * firstFragment.rgb + (1.0 - firstFragment.a) * bgColor.rgb;
                        return half4(blend, 1.0);
                    }

                    half4 secondFragment = SAMPLE_TEXTURE2D(_secondFragment, sampler_PointClamp, i.texcoord);
                    half4 pmAccumulation = SAMPLE_TEXTURE2D(_pmAccumulation, sampler_PointClamp, i.texcoord);
                    
                    half3 correct2 = firstFragment.a * firstFragment.rgb + (1.0 - firstFragment.a) * secondFragment.a * secondFragment.rgb;
                    if (fragmentCount == 2)
                    {
                        half3 blend = correct2 + (1.0 - firstFragment.a) * (1.0 - secondFragment.a) * bgColor.rgb;
                        return half4(blend, 1.0);
                    }
                    if (fragmentCount == 3)
                    {
                        pmAccumulation.rgb = pmAccumulation.rgb - firstFragment.rgb*firstFragment.a;
                        pmAccumulation.rgb = pmAccumulation.rgb - secondFragment.rgb*secondFragment.a;
                        half3 blend = correct2 + (1.0 - firstFragment.a) * (1.0 - secondFragment.a) * pmAccumulation.rgb + pmAccumulation.a *bgColor.rgb;
                        return half4(blend, 1.0);
                    }
    
                    // Normalize pm_acc without first two fragments (matching Python)
                    half4 average = SAMPLE_TEXTURE2D(_accumulation, sampler_PointClamp, i.texcoord);
                    half a_accum = average.a - firstFragment.a - secondFragment.a;
    
                    pmAccumulation.rgb = pmAccumulation.rgb - firstFragment.rgb * firstFragment.a - secondFragment.rgb * secondFragment.a;
                    pmAccumulation.rgb = pmAccumulation.rgb / a_accum;
    
                    // Calculate t_tail
                    half trans2 = (1.0 - firstFragment.a) * (1.0 - secondFragment.a);
                    half t_tail = pmAccumulation.a / trans2;
    
                    // Create input array matching Python: [t_tail, fc, pm_acc[0], pm_acc[1], pm_acc[2]]
                    float input[5] = {t_tail, float(fragmentCount), pmAccumulation.r, pmAccumulation.g, pmAccumulation.b};
    
                    half3 inf = correct2.rgb + trans2*infer(input) + pmAccumulation.a * bgColor.rgb;
                    return half4(inf, 0.98);
                }

            ENDHLSL
        }

    Fallback "Diffuse"
}