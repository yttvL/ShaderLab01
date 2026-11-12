Shader "ShaderLab/assignment10/CRT" {
    Properties {
        [Toggle] _Enabled ("Enabled", Float) = 1
        [Header(Screen Glass)]
        _Curve ("Curvature", Range(0, 0.25)) = 0.065
        _Vignette ("Vignette", Range(0, 1)) = 0.24
        _Chromatic ("RGB Separation", Range(0, 0.01)) = 0.0015
        _BorderColor ("Outside Screen Color", Color) = (0, 0, 0, 1)
        [Header(Scanlines)]
        _Lines ("Scanline Strength", Range(0, 1)) = 0.1
        _LineColorA ("Scanline Color A", Color) = (1, 0.15, 0.08, 1)
        _LineColorB ("Scanline Color B", Color) = (0.08, 1, 0.3, 1)
        _LineColorStrength ("Scanline Color Strength", Range(0, 1)) = 0.072
        _LineCount ("Horizontal Line Count", Float) = 90
        _LineSpeed ("Downward Lines Per Second", Float) = 6
        _RollStrength ("Rolling Band Strength", Range(0,1)) = 0.06
        _RollSpeed ("Rolling Band Cycles Per Second", Float) = 0.16
        [Header(Horizontal Interference)]
        _GlitchStrength ("Horizontal Displacement", Range(0, 0.2)) = 0.01
        _GlitchChromaticBoost ("Glitch RGB Boost", Range(0, 0.2)) = 0.01
        _GlitchBlockWidth ("Block Width", Range(0.1, 1)) = 0.65
        _GlitchBlockHeight ("Block Height", Range(0.03, 0.4)) = 0.074
        _GlitchInterval ("Interval Seconds", Float) = 5
        _GlitchDuration ("Duration Seconds", Range(0.05,0.5)) = 0.25
    }
    SubShader {
        Tags { "RenderPipeline"="UniversalPipeline" }
        Cull Off
        ZWrite Off
        ZTest Always

        Pass {
            Name "CRT"
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float _Enabled;
            float _Curve;
            float _Vignette;
            float _Chromatic;
            float4 _BorderColor;
            float _Lines;
            float4 _LineColorA;
            float4 _LineColorB;
            float _LineColorStrength;
            float _LineCount;
            float _LineSpeed;
            float _RollStrength;
            float _RollSpeed;
            float _GlitchStrength;
            float _GlitchChromaticBoost;
            float _GlitchBlockWidth;
            float _GlitchBlockHeight;
            float _GlitchInterval;
            float _GlitchDuration;
            CBUFFER_END

            TEXTURE2D(_BlitTexture);
            SAMPLER(sampler_BlitTexture);

            struct MeshData {
                uint vertexID : SV_VertexID;
            };

            struct Interpolators {
                float4 posCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.posCS = GetFullScreenTriangleVertexPosition(v.vertexID);
                o.uv = GetFullScreenTriangleTexCoord   (v.vertexID);
                return o;
            }


            float2 glassUV (float2 uv) {
                float2 p = uv * 2.0 - 1.0;
                float2 squared = p * p;
                return p * (1.0 + _Curve * 0.5 * dot(squared, squared)) * 0.5 + 0.5;
            }

            float2 randomCenter (float cycle, float blockIndex) {
                float2 seed = float2(
                    cycle * 12.9898 + blockIndex * 78.233 + 4.7,
                    cycle * 39.3468 + blockIndex * 11.135 + 9.2
                );
                return frac(sin(seed) * 43758.5453);
            }

            float blockWeight (float2 uv, float2 center, float2 halfSize) {
                float2 d = abs(uv - center) / max(halfSize, 0.0001);
                return 1.0 - smoothstep(0.85, 1.0, max(d.x, d.y));
            }

            float interferenceWeight (float2 uv, float cycle) {
                float weight = 0;

                [unroll]
                for (int j = 0; j < 3; j++) {
                    float scale = j == 0 ? 1.0 : (j == 1 ? 0.65 : 0.45);
                    float2 halfSize = clamp(float2(_GlitchBlockWidth, _GlitchBlockHeight), float2(0.1, 0.03), float2(1.0, 0.4)) * scale * 0.5;

                    float2 center = lerp(halfSize, 1.0 - halfSize, randomCenter(cycle, j));
                    float current = blockWeight(uv, center, halfSize) * scale * (j == 1 ? -1.0 : 1.0);
                    weight = abs(current) > abs(weight) ? current : weight;
                }
                return weight;
            }

            float3 readColor (float2 uv) {
                return SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, saturate(uv)).rgb;
            }

            float4 frag (Interpolators i) : SV_Target {
                float2 uv = i.uv;
                if (_Enabled < 0.5) return half4(readColor(uv), 1.0);

                float interval = max(0.25, _GlitchInterval);
                float cycle = floor(_Time.y / interval);
                float phaseTime = _Time.y - cycle * interval;
                float duration = clamp(_GlitchDuration, 0.05, interval * 0.9);
                float envelope = phaseTime < duration ? sin(PI * phaseTime / duration) : 0;
                float jitter = sin(_Time.y * 91.0);
                float interference = interferenceWeight(uv, cycle);
                float2 sourceUV = glassUV(uv);
                sourceUV.x += _GlitchStrength * envelope * jitter * interference;

                if (any(sourceUV < 0.0) || any(sourceUV > 1.0)) {
                    return float4(_BorderColor.rgb, 1.0);
                }

                float separation = _Chromatic + _GlitchChromaticBoost * envelope * abs(jitter) * abs(interference);
                float3 color = readColor(sourceUV);
                color.r = readColor(sourceUV + float2(separation, 0)).r;
                color.b = readColor(sourceUV - float2(separation, 0)).b;

                float screenY = 1.0 - uv.y;

                float phase = screenY * max(_LineCount, 1.0) - _Time.y * _LineSpeed;
                float visibility = 1.0 - smoothstep(0.4, 0.8, fwidth(phase));
                float scanline = 0.5 + 0.5 * cos(phase * TWO_PI);

                color *= 1.0 - _Lines * visibility * scanline;
                float colorA = pow(saturate(0.5 + 0.5 * sin(phase * TWO_PI)), 4.0);
                float colorB = pow(saturate(0.5 - 0.5 * sin(phase * TWO_PI)), 4.0);
                color += (_LineColorA.rgb * colorA + _LineColorB.rgb * colorB) * (_Lines * _LineColorStrength * visibility);

                float rollCenter = frac(_Time.y * _RollSpeed);
                float roll = 1 - smoothstep(0, 0.045, abs(screenY - rollCenter));
                color *= 1.0 - _RollStrength * roll;
                float2 position = uv * 2.0 - 1.0;
                color *= 1.0 - _Vignette * saturate(dot(position, position) * 0.5);

                return half4(max(color, 0), 1.0);
            }
            ENDHLSL
        }
    }
    Fallback Off
}
