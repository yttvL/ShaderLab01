Shader "ShaderLab/assignment06/Jellyfish"
{
    Properties
    {
        [Header(Bell Animation)]
        _BellRadius ("Bell Radius - Match CSharp", Float) = 1.0
        _PulseSpeed ("Pulse Speed", Range(0, 8)) = 2.4
        _PulseAmount ("Pulse Inward Amount", Range(0, 0.6)) = 0.22
        _PulseFalloff ("Pulse Edge Weight Power", Range(0.5, 6)) = 1.8
        _BellLift ("Bell Rim Lift", Range(-0.3, 0.3)) = 0.08

        [Header(Tentacle Animation)]
        _TentacleAmplitude ("Tentacle Wave Amplitude", Range(0, 0.6)) = 0.20
        _TentacleFrequency ("Tentacle Wave Frequency", Range(0, 24)) = 9.0
        _TentacleSpeed ("Tentacle Wave Speed", Range(0, 12)) = 3.1
        _TentacleSideAmplitude ("Secondary Wave Amplitude", Range(0, 0.4)) = 0.085

        [Header(Oral Arm Animation)]
        _ArmAmplitude ("Oral Arm Amplitude", Range(0, 0.4)) = 0.12
        _ArmFrequency ("Oral Arm Frequency", Range(0, 20)) = 7.0
        _ArmSpeed ("Oral Arm Speed", Range(0, 12)) = 1.8

        [Header(Whole Body)]
        _BobAmplitude ("Vertical Bob", Range(0, 0.3)) = 0.06
        _BobSpeed ("Vertical Bob Speed", Range(0, 8)) = 1.1

        [Header(Colors)]
        _BellColor ("Bell Body", Color) = (1, 1, 1, 1)
        _BellEdgeColor ("Bell Edge", Color) = (1, 1, 1, 1)
        _TentacleColor ("Tentacle Root", Color) = (1, 1, 1, 1)
        _TentacleTipColor ("Tentacle Tip", Color) = (1, 1, 1, 1)
        _OralArmColor ("Oral Arms", Color) = (1, 1, 1, 1)
        _GlowColor ("Fresnel Glow", Color) = (1, 1, 1, 1)

        [Header(Shading)]
        _FresnelPower ("Fresnel Power", Range(0.5, 8)) = 3.0
        _FresnelStrength ("Fresnel Strength", Range(0, 4)) = 1.25
        _GlowIntensity ("Glow Intensity", Range(0, 5)) = 0.65
        _FakeLightStrength ("Fake Light Strength", Range(0, 1)) = 0.25
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
            "RenderType" = "Opaque"
        }

        Pass
        {
            Name "JellyfishUnlit"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            Cull Off   
            ZWrite On 
            ZTest LEqual

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #define JELLY_PI 3.14159265359
            #define JELLY_TAU 6.28318530718

            CBUFFER_START(UnityPerMaterial)
                float _BellRadius;
                float _PulseSpeed;
                float _PulseAmount;
                float _PulseFalloff;
                float _BellLift;

                float _TentacleAmplitude;
                float _TentacleFrequency;
                float _TentacleSpeed;
                float _TentacleSideAmplitude;

                float _ArmAmplitude;
                float _ArmFrequency;
                float _ArmSpeed;

                float _BobAmplitude;
                float _BobSpeed;

                float4 _BellColor;
                float4 _BellEdgeColor;
                float4 _TentacleColor;
                float4 _TentacleTipColor;
                float4 _OralArmColor;
                float4 _GlowColor;

                float _FresnelPower;
                float _FresnelStrength;
                float _GlowIntensity;
                float _FakeLightStrength;
            CBUFFER_END

            // uv0.x: bell radial u / 0 (root) - 1 (tip)
            // uv0.y: bell v / appendage angular phase
            // color.r: bell = 0, oral arm = 0.5, tentacle = 1
            // color.g: angular coordinate normalized 0-1
            // color.b: tentacle root radius normalized by bellRadius
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float2 uv : TEXCOORD2;
                float  partID : TEXCOORD3;
            };

            float PulseWeight(float u)
            {
                return pow(saturate(u), _PulseFalloff);
            }

            Varyings vert(Attributes v)
            {
                Varyings o;
                float3 p = v.positionOS.xyz;
                float time = _Time.y;

                // 0 = relaxed, 1 = contracted
                float pulse = 0.5 + 0.5 * sin(time * _PulseSpeed);

                //BELL
                if (v.color.r < 0.25)
                {
                    float weight = PulseWeight(v.uv.x);
                    
                    //shrink
                    p.xz *= 1.0 - (_PulseAmount * pulse * weight);
                    p.y += _BellLift * pulse * weight;
                }

                //TENTACLE
                else if (v.color.r > 0.75)
                {
                    float s = saturate(v.uv.x);  // root = 0, tip = 1
                    float angle = JELLY_TAU * v.color.g;
                    float2 radial = float2(cos(angle), sin(angle));
                    float2 tangent = float2(-radial.y, radial.x);

                    float rootRadius01 = saturate(v.color.b);
                    float rootU = (2.0 / JELLY_PI) * asin(min(rootRadius01, 0.999));
                    float rootWeight = PulseWeight(rootU);

                    // keep the strand's attachment in sync with its bell point
                    float rootShrink = _BellRadius * rootRadius01 * _PulseAmount * pulse * rootWeight;
                    p.xz -= radial * rootShrink;
                    p.y += _BellLift * pulse * rootWeight;

                    float tipWeight = s * s;
                    float phase = angle;
                    float traveling = s * _TentacleFrequency - time * _TentacleSpeed + phase;
                    float sideWave = s * (_TentacleFrequency * 0.7) - time * (_TentacleSpeed * 0.73) + phase * 1.37;

                    p.xz += radial * (sin(traveling) * _TentacleAmplitude * tipWeight);
                    p.xz += tangent * (sin(sideWave) * _TentacleSideAmplitude * tipWeight);
                }

                //ORAL ARMS
                else
                {
                    float s = saturate(v.uv.x);
                    float angle = JELLY_TAU * v.color.g;
                    float2 radial = float2(cos(angle), sin(angle));
                    float2 tangent = float2(-radial.y, radial.x);
                    float weight = s * s;
                    float w = sin(s * _ArmFrequency - time * _ArmSpeed + angle);
                    p.xz += tangent * (w * _ArmAmplitude * weight);
                    p.xz += radial * (cos(s * _ArmFrequency * 0.65 - time * _ArmSpeed * 0.8 + angle) * _ArmAmplitude * 0.3 * weight);
                }

                //whole-body motion
                p.y += sin(time * _BobSpeed) * _BobAmplitude;

                o.positionWS = TransformObjectToWorld(p);
                o.positionCS = TransformWorldToHClip(o.positionWS);
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.uv = v.uv;
                o.partID = v.color.r;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float3 normalWS = normalize(i.normalWS);
                float3 viewDirWS = normalize(_WorldSpaceCameraPos.xyz - i.positionWS);

                // lighting
                // abs gives a symmetric rim on the two sides of surfaces
                float ndv = saturate(abs(dot(normalWS, viewDirWS)));
                float fresnel = pow(1.0 - ndv, _FresnelPower);

                float3 baseColor;
                float glowMask;

                //BELL
                if (i.partID < 0.25)
                {
                    float rim = smoothstep(0.58, 1.0, i.uv.x);
                    baseColor = lerp(_BellColor.rgb, _BellEdgeColor.rgb, rim * 0.75);
                    glowMask = fresnel * _FresnelStrength + rim * 0.15;
                }

                //TENTACCLE
                else if (i.partID > 0.75)
                {
                    float tip = saturate(i.uv.x);
                    baseColor = lerp(_TentacleColor.rgb, _TentacleTipColor.rgb, tip * 0.85);
                    glowMask = fresnel * _FresnelStrength * 0.45 + tip * 0.18;
                }

                //ORAL ARMS
                else
                {
                    baseColor = _OralArmColor.rgb;
                    glowMask = fresnel * _FresnelStrength * 0.7;
                }

                float3 fakeSun = normalize(float3(-0.3, 0.8, 0.5));
                float halfLambert = 0.5 + 0.5 * dot(normalWS, fakeSun);
                float shade = lerp(1.0, 0.65 + 0.35 * halfLambert, _FakeLightStrength);

                float3 color = baseColor * shade;
                color += _GlowColor.rgb * glowMask * _GlowIntensity;
                return half4(color, 1.0);
            }
            ENDHLSL
        }
    }

    FallBack Off
}
