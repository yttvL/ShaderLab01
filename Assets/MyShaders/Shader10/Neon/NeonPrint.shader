Shader "ShaderLab/assignment10/NeonPrint"
{
    Properties
    {
        [Header(Overall)]
        _Intensity ("Effect Intensity", Range(0,1)) = 1
        _Exposure ("Input Exposure", Range(0.1,5)) = 1.4
        _BlackPoint ("Black Point", Range(0,0.4)) = 0.025
        _WhitePoint ("White Point", Range(0.2,2)) = 0.9
        [Header(Palette)]
        _ShadowColor ("Deep Violet", Color) = (0.035,0.008,0.12,1)
        _MidColor ("Purple", Color) = (0.22,0.018,0.3,1)
        _PinkColor ("Hot Magenta", Color) = (0.95,0.005,0.19,1)
        _LightColor ("Coral Orange", Color) = (1,0.19,0.055,1)
        _PaletteMix ("Palette Strength", Range(0,1)) = 0.9
        [Header(Paper And Pigment)]
        _SmoothRadius ("Smoothing Radius Pixels", Range(0,5)) = 2
        _ColorSigma ("Color Edge Tolerance", Range(0.01,1)) = 0.18
        _PigmentStrength ("Pigment Variation", Range(0,0.4)) = 0.12
        _Grain ("Fine Grain", Range(0,0.15)) = 0.025
        [Header(White Highlights)]
        _HighlightThreshold ("Highlight Threshold", Range(0.1,2)) = 0.85
        _HighlightSoftness ("Highlight Edge Softness", Range(0.001,0.3)) = 0.035
        _HighlightStrength ("Highlight Strength", Range(0,1)) = 0.95
        [Header(Ink Outline)]
        _OutlineColor ("Outline Pink", Color) = (1,0.002,0.15,1)
        _OutlineWidth ("Outline Width Pixels", Range(0.5,5)) = 1.6
        _OutlineStrength ("Outline Strength", Range(0,1)) = 0.9
        _ColorEdgeThreshold ("Color Edge Threshold", Range(0.01,1)) = 0.24
        [Header(Halftone Shading)]
        _DotColor ("Dot Ink", Color) = (1,0.015,0.24,1)
        _DotSpacing ("Dot Spacing Pixels", Range(3,20)) = 7
        _DotRadius ("Dot Size Bias", Range(0.05,0.48)) = 0.24
        _DotAngle ("Dot Angle Degrees", Range(-90,90)) = 32
        _DotStrength ("Halftone Strength", Range(0,1)) = 1
        _DotCoverage ("Midtone Exposure", Range(0,1)) = 0.48
        [Header(Debug)]
        [Enum(Final,0,Original,1,Smoothed,2,Edges,3,DotMask,4,Tone,5)] _DebugView ("Debug View", Float) = 0
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }
        Cull Off ZWrite Off ZTest Always
        HLSLINCLUDE
        #pragma target 3.5
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
        TEXTURE2D_X(_NeonOriginalTexture);
        CBUFFER_START(UnityPerMaterial)
        float4 _ShadowColor, _MidColor, _PinkColor, _LightColor, _OutlineColor, _DotColor;
        float _Intensity, _Exposure, _BlackPoint, _WhitePoint;
        float _PaletteMix, _SmoothRadius, _ColorSigma;
        float _PigmentStrength, _Grain, _HighlightThreshold, _HighlightSoftness, _HighlightStrength;
        float _OutlineWidth, _OutlineStrength, _ColorEdgeThreshold;
        float _DotSpacing, _DotRadius, _DotAngle, _DotStrength, _DotCoverage, _DebugView;
        CBUFFER_END

        float Hash21(float2 p)
        {
            p = frac(p * float2(123.34, 456.21));
            p += dot(p, p + 45.32);
            return frac(p.x * p.y);
        }
        // 平滑值噪声：低频控制颜料块，中频控制覆盖破碎，小尺度控制颗粒。
        float Noise(float2 p)
        {
            float2 cell = floor(p), f = frac(p);
            f = f*f*(3.0-2.0*f);
            return lerp(lerp(Hash21(cell), Hash21(cell+float2(1,0)), f.x),
                        lerp(Hash21(cell+float2(0,1)), Hash21(cell+1), f.x), f.y);
        }
        float Luma(float3 c) { return dot(max(c,0), float3(0.2126,0.7152,0.0722)); }
        float3 ReadColor(float2 uv)
        {
            return SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, saturate(uv)).rgb;
        }
        float Tone(float3 c)
        {
            return saturate((Luma(c)*_Exposure-_BlackPoint)/max(_WhitePoint-_BlackPoint,0.001));
        }
        float3 Palette(float t)
        {
            float3 c = lerp(_ShadowColor.rgb, _MidColor.rgb, smoothstep(0,0.38,t));
            c = lerp(c, _PinkColor.rgb, smoothstep(0.25,0.74,t));
            return lerp(c, _LightColor.rgb, smoothstep(0.7,1,t));
        }
        ENDHLSL

        Pass
        {
            Name "Color Aware Paint Smoothing"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragSmooth
            float4 FragSmooth(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float2 uv = input.texcoord;
                float3 center = ReadColor(uv);
                float3 sum = center;
                float total = 1;
                // 13 次颜色采样的双边平滑：颜色变化较大的区域降低混色。
                [unroll] for (int k=0;k<12;k++)
                {
                    float angle = k*2.39996323;
                    float radius = sqrt((k+0.5)/12.0)*_SmoothRadius;
                    float2 p = uv+float2(cos(angle),sin(angle))*radius*_BlitTexture_TexelSize.xy;
                    float3 c = ReadColor(p);
                    float3 diff = c-center;
                    float weight = exp(-dot(diff,diff)/max(_ColorSigma*_ColorSigma,0.0001));
                    sum += c*weight;
                    total += weight;
                }
                return float4(sum/total,1);
            }
            ENDHLSL
        }

        Pass
        {
            Name "Neon Pigment And Print"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragPrint
            float4 FragPrint(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float2 uv = input.texcoord;
                float2 pixel = uv*_BlitTexture_TexelSize.zw;
                float4 original = SAMPLE_TEXTURE2D_X(_NeonOriginalTexture,sampler_LinearClamp,uv);
                float3 smoothColor = ReadColor(uv);
                float t = Tone(smoothColor);

                float pigment = (Noise(pixel/38.0)*0.55+Noise(pixel/11.0)*0.3+Noise(pixel/3.0)*0.15)-0.5;
                t = saturate(t+pigment*_PigmentStrength*2);
                float3 color = lerp(smoothColor,Palette(t),_PaletteMix);
                // 稀疏的紫色擦痕，保留亮区的大形状。
                float scumble = smoothstep(0.58,0.8,Noise(pixel/5.0)+0.2*Noise(pixel/43.0));
                color = lerp(color,_MidColor.rgb,scumble*_PigmentStrength*(1-t));

                // Sobel 亮度边缘：对物体和天空图像使用相同的颜色边缘检测。
                float gx=0, gy=0;
                [unroll] for(int y=-1;y<=1;y++)
                {
                    [unroll] for(int x=-1;x<=1;x++)
                    {
                        float2 p = uv+float2(x,y)*_OutlineWidth*_BlitTexture_TexelSize.xy;
                        float lum = Luma(ReadColor(p));
                        gx += lum*x*(y==0 ? 2.0 : 1.0);
                        gy += lum*y*(x==0 ? 2.0 : 1.0);
                    }
                }
                float colorEdge = smoothstep(_ColorEdgeThreshold,_ColorEdgeThreshold*2,length(float2(gx,gy)));
                float edge = colorEdge*_OutlineStrength;

                float angle = radians(_DotAngle), sn=sin(angle), cs=cos(angle);
                float2 dotPixel = float2(cs*pixel.x-sn*pixel.y,sn*pixel.x+cs*pixel.y);
                float2 dotUV = frac(dotPixel/max(_DotSpacing,1))-0.5;
                float dist = length(dotUV);
                float aa = max(fwidth(dist),0.001);
                // Bright ink dots grow with luminance; the endpoints are solid ink.
                // Radius sqrt(0.5) covers an entire square cell, leaving dark holes
                // just before the bright region becomes completely solid.
                float coverage = smoothstep(0.12,0.78,
                    t + (_DotCoverage-0.48)*0.5);
                float radius = sqrt(coverage)*0.70710678*(_DotRadius/0.24);
                float dots = 1-smoothstep(radius-aa,radius+aa,dist);
                dots = lerp(dots,0,1-smoothstep(0,0.025,coverage));
                dots = lerp(dots,1,smoothstep(0.975,1,coverage));
                float dotMask = dots;
                float3 darkInk = lerp(_ShadowColor.rgb,_MidColor.rgb,0.08);
                float3 lightInk = lerp(_PinkColor.rgb,_LightColor.rgb,0.65);
                lightInk = lerp(lightInk,_DotColor.rgb,0.08);
                float3 printColor = lerp(darkInk,lightInk,dots);
                color = lerp(color,printColor,_DotStrength);
                // Preserve subtle paper grain and pigment variation without facets.
                color *= 1 + pigment*_PigmentStrength*0.65;
                float highlightValue = Luma(smoothColor)*_Exposure;
                float halo = smoothstep(_HighlightThreshold-0.16,_HighlightThreshold,highlightValue);
                color = lerp(color,lerp(_PinkColor.rgb,float3(1,0.65,0.78),0.65),halo*_HighlightStrength*0.35);
                float whiteMask = smoothstep(_HighlightThreshold-_HighlightSoftness,
                    _HighlightThreshold+_HighlightSoftness,highlightValue)*_HighlightStrength;
                color = lerp(color,float3(1,0.98,0.97),whiteMask);
                color = lerp(color,_OutlineColor.rgb,edge*(1-whiteMask*0.7));
                color += (Hash21(floor(pixel))-0.5)*_Grain;
                color = max(color,0);
                float influence = _Intensity;
                if (_DebugView>4.5) return float4(t.xxx,1);
                if (_DebugView>3.5) return float4(dotMask.xxx,1);
                if (_DebugView>2.5) return float4(colorEdge.xxx,1);
                if (_DebugView>1.5) return float4(smoothColor,1);
                if (_DebugView>0.5) return original;
                return float4(lerp(original.rgb,color,influence),original.a);
            }
            ENDHLSL
        }
    }
}
