Shader "ShaderLab/assignment09/MirrorChrome"
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
        [HDR] _MetalTint ("Chrome Reflectance (F0)", Color) = (0.94, 0.96, 0.99, 1)
        _ReflectionStrength ("Reflection Brightness", Range(0, 2)) = 1.0
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }
        Pass
        {
            Name "MirrorChrome"
            Tags { "LightMode" = "UniversalForward" }
            Cull Back
            ZWrite On
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
            float4 _MetalTint;
            float _ReflectionStrength;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
            };

            Varyings Vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                return OUT;
            }

            half4 Frag(Varyings IN) : SV_Target
            {
                float3 N = normalize(IN.normalWS);
                float3 V = normalize(GetCameraPositionWS() - IN.positionWS);
                float3 R = reflect(-V, N);

                float3 skyReflection = RetroSkyColor(
                    R, 
                    _Time.y,
                    _DeepColor.rgb, 
                    _HighColor.rgb,
                    _RibbonColor.rgb, 
                    _AccentColor.rgb,
                    _SwirlStrength, 
                    _Speed, 
                    _Exposure);

                float nv = saturate(dot(N, V));
                float grazing = pow(1.0 - nv, 5.0);
                float3 F0 = saturate(_MetalTint.rgb);
                float3 F = F0 + (1.0 - F0) * grazing;

                float3 color = skyReflection * F * _ReflectionStrength;
                return half4(color, 1.0);
            }
            ENDHLSL
        }
    }
    FallBack Off
}
