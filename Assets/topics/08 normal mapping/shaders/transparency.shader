Shader "shader lab/week 8/transparency" {
    Properties {
        _color ("color", Color) = (1, 1, 1, 1)
    }
    SubShader {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
        }
        
        ZWrite Off
        
        // final color = (srcColor * srcAlpha) + (dstColor * (1-srcAlpha))
        // additive color = (srcColor * 1) + (dstColor * 1)
        Blend SrcAlpha OneMinusSrcAlpha
        
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _color;
            CBUFFER_END

            struct MeshData {
                float4 vertex : POSITION;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);
                return o;
            }

            float4 frag (Interpolators i) : SV_Target {
                return _color;
            }
            ENDHLSL
        }
    }
}