Shader "shader lab/week 2/polar blend" {
    Properties {
        _spaceBlend ("space blend", Range(0,1)) = 0
    }
    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #define TAU 6.283185307

            CBUFFER_START(UnityPerMaterial)
            float _spaceBlend;
            CBUFFER_END

            struct MeshData {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag (Interpolators i) : SV_Target {
                float2 uv = i.uv * 2.0 - 1.0;
                float2 outUV = uv;
                

                return float4(outUV.x, 0.0, outUV.y, 1.0);
            }
            ENDHLSL
        }
    }
}