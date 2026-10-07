Shader "shader lab/week 4/texture mapping" {
    Properties {
       _tex ("texture", 2D) = "white" {}
    }

    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            
            CBUFFER_START(UnityPerMaterial)
            float4 _tex_ST;
            CBUFFER_END
            
            TEXTURE2D(_tex);
            SAMPLER(sampler_tex);
            
            struct MeshData {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 worldPos : TEXCOORD1;
                float4 screenPos : TEXCOORD2;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                o.screenPos = ComputeScreenPos(o.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                
                return o;
            }

            float4 frag (Interpolators i) : SV_Target {
                // mesh uv
                float2 uv = i.uv;
                float3 color = 0;
                
                uv = i.worldPos.xz;
                uv = i.screenPos.xy / i.screenPos.w;
                float aspect = _ScreenParams.x / _ScreenParams.y;
                uv.x *= aspect;
                
                
                color = SAMPLE_TEXTURE2D(_tex, sampler_tex, TRANSFORM_TEX(uv, _tex));
                
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}