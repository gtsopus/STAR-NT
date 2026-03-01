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
                #include "../Utils/DFANetwork.hlsl"

                #pragma vertex Vert
                #pragma fragment frag

                TEXTURE2D(_firstFragment);
                TEXTURE2D(_secondFragment);
                TEXTURE2D(_pmAccumulation);
                TEXTURE2D(_accumulation);
                TEXTURE2D(_fragmentCount);

                half4 frag(Varyings i) : SV_Target
                {
                    uint fragmentCount = uint(round(SAMPLE_TEXTURE2D(_fragmentCount, sampler_PointClamp, i.texcoord).r));
                    half4 bgColor = float4(1, 1, 1, 0);

                    if (fragmentCount == 0) return bgColor;

                    half4 firstFragment = SAMPLE_TEXTURE2D(_firstFragment, sampler_PointClamp, i.texcoord);

                    if (fragmentCount == 1)
                    {
                        half3 blend = firstFragment.a * firstFragment.rgb + (1.0 - firstFragment.a) * bgColor.rgb;
                        return half4(blend, 1.0);
                    }

                    half4 secondFragment = SAMPLE_TEXTURE2D(_secondFragment, sampler_PointClamp, i.texcoord);
                    half4 pmAccumulation  = SAMPLE_TEXTURE2D(_pmAccumulation,  sampler_PointClamp, i.texcoord);

                    half3 correct2 = firstFragment.a * firstFragment.rgb
                                   + (1.0 - firstFragment.a) * secondFragment.a * secondFragment.rgb;

                    if (fragmentCount == 2)
                    {
                        half3 blend = correct2 + (1.0 - firstFragment.a) * (1.0 - secondFragment.a) * bgColor.rgb;
                        return half4(blend, 1.0);
                    }

                    if (fragmentCount == 3)
                    {
                        pmAccumulation.rgb -= firstFragment.rgb  * firstFragment.a;
                        pmAccumulation.rgb -= secondFragment.rgb * secondFragment.a;
                        half3 blend = correct2
                                    + (1.0 - firstFragment.a) * (1.0 - secondFragment.a) * pmAccumulation.rgb
                                    + pmAccumulation.a * bgColor.rgb;
                        return half4(blend, 1.0);
                    }

                    half4 average = SAMPLE_TEXTURE2D(_accumulation, sampler_PointClamp, i.texcoord);
                    average  = average - firstFragment;
                    average  = average - secondFragment;
                    average  = average / (fragmentCount - 2);

                    float transmittance = pmAccumulation.a;

                    float input[10] = {
                        average.a, average.r, average.g, average.b,
                        pmAccumulation.r, pmAccumulation.g, pmAccumulation.b,
                        correct2.r, correct2.g, correct2.b
                    };

                    half3 inf  = infer(input);
                    half3 OUT  = inf + transmittance * bgColor.rgb;
                    return half4(OUT, 1.0);
                }
            ENDHLSL
        }
    }
    Fallback "Diffuse"
}