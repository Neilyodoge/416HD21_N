Shader "Hidden/Shader/PP_SNN"
{
    Properties
    {
        // This property is necessary to make the CommandBuffer.Blit bind the source texture to _MainTex
        _MainTex("Main Texture", 2DArray) = "grey" {}
        _SNNIntensity("LerpBase",range(0,1)) = 1
        _SNNPixelWidth ("Sampler Count", range(2,7)) = 5
    }

    HLSLINCLUDE

    #pragma target 4.5
    #pragma only_renderers d3d11 playstation xboxone xboxseries vulkan metal switch

    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/PostProcessing/Shaders/FXAA.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/PostProcessing/Shaders/RTUpscale.hlsl"

    struct Attributes
    {
        uint vertexID : SV_VertexID;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct Varyings
    {
        float4 positionCS : SV_POSITION;
        float2 texcoord   : TEXCOORD0;
        UNITY_VERTEX_OUTPUT_STEREO
    };

    Varyings Vert(Attributes input)
    {
        Varyings output;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
        output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
        output.texcoord = GetFullScreenTriangleTexCoord(input.vertexID);
        return output;
    }

    // List of properties to control your post process effect
    float _Intensity;
    float _SNNPixelWidth;
    float _SNNIntensity;
    TEXTURE2D_X(_MainTex);

    //Copy from https://www.shadertoy.com/view/MlyfWd
    // Calculate color distance
    float CalcDistance(float3 c0, float3 c1)
    {
        float3 sub = c0 - c1;
        return dot(sub, sub);
    }
    
    // Symmetric Nearest Neighbor
    float3 CalcSNN(float2 fragCoord,float3 c0)
    {
        float2 uv = fragCoord;
        
        //float3 c0 = SAMPLE_TEXTURE2D_X(_MainTex, s_linear_clamp_sampler,uv);
        
        float4 sum = float4(0.0f, 0.0f, 0.0f, 0.0f);
        
        for (int i = 0; i <= _SNNPixelWidth; ++ i)
        {
            float3 c1 = SAMPLE_TEXTURE2D_X(_MainTex, s_linear_clamp_sampler,uv + float2(+i, 0) * _PostProcessScreenSize.zw).rgb;
            float3 c2 = SAMPLE_TEXTURE2D_X(_MainTex, s_linear_clamp_sampler,uv + float2(-i, 0) * _PostProcessScreenSize.zw).rgb;
            
            float d1 = CalcDistance(c1, c0);
            float d2 = CalcDistance(c2, c0);
            if (d1 < d2)
            {
                sum.rgb += c1;
            }
            else
            {
                sum.rgb += c2;
            }
            sum.a += 1.0f;
        }
        for (int j = 1; j <= _SNNPixelWidth; ++ j)
        {
            for (int i = -_SNNPixelWidth; i <= _SNNPixelWidth; ++ i)
            {
                // float3 c1 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(+i, +j) * _ScreenSize.zw).rgb;
                float3 c1 = SAMPLE_TEXTURE2D_X(_MainTex, s_linear_clamp_sampler,uv + float2(+i, +j) * _PostProcessScreenSize.zw).rgb;
                float3 c2 = SAMPLE_TEXTURE2D_X(_MainTex, s_linear_clamp_sampler,uv + float2(-i, -j) * _PostProcessScreenSize.zw).rgb;
                
                float d1 = CalcDistance(c1, c0);
                float d2 = CalcDistance(c2, c0);
                if(d1 < d2)
                {
                    sum.rgb += c1;
                }
                else
                {
                    sum.rgb += c2;
                }
                sum.a += 1.0f;
            }
        }
        return sum.rgb / sum.a;
    }

    float4 CustomPostProcess(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

        // Note that if HDUtils.DrawFullScreen is not used to render the post process, you don't need to call ClampAndScaleUVForBilinearPostProcessTexture.

        float3 sourceColor = SAMPLE_TEXTURE2D_X(_MainTex, s_linear_clamp_sampler, ClampAndScaleUVForBilinearPostProcessTexture(input.texcoord.xy)).xyz;
        float3 SNNFilterResult = CalcSNN(ClampAndScaleUVForBilinearPostProcessTexture(input.texcoord.xy),sourceColor);
        // Apply greyscale effect
        float3 color = lerp(sourceColor,SNNFilterResult,_SNNIntensity);

        return float4(color, 1);
    }

    ENDHLSL

    SubShader
    {
        Tags{ "RenderPipeline" = "HDRenderPipeline" }
        Pass
        {
            Name "PP_SNNShaper"

            ZWrite Off
            ZTest Always
            Blend Off
            Cull Off

            HLSLPROGRAM
                #pragma fragment CustomPostProcess
                #pragma vertex Vert
            ENDHLSL
        }
    }
    Fallback Off
}
