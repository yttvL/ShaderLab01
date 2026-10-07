Shader "shader lab/week 2/shaping" {
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

            half4 frag(Interpolators i) : SV_Target
            {
                float2 uv = i.uv;

                float color = 0.0;

                float y1 = 0.50
                         + sin(uv.x * 20.0) * 0.10;

                float line1 = 1.0 - smoothstep(
                    0.008,
                    0.015,
                    abs(uv.y - y1)
                );

                color = max(color, line1);

                return half4(color.rrr, 1.0);
            }
            ENDHLSL
        }
    }
}