Shader "ShaderLab/assignment09/VortexSkybox"
{
    Properties
    {
        [HDR] _DeepColor ("Deep Color", Color) = (1, 1, 1, 1)
        [HDR] _HighColor ("High Color", Color) = (1, 1, 1, 1)
        [HDR] _RibbonColor ("Ribbon Color", Color) = (1, 1, 1, 1)
        [HDR] _AccentColor ("Accent Color", Color) = (1, 1, 1, 1)
        _SwirlStrength ("Swirl Strength", Range(0, 2)) = 1.2
        _Speed ("Animation Speed", Range(0, 3)) = 0.6
        _Exposure ("Environment Brightness", Range(0, 3)) = 1.0
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Background"
            "RenderType" = "Background"
            "PreviewType" = "Skybox"
        }
        Cull Off
        ZWrite Off

        Pass
        {
            Name "AnimatedSky"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma target 3.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #ifndef RETRO_COSMIC_SKY_COMMON_INCLUDED
            #include "RetroSkyCommon.hlsl"
            #endif


            CBUFFER_START(UnityPerMaterial)
            float4 _DeepColor;
            float4 _HighColor;
            float4 _RibbonColor;
            float4 _AccentColor;
            float _SwirlStrength;
            float _Speed;
            float _Exposure;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 directionWS : TEXCOORD0;
            };

            Varyings Vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.directionWS = IN.positionOS.xyz;
                return OUT;
            }

            half4 Frag(Varyings IN) : SV_Target
            {
                float3 color = RetroSkyColor(
                    IN.directionWS, 
                    _Time.y,
                    _DeepColor.rgb, 
                    _HighColor.rgb,
                    _RibbonColor.rgb, 
                    _AccentColor.rgb,
                    _SwirlStrength, 
                    _Speed, 
                    _Exposure);
                return half4(color, 1.0);
            }
            ENDHLSL
        }
    }
    FallBack Off
}
