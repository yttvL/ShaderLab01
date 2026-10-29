Shader "ShaderLab/assignment08/GerstnerWave01"
{
    Properties
    {
        [Header(Debug)]
        [Enum(Final,0,WaterDepth,1,ShoreMask,2,FinalFoam,3,Refraction,4,Caustics,5,Sparkle,6)]
        _DebugView ("Debug View", Float) = 0

        [Header(Base Water)]
        _ShallowColor ("Shallow Color", Color) = (0.08, 0.48, 0.42, 1)
        _DeepColor ("Deep Color", Color) = (0.015, 0.12, 0.14, 1)
        _DepthRange ("Depth Color Range", Float) = 2.5
        _TintStrength ("Water Tint Strength", Range(0,1)) = 0.72
        _BaseAlpha ("Base Alpha", Range(0,1)) = 0.58
        _DepthOpacity ("Depth Opacity Boost", Range(0,1)) = 0.22

        [Header(Gerstner Waves)]
        _WaveA ("Wave A (XY Dir, Z Steepness, W Wavelength)", Vector) = (1, 0, 0.10, 5.5)
        _WaveASpeed ("Wave A Speed", Float) = 0.8
        _WaveB ("Wave B (XY Dir, Z Steepness, W Wavelength)", Vector) = (0.45, 1, 0.065, 2.7)
        _WaveBSpeed ("Wave B Speed", Float) = 1.15
        _WaveHeightScale ("Wave Scale", Range(0,2)) = 1.0

        [Header(Surface Normals)]
        [NoScaleOffset] _NormalMap ("Water Normal", 2D) = "bump" {}
        _NormalTilingA ("Normal Tiling A", Float) = 0.8
        _NormalTilingB ("Normal Tiling B", Float) = 1.35
        _NormalSpeedA ("Normal Speed A", Vector) = (0.035, 0.018, 0, 0)
        _NormalSpeedB ("Normal Speed B", Vector) = (-0.025, 0.032, 0, 0)
        _NormalStrengthA ("Normal Strength A", Range(0,2)) = 0.9
        _NormalStrengthB ("Normal Strength B", Range(0,2)) = 0.75
        _SmallNormalInfluence ("Small Normal Influence", Range(0,1)) = 0.72

        [Header(Refraction)]
        _RefractionStrength ("Refraction Strength", Range(0,0.15)) = 0.055
        _RefractionEdgeFade ("Screen Edge Fade", Range(0.001,0.1)) = 0.025

        [Header(Shore Foam)]
        [NoScaleOffset] _FoamNoiseTex ("Foam Mask Texture", 2D) = "white" {}
        _FoamColor ("Foam Color", Color) = (1,1,1,1)
        _FoamDepthRange ("Shoreline Depth Width", Range(0.001,1)) = 0.10
        _FoamTiling ("Foam Mask Tiling", Float) = 1.0
        _FoamSpeed ("Foam Mask Speed", Vector) = (0.025,0.015,0,0)
        _FoamCutoff ("Foam Mask Cutoff", Range(0,1)) = 0.52
        _FoamSoftness ("Foam Mask Softness", Range(0.001,0.4)) = 0.10
        _FoamIntensity ("Foam Intensity", Range(0,1)) = 1.0

        [Header(Caustics)]
        [NoScaleOffset] _CausticsTex ("Caustics Texture", 2D) = "black" {}
        _CausticsTiling ("Caustics Tiling", Float) = 0.32
        _CausticsLayer2Scale ("Caustics Layer 2 Scale", Float) = 1.31
        _CausticsSpeed1 ("Caustics Speed 1", Vector) = (0.030,0.018,0,0)
        _CausticsSpeed2 ("Caustics Speed 2", Vector) = (-0.020,0.027,0,0)
        _CausticsIntensity ("Caustics Intensity", Range(0,3)) = 0.85
        _CausticsDispersion ("RGB Dispersion", Range(0,0.05)) = 0.007
        _CausticsColor ("Caustics Tint", Color) = (0.88,1.0,0.97,1)
        _CausticsDepthRange ("Caustics Depth Range", Float) = 2.2

        [Header(Fresnel)]
        _FresnelColor ("Fresnel Color", Color) = (0.10,0.58,0.58,1)
        _FresnelPower ("Fresnel Power", Range(0.2,10)) = 4.0
        _FresnelIntensity ("Fresnel Intensity", Range(0,2)) = 0.35

        [Header(Main Specular)]
        _SpecularColor ("Specular Color", Color) = (0.92,1.0,0.98,1)
        _SpecularPower ("Specular Power", Range(1,256)) = 72
        _SpecularIntensity ("Specular Intensity", Range(0,5)) = 1.25

        [Header(Sparkle)]
        [HDR] _SparkleColor ("Sparkle Color", Color) = (1.4,1.4,1.25,1)
        _SparkleIntensity ("Sparkle Intensity", Range(0,6)) = 1.5
        _SparklePhaseOffset ("Sparkle Phase Offset", Range(-3.14,3.14)) = 0.6
        _SparkleSharpness ("Crest Sharpness", Range(1,32)) = 12
        _SparkleBreakupTiling ("Breakup Tiling", Range(0.1,10)) = 3.0
        _SparkleBreakupCutoff ("Breakup Cutoff", Range(0,1)) = 0.48
        _SparkleWarp ("Breakup Warp", Range(0,6)) = 2.0
        _SparkleLightInfluence ("Light Influence", Range(0,1)) = 0.4
        _SparkleViewInfluence ("View Influence", Range(0,1)) = 0.15
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "Queue"="Transparent"
            "RenderType"="Transparent"
        }

        Pass
        {
            Name "ForwardWater"
            Tags { "LightMode"="UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            ZTest LEqual
            Cull Back

            HLSLPROGRAM
            #pragma target 4.0
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            TEXTURE2D(_NormalMap);
            TEXTURE2D(_FoamNoiseTex);
            TEXTURE2D(_CausticsTex); 
            SAMPLER(sampler_NormalMap);
            SAMPLER(sampler_FoamNoiseTex);
            SAMPLER(sampler_CausticsTex);

            CBUFFER_START(UnityPerMaterial)
                float _DebugView;
                float4 _ShallowColor, _DeepColor;
                float _DepthRange, _TintStrength, _BaseAlpha, _DepthOpacity;

                float4 _WaveA, _WaveB;
                float _WaveASpeed, _WaveBSpeed, _WaveHeightScale;

                float _NormalTilingA, _NormalTilingB;
                float4 _NormalSpeedA, _NormalSpeedB;
                float _NormalStrengthA, _NormalStrengthB, _SmallNormalInfluence;

                float _RefractionStrength, _RefractionEdgeFade;

                float4 _FoamColor;
                float _FoamDepthRange, _FoamTiling;
                float4 _FoamSpeed;
                float _FoamCutoff, _FoamSoftness, _FoamIntensity;

                float _CausticsTiling, _CausticsLayer2Scale;
                float4 _CausticsSpeed1, _CausticsSpeed2;
                float _CausticsIntensity, _CausticsDispersion;
                float4 _CausticsColor;
                float _CausticsDepthRange;

                float4 _FresnelColor;
                float _FresnelPower, _FresnelIntensity;

                float4 _SpecularColor;
                float _SpecularPower, _SpecularIntensity;

                float4 _SparkleColor;
                float _SparkleIntensity, _SparklePhaseOffset, _SparkleSharpness;
                float _SparkleBreakupTiling, _SparkleBreakupCutoff, _SparkleWarp;
                float _SparkleLightInfluence, _SparkleViewInfluence;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float2 uv : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 tangentWS : TEXCOORD3;
                float waterEyeDepth : TEXCOORD4;
            };

            float3 SafeNormalize(float3 v, float3 fallback)
            {
                float l2 = dot(v,v);
                return l2 > 1e-10 ? v * rsqrt(l2) : fallback;
            }

            float2 SafeNormalize2(float2 v, float2 fallback)
            {
                float l2 = dot(v,v);
                return l2 > 1e-10 ? v * rsqrt(l2) : fallback;
            }

            float3 GerstnerWave(float3 p, float4 wave, float speed, inout float3 T, inout float3 B)
            {
                float dirLen = length(wave.xy);
                if (dirLen < 1e-5 || abs(wave.w) < 1e-4) return 0;
                
                //normalize dir
                float2 d = wave.xy / dirLen;
                //smaller wavelength = higher frequency = bigger k
                float k = TWO_PI / max(abs(wave.w),0.01);
                //Gerstner steepness fold safe gate
                float s = clamp(wave.z * _WaveHeightScale,-0.95,0.95);
                //amplitude
                float a = s / k;

                float phase = TWO_PI * frac(k * (dot(d, p.xz) - speed * _Time.y) / TWO_PI);
                float sn, cs;
                sincos(phase, sn, cs);

                T += float3(-d.x * d.x * s * sn, d.x * s * cs, -d.x * d.y * s * sn);
                B += float3(-d.x * d.y * s * sn, d.y * s * cs, -d.y * d.y * s * sn);

                return float3(d.x * a * cs, a * sn, d.y * a * cs);
            }

            //add normal helper
            float3 BlendNormalsRNM(float3 n1, float3 n2)
            {
                float3 t = n1 + float3(0,0,1);
                float3 u = n2 * float3(-1,-1,1);
                return SafeNormalize(t * dot(t,u) / max(t.z,0.001) - u, float3(0,0,1));
            }

            float SceneEyeDepthAt(float2 uv)
            {
                return LinearEyeDepth(SampleSceneDepth(uv), _ZBufferParams);
            }

            //refraction out of screen safety check
            float2 ValidateRefractionUV(float2 uv, float2 fallbackUV, float waterEyeDepth)
            {
                if (any(uv < 0.0) || any(uv > 1.0)) return fallbackUV;
                if (SceneEyeDepthAt(uv) < waterEyeDepth + 0.001) return fallbackUV;
                return uv;
            }

            float CrestSparkle(float2 posXZ, float4 wave, float speed, float timeScale, float phaseOffset)
            {
                //wave dir
                float2 dir = SafeNormalize2(wave.xy, float2(1,0));
                float2 crestTangent = float2(-dir.y, dir.x);
                float k = TWO_PI / max(abs(wave.w), 0.01);

                //sparkle follow Gerstener
                float phase = k * (dot(posXZ, dir) - speed * _Time.y * timeScale) + phaseOffset;

                //remap 01 and sharpen band
                float crest = pow(saturate(0.5 + 0.5 * sin(phase)), max(_SparkleSharpness,1.0));

                float2 breakupUV = float2(dot(posXZ, crestTangent), dot(posXZ, dir) * 0.2)
                                 * _SparkleBreakupTiling
                                 + float2(0.07, -0.04) * (_Time.y * timeScale);

                float n1 = SAMPLE_TEXTURE2D(_FoamNoiseTex, sampler_FoamNoiseTex, breakupUV).r;
                float n2 = SAMPLE_TEXTURE2D(_FoamNoiseTex, sampler_FoamNoiseTex, float2(-breakupUV.y, breakupUV.x) * 1.23 + float2(-0.11, 0.05) * (_Time.y * timeScale)).r;

                float breakup = smoothstep(_SparkleBreakupCutoff, 1.0, saturate(n1 * n2 * 1.8));
                float warp = 0.5 + 0.5 * sin(phase + (n1 - 0.5) * _SparkleWarp);

                return crest * breakup * warp;
            }

            Varyings vert(Attributes v)
            {
                Varyings o;
                float3 p = TransformObjectToWorld(v.positionOS.xyz);
                float3 T = float3(1,0,0);
                float3 B = float3(0,0,1);

                //apply gerstner waves
                p += GerstnerWave(p,_WaveA,_WaveASpeed,T,B);
                p += GerstnerWave(p,_WaveB,_WaveBSpeed,T,B);

                float3 N = SafeNormalize(cross(B,T), float3(0,1,0));
                T = SafeNormalize(T - N * dot(T,N), float3(1,0,0));

                o.positionWS = p;
                o.normalWS = N;
                o.tangentWS = T;
                o.uv = v.uv;
                o.positionCS = TransformWorldToHClip(p);
                o.waterEyeDepth = -TransformWorldToView(p).z;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float2 screenUV = GetNormalizedScreenSpaceUV(i.positionCS);

                float rawSceneDepth = SampleSceneDepth(screenUV);
                float sceneEyeDepth = LinearEyeDepth(rawSceneDepth, _ZBufferParams);
                float waterDepth = max(0.0, sceneEyeDepth - i.waterEyeDepth);
                float depth01 = saturate(waterDepth / max(_DepthRange, 0.0001));

                //gerstner normal
                float3 geoN = SafeNormalize(i.normalWS, float3(0, 1, 0));
                float3 T = SafeNormalize(i.tangentWS - geoN * dot(i.tangentWS, geoN), float3(1, 0, 0));
                float3 B = SafeNormalize(cross(T, geoN), float3(0, 0, 1));

                //sample detail normal tex
                float2 uvA = i.uv * _NormalTilingA + _NormalSpeedA.xy * _Time.y;
                //rotate and sample same normal tex
                float2 uvB = float2(-i.uv.y, i.uv.x) * _NormalTilingB + _NormalSpeedB.xy * _Time.y;

                float3 nA = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uvA), _NormalStrengthA);
                float3 nB = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uvB), _NormalStrengthB);
                //retrieve rotate
                nB.xy = float2(nB.y, -nB.x);

                float3 nTS = BlendNormalsRNM(nA, nB);
                //world space normal with detail normal tex
                float3 detailN = SafeNormalize(nTS.x * T + nTS.y * B + nTS.z * geoN, geoN);
                //blend gerstner and detail normal
                float3 N = SafeNormalize(lerp(geoN, detailN, saturate(_SmallNormalInfluence)), geoN);

                float3 V = GetWorldSpaceNormalizeViewDir(i.positionWS);
                Light mainLight = GetMainLight(TransformWorldToShadowCoord(i.positionWS));
                float3 L = SafeNormalize(mainLight.direction, float3(0, 1, 0));
                float3 H = SafeNormalize(L + V, N);
                float3 radiance = mainLight.color * mainLight.distanceAttenuation * mainLight.shadowAttenuation;
                float ndh = saturate(dot(N,H));
                float ndv = saturate(dot(N,V));

                float fresnel = pow(max(1.0 - ndv, 0.0), max(_FresnelPower, 0.01));
                //fresnel col
                float3 fresnelTerm = _FresnelColor.rgb * fresnel * _FresnelIntensity;

                //gerstner does not affect refraction
                float3 refractionNVS = mul((float3x3)UNITY_MATRIX_V, N - geoN);
                float2 refractOffset = refractionNVS.xy * _RefractionStrength;
                //safe gate refraction
                float edge = min(min(screenUV.x, screenUV.y), min(1.0 - screenUV.x, 1.0 - screenUV.y));
                refractOffset *= smoothstep(0.0, max(_RefractionEdgeFade, 0.0001), edge);
                float2 refractUV = ValidateRefractionUV(screenUV + refractOffset, screenUV, i.waterEyeDepth);

                float3 refractedScene = SampleSceneColor(refractUV);

                float3 waterTint = lerp(_ShallowColor.rgb, _DeepColor.rgb, depth01);
                float3 waterColor = lerp(refractedScene, refractedScene * waterTint, saturate(_TintStrength));

                float shoreMask = 1.0 - smoothstep(0.0, max(_FoamDepthRange,0.0001), waterDepth);
                float2 foamUV = i.positionWS.xz * _FoamTiling + _FoamSpeed.xy * _Time.y;
                float foamTex = SAMPLE_TEXTURE2D(_FoamNoiseTex, sampler_FoamNoiseTex, foamUV).r;
                float foamTexMask = smoothstep(_FoamCutoff - _FoamSoftness, _FoamCutoff + _FoamSoftness, foamTex);
                float foam = saturate(shoreMask * foamTexMask * _FoamIntensity);

                float rawBottomDepth = SampleSceneDepth(refractUV);
                float bottomEyeDepth = LinearEyeDepth(rawBottomDepth, _ZBufferParams);
                float causticWaterDepth = max(0.0, bottomEyeDepth - i.waterEyeDepth);
                float3 bottomWS = ComputeWorldSpacePosition(refractUV, rawBottomDepth, UNITY_MATRIX_I_VP);

                //caustic rgb split follows refraction offset
                float2 cDir = SafeNormalize2(refractOffset, float2(1, 0));
                float2 cOff = cDir * _CausticsDispersion;
                float2 cUV1 = bottomWS.xz * _CausticsTiling + _CausticsSpeed1.xy * _Time.y;
                float2 cUV2 = bottomWS.xz * (_CausticsTiling * max(_CausticsLayer2Scale, 0.01)) + _CausticsSpeed2.xy * _Time.y;

                float cR = SAMPLE_TEXTURE2D(_CausticsTex,sampler_CausticsTex, cUV1 + cOff).r;
                float cG = SAMPLE_TEXTURE2D(_CausticsTex,sampler_CausticsTex, cUV1).r;
                float cB = SAMPLE_TEXTURE2D(_CausticsTex,sampler_CausticsTex, cUV1 - cOff).r;
                float c2 = SAMPLE_TEXTURE2D(_CausticsTex,sampler_CausticsTex, cUV2).r;

                //fade on water depth
                float causticFade = 1.0 - smoothstep(0.0, max(_CausticsDepthRange, 0.0001), causticWaterDepth);
                //get intersection
                float3 caustics = min(float3(cR, cG, cB), c2.xxx) * _CausticsColor.rgb * _CausticsIntensity * causticFade;

                float specSignal = pow(ndh, max(_SpecularPower,1.0));
                float3 specular = specSignal * _SpecularColor.rgb * _SpecularIntensity * radiance;

                //stylized sparkle on wave crest
                float sA = CrestSparkle(i.positionWS.xz, _WaveA, _WaveASpeed, 1.0, _SparklePhaseOffset);
                float sB = CrestSparkle(i.positionWS.xz, _WaveB, _WaveBSpeed, 0.93, _SparklePhaseOffset * 0.75);
                float sparkleSignal = saturate(sA + sB);
                float sparkleAA = max(fwidth(sparkleSignal), 0.004);
                float sparkleMask = smoothstep(0.25 - sparkleAA, 0.85 + sparkleAA, sparkleSignal);

                //light and view influence
                float broadLightMask = lerp(1.0, lerp(0.35, 1.0, pow(ndh,2.0)), saturate(_SparkleLightInfluence));
                float broadViewMask = lerp(1.0, lerp(0.35, 1.0, fresnel), saturate(_SparkleViewInfluence));
                float3 sparkle = _SparkleColor.rgb * sparkleMask * _SparkleIntensity * broadLightMask * broadViewMask;

                if (_DebugView > 0.5 && _DebugView < 1.5) return half4(depth01.xxx, 1);
                if (_DebugView > 1.5 && _DebugView < 2.5) return half4(shoreMask.xxx, 1);
                if (_DebugView > 2.5 && _DebugView < 3.5) return half4(foam.xxx, 1);
                if (_DebugView > 3.5 && _DebugView < 4.5) return half4(refractedScene, 1);
                if (_DebugView > 4.5 && _DebugView < 5.5) return half4(saturate(caustics), 1);
                if (_DebugView > 5.5 && _DebugView < 6.5) return half4(sparkleMask.xxx, 1);

                float3 finalColor = waterColor + fresnelTerm + caustics + specular + sparkle;
                finalColor = lerp(finalColor, _FoamColor.rgb, saturate(foam * _FoamColor.a));

                float alpha = saturate(_BaseAlpha + depth01 * _DepthOpacity + foam * 0.15);
                return half4(max(finalColor, 0), alpha);
            }
            ENDHLSL
        }
    }
}
