Shader "shader lab/assignment 1/sunset01" {
    Properties {
        [Header(Sky)]
        _SkyTopColor ("SkyTopColor", Color) = (1, 1, 1, 1)
        _SkyBottomColor ("SkyBottomColor", Color) = (1, 1, 1, 1)
        _SkyBlendWidth ("SkyBlendWidth", Range(0.05, 1.0)) = 1


        [Header(Sun)]
        _SunPosition ("SunPosition XY", Vector) = (0, 0, 0, 0)
        _SunRadius ("SunRadius", Range(0.01, 0.30)) = 0.1
        _SunHorizontalStretch ("SunHorizontalStretch", Range(0.25, 4.0)) = 1
        _SunSoftness ("SunSoftness", Range(0.001, 0.10)) = 0.01
        [HDR] _SunColor ("SunColor", Color) = (1, 1, 1, 1)
        _SunCoreIntensity ("SunCoreIntensity", Range(0.0, 5.0)) = 1


        [Header(Cloud Shape)]
        _CloudScale ("CloudScale", Range(0.5, 12.0)) = 1
        _CloudLength ("CloudLength", Range(0.5, 10.0)) = 1
        _CloudFlatness ("CloudFlatness", Range(0.5, 6.0)) = 1
        _CloudThreshold ("CloudThreshold", Range(0.0, 1.0)) = 0.50
        _CloudNearSoftness ("CloudNearSoftness", Range(0.001, 0.25)) = 0.1
        _CloudFarSoftness ("CloudFarSoftness", Range(0.001, 0.35)) = 0.1
        _CloudColor ("CloudColor", Color) = (1, 1, 1, 1)
        _CloudNoiseOffset ("CloudNoiseOffset XY", Vector) = (0, 0, 0, 0)
        _CloudDetailOffset ("CloudDetailOffset XY", Vector) = (0, 0, 0, 0)


        [Header(Cloud Distance Dissolve)]
        _CloudFadeStart ("CloudFadeStart", Range(0.0, 1.5)) = 0.1
        _CloudFadeRange ("CloudFadeRange", Range(0.05, 1.5)) = 1
        _CloudFadeStrength ("CloudFadeStrength", Range(0.0, 1.0)) = 0.1
        _CloudDissolveNoiseScale ("CloudDissolveNoiseScale", Range(0.5, 30)) = 1
        _CloudDissolveStretchX ("CloudDissolveStretchX", Range(0.5, 20)) = 1
        _CloudDissolveMix ("CloudDissolveMix", Range(0.0, 1.0)) = 0.72
        _CloudDissolveOffset ("CloudDissolveOffset XY", Vector) = (0, 0, 0, 0)
        _CloudDissolveDetailOffset ("CloudDissolveDetailOffset XY", Vector) = (0, 0, 0, 0)

        [Header(Cloud Rim)]
        [HDR] _CloudRimColor ("CloudRimColor", Color) = (1, 1, 1, 1)
        _CloudRimWidth ("CloudRimWidth", Range(0.0005, 0.03)) = 0.01
        _CloudRimSoftness ("CloudRimSoftness", Range(0.001, 0.30)) = 0.1
        _CloudRimIntensity ("CloudRimIntensity", Range(0.0, 6.0)) = 1


        [Header(Ground Horizon)]
        _HorizonHeight ("HorizonHeight", Range(0.02, 0.50)) = 0.1
        _MountainWidth ("MountainWidth", Range(0.25, 5.0)) = 1
        _MountainAmplitude ("MountainAmplitude", Range(0.0, 1)) = 0.3
        _HorizonSoftness ("HorizonSoftness", Range(0.0005, 0.08)) = 0.001
        _MountainNoiseOffset ("MountainNoiseOffset", Float) = 1
        _GroundColor ("GroundColor", Color) = (1, 1, 1, 1)
    }

    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }

        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct MeshData {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Interpolators vert(MeshData v) {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }

            CBUFFER_START(UnityPerMaterial)
                float4 _SkyTopColor;
                float4 _SkyBottomColor;
                float _SkyBlendWidth;

                float4 _SunPosition;
                float _SunRadius;
                float _SunHorizontalStretch;
                float _SunSoftness;
                float4 _SunColor;
                float _SunCoreIntensity;
                float4 _SunHaloColor;
                float _SunHaloWidth;
                float _SunHaloStrength;

                float _CloudScale;
                float _CloudLength;
                float _CloudFlatness;
                float _CloudThreshold;
                float _CloudNearSoftness;
                float _CloudFarSoftness;
                float4 _CloudColor;
                float4 _CloudNoiseOffset;
                float4 _CloudDetailOffset;

                float _CloudFadeStart;
                float _CloudFadeRange;
                float _CloudFadeStrength;
                float _CloudDissolveNoiseScale;
                float _CloudDissolveStretchX;
                float _CloudDissolveMix;
                float4 _CloudDissolveOffset;
                float4 _CloudDissolveDetailOffset;

                float4 _CloudRimColor;
                float _CloudRimWidth;
                float _CloudRimSoftness;
                float _CloudRimIntensity;

                float _HorizonHeight;
                float _MountainWidth;
                float _MountainAmplitude;
                float _HorizonSoftness;
                float _MountainNoiseOffset;
                float4 _GroundColor;
            CBUFFER_END

            
            //float2 pos to random float01 
            float Hash21(float2 p) {
                p = frac(p * float2(999.99, 888.88));
                p += dot(p, p + 11.11);
                return frac(p.x * p.y);
            }

            //pos to curved noise
            // generate continuous field with four corners of random float
            float ValueNoise(float2 p) {
                float2 id = floor(p);
                float2 local = frac(p);
                float2 u = local * local * (3.0 - 2.0 * local);

                float a = Hash21(id + float2(0.0, 0.0));
                float b = Hash21(id + float2(1.0, 0.0));
                float c = Hash21(id + float2(0.0, 1.0));
                float d = Hash21(id + float2(1.0, 1.0));

                return lerp(
                    lerp(a, b, u.x),
                    lerp(c, d, u.x),
                    u.y
                );
            }

            float FBM5(float2 p) {
                float value = 0.0;
                float amplitude = 0.5;
                float amplitudeSum = 0.0;

                [unroll]
                for (int octave = 0; octave < 5; octave++) {
                    value += ValueNoise(p) * amplitude;
                    amplitudeSum += amplitude;
                    p = p * 2.03 + float2(17.13, 9.27);
                    amplitude *= 0.5;
                }

                return value / max(amplitudeSum, 0.0001);
            }

            //basic sky gradient
            float3 GetSky(float2 uv) {
                float halfWidth = max(_SkyBlendWidth * 0.5, 0.0001);

                //gradient center above sun
                float gradientCenter = _SunPosition.y + 0.07;

                float t = smoothstep(
                    gradientCenter - halfWidth,
                    gradientCenter + halfWidth,
                    uv.y
                );

                return lerp(
                    _SkyBottomColor.rgb,
                    _SkyTopColor.rgb,
                    t
                );
            }

            //returns distance to sun center
            float GetCloudSunDistance(float2 uv) {
                float2 delta = uv - _SunPosition.xy;
                //cloud distance mask proportional to sun stretch
                delta.x /= max(_SunHorizontalStretch, 0.001);
                return length(delta);
            }

            float3 ApplySun(float2 uv, float3 skyColor) {
                float d = GetCloudSunDistance(uv);

                float coreMask = 1.0 - smoothstep(
                    max(_SunRadius - _SunSoftness, 0.0),
                    _SunRadius + _SunSoftness,
                    d
                );

                float3 color = lerp(skyColor, _SunColor.rgb * _SunCoreIntensity, coreMask);
                return color;
            }

            //cloud macro shape stretched
            float2 GetCloudUV(float2 uv) {
                float2 p = uv - 0.5;
                p.x *= _ScreenParams.x / max(_ScreenParams.y, 1.0);

                p.x *= _CloudScale / max(_CloudLength, 0.001);
                p.y *= _CloudScale * _CloudFlatness;
                return p;
            }

            //cloud density pattern
            float GetCloudField(float2 uv) {
                float2 p = GetCloudUV(uv);

                float largeShape = FBM5(p + _CloudNoiseOffset.xy);
                float detailShape = FBM5(
                    p * 2.15 + _CloudDetailOffset.xy
                );

                //blend two layers of noise
                return saturate(largeShape * 0.78 + detailShape * 0.22);
            }

            //////////
            //cloud fading effect controlled by distance to sun
            float GetFarAmount(float2 uv) {
                float d = GetCloudSunDistance(uv);
                return smoothstep(
                    _CloudFadeStart,
                    _CloudFadeStart + _CloudFadeRange,
                    d
                );
                //smoothstep between fadestart point and fadeend point 01
                //already proportional to sun stretch
            }
            //////////

            //noise pattern for dissolve
            //used for FarAmount() mask
            float GetCloudSurvivalNoise(float2 uv) {
                float2 p = uv - 0.5;
                p.x *= _ScreenParams.x / max(_ScreenParams.y, 1.0);
                p.x /= _CloudDissolveStretchX;
                p *= _CloudDissolveNoiseScale;

                float base = FBM5(
                    p + _CloudDissolveOffset.xy
                );
                float detail = FBM5(
                    p * 2.1 + _CloudDissolveDetailOffset.xy
                );

                float n = saturate(base * 0.72 + detail * 0.28);
                return smoothstep(0.26, 0.74, n);
            }


            //cloud density final
            float GetCloudDensity(float2 uv) {
                float farAmount = GetFarAmount(uv);

                //if closer use near softness
                float softness = lerp(
                    _CloudNearSoftness,
                    _CloudFarSoftness,
                    farAmount
                );

                float cloudField = GetCloudField(uv); //basic density
                float cloud = smoothstep(
                    _CloudThreshold - softness,
                    _CloudThreshold + softness,
                    cloudField
                );// final smoothstepped field

                float survivalNoise = GetCloudSurvivalNoise(uv);

                // disoolve mix 0 = fade off
                float survival = lerp(1.0, survivalNoise, _CloudDissolveMix); //noise pattern 0.26 0.74
                float dissolveAmount = saturate(farAmount * _CloudFadeStrength); //scalar from sun center

                cloud *= lerp(1.0, survival, dissolveAmount);
                return saturate(cloud);
            }


            //cloud inner rim
            float GetCloudRim(float2 uv, float cloudDensity) {
                float2 toSun = _SunPosition.xy - uv;
                float2 toSunDir = toSun / max(length(toSun), 0.0001);

                //edge detection
                float shiftedDensity = GetCloudDensity(
                    uv + toSunDir * _CloudRimWidth
                );

                float difference = saturate(
                    cloudDensity - shiftedDensity
                );

                float rim = smoothstep(
                    0.0,
                    max(_CloudRimSoftness, 0.0001),
                    difference
                );

                // far end no rim
                rim *= (1.0 - GetFarAmount(uv));
                return saturate(rim);
            }

            
            //=========================
            //horizon perlin fbm
            float2 RandomGradient(float2 id) {
                float angle = Hash21(id) * 6.28318530718;
                return float2(cos(angle), sin(angle));
            }

            float PerlinNoise(float2 p) {
                float2 id = floor(p);
                float2 f = frac(p);
                float2 u = f * f * (3.0 - 2.0 * f);

                float n00 = dot(RandomGradient(id + float2(0, 0)), f - float2(0, 0));
                float n10 = dot(RandomGradient(id + float2(1, 0)), f - float2(1, 0));
                float n01 = dot(RandomGradient(id + float2(0, 1)), f - float2(0, 1));
                float n11 = dot(RandomGradient(id + float2(1, 1)), f - float2(1, 1));

                float nx0 = lerp(n00, n10, u.x);
                float nx1 = lerp(n01, n11, u.x);
                float n = lerp(nx0, nx1, u.y);

                return saturate(n * 0.72 + 0.5);
            }

            float PerlinFBM4(float2 p) {
                float value = 0.0;
                float amplitude = 0.5;
                float sum = 0.0;

                [unroll]
                for (int octave = 0; octave < 4; octave++) {
                    value += PerlinNoise(p) * amplitude;
                    sum += amplitude;
                    p = p * 2.03 + float2(11.7, 7.9);
                    amplitude *= 0.5;
                }

                return value / max(sum, 0.0001);
            }
            //=========================


            float GetHorizonHeight(float x) {
                float aspect = _ScreenParams.x / max(_ScreenParams.y, 1.0);
                float px =
                    x * aspect * 2.1 / max(_MountainWidth, 0.001)
                    + _MountainNoiseOffset;
                float n = PerlinFBM4(float2(px, 17.37));
                return _HorizonHeight + (n - 0.5) * _MountainAmplitude;
            }

            float GetGroundMask(float2 uv) {
                float horizon = GetHorizonHeight(uv.x);
                return 1.0 - smoothstep(
                    horizon,
                    horizon + _HorizonSoftness,
                    uv.y
                );
            }

            
            // ==========================
            //final blend
            //lerp sky to cloud
            //lerp cloud to cloud rim
            //lerp all to ground
            half4 frag(Interpolators i) : SV_Target {
                float2 uv = i.uv;

                float3 output = GetSky(uv);
                output = ApplySun(uv, output);

                float cloudDensity = GetCloudDensity(uv);
                float cloudRim = GetCloudRim(uv, cloudDensity);

                float3 rimTarget = _CloudRimColor.rgb * _CloudRimIntensity;
                float3 cloudColor = lerp(
                    _CloudColor.rgb,
                    rimTarget,
                    cloudRim
                );

                output = lerp(
                    output,
                    cloudColor,
                    cloudDensity
                );

                float groundMask = GetGroundMask(uv);
                output = lerp(
                    output,
                    _GroundColor.rgb,
                    groundMask
                );

                return half4(output, 1.0);
            }
            ENDHLSL
        }
    }
}
