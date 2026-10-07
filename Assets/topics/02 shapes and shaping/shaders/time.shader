Shader "shader lab/week 2/time" {
    SubShader {
        Tags {"RenderPipeline" = "UniversalPipeline"}
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

            float4 frag (Interpolators i) : SV_Target {
                float3 colorA = float3(0.72, 0.04, 0.30);
                float3 colorB = float3(0.00, 0.57, 0.68);
                
                
                float l = 0.5;
                

                float3 c = lerp(colorA, colorB, l);
                return float4(c, 1);
            }
            ENDHLSL
        }
    }
}