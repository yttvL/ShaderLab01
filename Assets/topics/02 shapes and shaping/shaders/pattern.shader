Shader "shader lab/week 2/pattern" {
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

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float circle (float radius, float2 uv) {
                float distance = length(uv);
                distance -= radius;
                float aa = 0.005;
                return 1-smoothstep(0, aa, distance);
            }

            float4 frag (Interpolators i) : SV_Target {
                float output = 0;
                
                return float4(output.rrr, 1.0);
            }
            ENDHLSL
        }
    }
}