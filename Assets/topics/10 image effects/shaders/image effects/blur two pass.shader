Shader "shader lab/week 10/two pass blur" {
    Properties {
        _blurSize("blur size", float) = 1
    }
    SubShader {
        Tags { "RenderPipeline"="UniversalPipeline" }
        
        Cull Off
        ZWrite Off
        ZTest Always
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float _blurSize;
        float4 _BlitTexture_TexelSize;
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
            o.uv    = GetFullScreenTriangleTexCoord(v.vertexID);
            return o;
        }
        ENDHLSL
        

        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            float4 frag (Interpolators i) : SV_Target {
                // create a variable to accumulate our samples
            	float4 sum = 0;
                
            	// we can define a little helper function like this, which will make our sample code a lot cleaner.
            	// kernelx is the x offset
            	// calculate our sample uv x component by adding (1/textureWidth) * kernelx * _blurSize
            	// _blurSize is a decent but not totally accurate way to spread the blur out by essentially moving the offsets further away from the center. this works pretty well for values between 0-5, but starts to break down visually after that. doing a better job would require different blur approaches that would be more expensive or would need more complex setup in the renderer feature.
                #define GRABPIXEL(weight, kernelx) SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, float2(i.uv.x + _BlitTexture_TexelSize.x * kernelx * _blurSize, i.uv.y)) * weight
                
				sum += GRABPIXEL(0.05, -4.0);
				sum += GRABPIXEL(0.09, -3.0);
				sum += GRABPIXEL(0.12, -2.0);
				sum += GRABPIXEL(0.15, -1.0);
				sum += GRABPIXEL(0.18, 0.0);
				sum += GRABPIXEL(0.15, +1.0);
				sum += GRABPIXEL(0.12, +2.0);
				sum += GRABPIXEL(0.09, +3.0);
				sum += GRABPIXEL(0.05, +4.0);

				return sum;
            }
            ENDHLSL
        }

        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            float4 frag (Interpolators i) : SV_Target {
                float4 sum = 0;
            	
            	// this is basically the same as above, but doing the y part.
                #define GRABPIXEL(weight, kernely) SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, float2(i.uv.x, i.uv.y + _BlitTexture_TexelSize.y * kernely * _blurSize)) * weight
                
				sum += GRABPIXEL(0.05, -4.0);
				sum += GRABPIXEL(0.09, -3.0);
				sum += GRABPIXEL(0.12, -2.0);
				sum += GRABPIXEL(0.15, -1.0);
				sum += GRABPIXEL(0.18, 0.0);
				sum += GRABPIXEL(0.15, +1.0);
				sum += GRABPIXEL(0.12, +2.0);
				sum += GRABPIXEL(0.09, +3.0);
				sum += GRABPIXEL(0.05, +4.0);

				return sum;
            }
            ENDHLSL
        }
    }
}
