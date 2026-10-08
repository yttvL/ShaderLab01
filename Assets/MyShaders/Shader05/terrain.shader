Shader "ShaderLab/assignment05/VertexTerrain"
{
    Properties
    {
        
        [Header(Terrain Shape)]
        _Morph ("Morph", Range(0, 1)) = 1
        _Height ("Displacement Height", Float) = 0.08
        _NoiseScale ("Noise Scale", Float) = 1.5


        [Header(FBM Parameters)]
        _Octaves ("Octaves", Float) = 4.0
        _Lacunarity ("Lacunarity", Float) = 2.0
        _Persistence ("Persistence", Float) = 0.5
        _SeedOffset ("Seed Offset", Vector) = (0, 0, 0, 0)

        _ScrollSpeed ("Scroll Speed", Float) = 0.0
        _ScrollDirection ("Scroll Direction", Vector) = (0, 1, 0, 0)


        [Header(Normal)]
        _NormalSampleOffset ("Normal Sample Offset", Float) = 0.01


        [Header(Land)]
        _LandColor ("Flat Land Color", Color) = (0.3, 0.3, 0.3, 1)
        _RockColor ("Rock Color", Color) = (0.4, 0.4, 0.4, 1)

        _RockSlopeStart ("Rock Slope Start", Range(0, 1)) = 0.18
        _RockSlopeEnd ("Rock Slope End", Range(0, 1)) = 0.55


        [Header(Water)]
        _WaterLevel ("Water Level", Float) = 0.0
        _MaxWaterDepth ("Max Water Depth", Float) = 0.08

        _ShallowWaterColor ("Shallow Water Color", Color) = (0.18, 0.48, 0.48, 1)
        _DeepWaterColor ("Deep Water Color", Color) = (0.025, 0.10, 0.20, 1)
        _WaterTintStrength ("Water Tint Strength", Range(0, 1)) = 0.65

        _ShoreWidth ("Shore Width", Float) = 0.01
        _ShoreColor ("Shore Color", Color) = (0.65, 0.75, 0.55, 1)
        _ShoreIntensity ("Shore Intensity", Range(0, 1)) = 0.20


        [Header(Fake Lighting)]
        _SunDirection ("Sun Direction", Vector) = (0.4, 1.0, 0.3, 0)
        _SunColor ("Sun Color", Color) = (1.0, 1.0, 1.0, 1)
        _ShadowColor ("Shadow Color", Color) = (0.3, 0.3, 0.3, 1)
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
            Cull Back
            ZWrite On

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"


            struct Attributes
            {
                float4 positionOS : POSITION;
            };


            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float heightOS : TEXCOORD1;
            };


            CBUFFER_START(UnityPerMaterial)

            float _Morph;
            float _Height;
            float _NoiseScale;

            float _Octaves;
            float _Lacunarity;
            float _Persistence;
            float4 _SeedOffset;

            float _ScrollSpeed;
            float4 _ScrollDirection;

            float _NormalSampleOffset;

            float4 _LandColor;
            float4 _RockColor;
            float _RockSlopeStart;
            float _RockSlopeEnd;

            float _WaterLevel;
            float _MaxWaterDepth;
            float4 _ShallowWaterColor;
            float4 _DeepWaterColor;
            float _WaterTintStrength;

            float _ShoreWidth;
            float4 _ShoreColor;
            float _ShoreIntensity;

            float4 _SunDirection;
            float4 _SunColor;
            float4 _ShadowColor;

            CBUFFER_END


            float2 Hash22(float2 p)
            {
                p = float2(
                    dot(p, float2(127.1, 311.7)),
                    dot(p, float2(269.5, 183.3))
                );

                //remap range [-1,1]
                return -1.0 + 2.0 * frac(sin(p) * 43758.5453123);
            }


            float PerlinNoise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);

                //perlin fade curve
                float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

                //hash gradient vectors
                float2 g00 = normalize(Hash22(i + float2(0.0, 0.0)));
                float2 g10 = normalize(Hash22(i + float2(1.0, 0.0)));
                float2 g01 = normalize(Hash22(i + float2(0.0, 1.0)));
                float2 g11 = normalize(Hash22(i + float2(1.0, 1.0)));

                //noise contribution for corners
                float n00 = dot(g00, f - float2(0.0, 0.0));
                float n10 = dot(g10, f - float2(1.0, 0.0));
                float n01 = dot(g01, f - float2(0.0, 1.0));
                float n11 = dot(g11, f - float2(1.0, 1.0));

                //interpolate
                float nx0 = lerp(n00, n10, u.x);
                float nx1 = lerp(n01, n11, u.x);

                return lerp(nx0, nx1, u.y);
            }


            float FBM(float2 p)
            {
                float value = 0.0;
                float amplitude = 1.0;
                float frequency = 1.0;
                float maxValue = 0.0;

                //max 8 for performance sake
                int octaveCount = clamp((int)round(_Octaves), 1, 8);

                [loop]
                for (int o = 0; o < 8; o++)
                {
                    if (o >= octaveCount)
                        break;

                    value += PerlinNoise(p * frequency) * amplitude;
                    maxValue += amplitude;

                    frequency *= _Lacunarity;
                    amplitude *= _Persistence;
                }

                return value / max(maxValue, 0.0001);
            }

            
            //lighting
            float HalfLambert(float3 normalWS, float3 lightDirWS)
            {
                return saturate(dot(normalWS, lightDirWS) * 0.5 + 0.5);
            }


            Varyings vert(Attributes input)
            {
                Varyings output;

                float3 positionOS = input.positionOS.xyz;

                //plane rotated, use local Z as height
                float2 scrollDir = normalize(_ScrollDirection.xy + 1e-5);

                float2 samplePos =
                    positionOS.xy * _NoiseScale
                    + scrollDir * (_Time.y * _ScrollSpeed)
                    + _SeedOffset.xy;

                float noise = FBM(samplePos);

                float displacement = noise * _Height * _Morph;
                positionOS.z += displacement;


                // reconstruct normal for lighting
                float eps = max(_NormalSampleOffset, 0.0001);

                float heightScale = _Height * _Morph;

                float hL = FBM(samplePos + float2(-eps, 0.0)) * heightScale;
                float hR = FBM(samplePos + float2(eps, 0.0)) * heightScale;

                float hD = FBM(samplePos + float2(0.0, -eps)) * heightScale;
                float hU = FBM(samplePos + float2(0.0, eps)) * heightScale;

                // for P(x,y) = (x, y, h):
                //(hL-hR, hD-hU, 2*eps)
                float3 terrainNormalOS =
                    normalize(
                        float3(
                            hL - hR,
                            hD - hU,
                            eps * 2.0
                        )
                    );


                VertexPositionInputs positionInputs = GetVertexPositionInputs(positionOS);

                output.positionCS = positionInputs.positionCS;
                output.normalWS = normalize(TransformObjectToWorldNormal(terrainNormalOS));
                output.heightOS = positionOS.z;

                return output;
            }


            
            half4 frag(Varyings input) : SV_Target
            {
                float3 normalWS = normalize(input.normalWS);

                // flat = grass
                // steep = rock
                float steepness = 1.0 - saturate(normalWS.y);
                float rockMask = smoothstep(_RockSlopeStart, _RockSlopeEnd, steepness);
                float3 landColor = lerp(_LandColor.rgb, _RockColor.rgb, rockMask);

                //water
                float waterDepth = max(0.0, _WaterLevel - input.heightOS);
                float waterMask = step(input.heightOS, _WaterLevel);
                float depth01 = saturate(waterDepth / max(_MaxWaterDepth, 0.0001));
                float3 waterColor = lerp(_ShallowWaterColor.rgb, _DeepWaterColor.rgb, depth01);
                float3 surfaceColor = lerp(landColor, waterColor, waterMask * _WaterTintStrength);


                //shore line
                float shoreMask =
                    waterMask *
                    (
                        1.0 -
                        smoothstep(
                            0.0,
                            max(_ShoreWidth, 0.0001),
                            waterDepth
                        )
                    );

                surfaceColor += _ShoreColor.rgb * shoreMask * _ShoreIntensity;


                //half lambert lighting
                float3 sunDirection = normalize(_SunDirection.xyz);
                float lightFactor = HalfLambert(normalWS, sunDirection);
                float3 fakeLighting = lerp(_ShadowColor.rgb, _SunColor.rgb, lightFactor);
                surfaceColor *= fakeLighting;


                return half4(surfaceColor, 1.0);
            }

            ENDHLSL
        }
    }
}
