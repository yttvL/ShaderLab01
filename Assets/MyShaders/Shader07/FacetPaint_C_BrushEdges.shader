Shader "ShaderLab/assignment07/BrushStroke"
{
    Properties
    {
        [Header(Palette)]
        _ShadowColor ("Shadow Pigment", Color) = (1, 1, 1, 1)
        _MidColor ("Midtone Pigment", Color) = (1, 1, 1, 1)
        _LightColor ("Light Pigment", Color) = (1, 1, 1, 1)
        _HighlightColor ("Highlight Pigment", Color) = (1, 1, 1, 1)
        _EdgeColor ("Pigment Edge Color", Color) = (1, 1, 1, 1)

        [Header(FacetedNormals)]
        _FacetDensity ("Cell Density per Local Unit", Range(2, 25)) = 10
        _FacetStrength ("Facet Strength", Range(0, 1)) = 1
        _GeometryNormalBlend ("Original Normal Blend", Range(0, 1)) = 0
        _ProxyCenter ("Local Shape Center", Vector) = (0, 0, 0, 0)
        _GridRotation ("Cell Field Y Rotation", Range(0, 90)) = 19
        _CellJitter ("Voronoi Seed Jitter", Range(0, 1)) = 0.80

        [Header(BrushEdges)]
        _EdgeDisplacement ("Brush Edge Displacement", Range(0, 0.25)) = 0.105
        _EdgeInfluence ("Edge Influence Width", Range(0.03, 0.40)) = 0.23
        _StrokeScale ("Stroke Grain Frequency", Range(2, 25)) = 9.0
        _StrokeElongation ("Stroke Elongation", Range(1, 12)) = 4.5
        _BristleStrength ("Fine Bristle Strength", Range(0, 1)) = 0.35

        [Header(DiffuseLighting)]
        _ShadowThreshold ("Shadow Band Threshold", Range(0.05, 0.85)) = 0.39
        _LightThreshold ("Light Band Threshold", Range(0.15, 0.98)) = 0.74
        _BandSoftness ("Tone Band Softness", Range(0.001, 0.20)) = 0.045

        [Header(SpecularLighting)]
        _SpecExponent ("Blinn Phong Exponent", Range(2, 80)) = 17
        _SpecThreshold ("Paint Highlight Threshold", Range(0.02, 0.95)) = 0.27
        _SpecSoftness ("Highlight Edge Softness", Range(0.001, 0.30)) = 0.065
        _SpecStrength ("Highlight Strength", Range(0, 1)) = 0.85

        [Header(Debug)]
        [Enum(Final,0,OriginalNormal,1,FacetNormal,2,FacetLambert,3,DiffuseOnly,4,Specular,5,CellIDs,6,StrokeNoise,7,EdgeMask,8,OriginalCellIDs,9)]
        _DebugView ("Debug View", Float) = 0
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
            Name "FacetPaintForward"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _ShadowColor;
                float4 _MidColor;
                float4 _LightColor;
                float4 _HighlightColor;
                float4 _EdgeColor;
                float4 _ProxyCenter;
                float _FacetDensity;
                float _FacetStrength;
                float _GeometryNormalBlend;
                float _GridRotation;
                float _CellJitter;
                float _EdgeDisplacement;
                float _EdgeInfluence;
                float _StrokeScale;
                float _StrokeElongation;
                float _BristleStrength;
                float _StrokePigmentStrength;
                float _ShadowThreshold;
                float _LightThreshold;
                float _BandSoftness;
                float _BandEdgeWidth;
                float _BandEdgeStrength;
                float _WithinBandShading;
                float _SpecExponent;
                float _SpecThreshold;
                float _SpecSoftness;
                float _SpecStrength;
                float _DebugView;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionOS : TEXCOORD0;
                float3 normalOS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
            };

            Varyings vert(Attributes v)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
                o.positionOS = v.positionOS.xyz;
                o.normalOS = v.normalOS;
                return o;
            }

            float3 RotateLocalY(float3 p, float angle)
            {
                float s = sin(angle);
                float c = cos(angle);
                return float3(c * p.x - s * p.z, p.y, s * p.x + c * p.z);
            }

            float Hash13(float3 p)
            {
                p = frac(p * 0.1031);
                p += dot(p, p.yzx + 33.33);

                return frac((p.x + p.y) * p.z);
            }

            float3 Hash33(float3 p)
            {
                return float3(
                    Hash13(p + float3(3.1, 7.2, 1.9)),
                    Hash13(p + float3(11.7, 2.5, 9.3)),
                    Hash13(p + float3(5.9, 13.1, 4.7)));
            }

            float ValueNoise2D(float2 p)
            {
                float2 cell = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);

                float a = Hash13(float3(cell, 2.73));
                float b = Hash13(float3(cell + float2(1.0, 0.0), 2.73));
                float c = Hash13(float3(cell + float2(0.0, 1.0), 2.73));
                float d = Hash13(float3(cell + float2(1.0, 1.0), 2.73));

                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }

            // BRUSH STROKE
            //slowly changing along the edge and rapidly changing across it
            float BrushNoise(float2 localStroke, float pairHash)
            {
                float2 uv = float2(
                    localStroke.x * _StrokeScale / max(_StrokeElongation, 1.0),
                    localStroke.y * _StrokeScale);

                float2 shift = float2(pairHash * 17.13, pairHash * 23.61);

                float coarse = ValueNoise2D(uv + shift);
                float fine = ValueNoise2D(uv * float2(1.9, 3.3) + shift + 11.37);

                float fibers = sin(localStroke.y * _StrokeScale * 13.0 + coarse * 3.0 + pairHash * 6.2831853);

                float result = (coarse - 0.5) * 1.45 + (fine - 0.5) * 0.52 * _BristleStrength + fibers * 0.14 * _BristleStrength;
                return result;
            }

            struct FacetRegion
            {
                float3 centerOS; //renpresentative center of voronoi cell
                float id;
                float originalID;
                float brushNoise;
                float edgeMask; //distance to cell edge
                float pigmentMask;
            };

            FacetRegion FindFacetRegion(float3 positionOS)
            {
                float radiansY = _GridRotation * (3.14159265359 / 180.0);
                float3 p = RotateLocalY(positionOS, radiansY) * _FacetDensity;
                float3 lattice = floor(p);

                float bestDistance2 = 1e10;
                float secondDistance2 = 1e10;
                float3 bestSite = 0.0;
                float3 secondSite = 0.0;
                float3 bestCell = 0.0;
                float3 secondCell = 0.0;

                [loop]
                for (int z = -1; z <= 1; z++)
                {
                    [loop]
                    for (int y = -1; y <= 1; y++)
                    {
                        [loop]
                        for (int x = -1; x <= 1; x++)
                        {
                            float3 neighborCell = lattice + float3(x, y, z);
                            float3 randomShift = Hash33(neighborCell) - 0.5;
                            float3 site = neighborCell + 0.5 + randomShift * _CellJitter;
                            float3 difference = p - site;
                            float d2 = dot(difference, difference);

                            if (d2 < bestDistance2)
                            {
                                secondDistance2 = bestDistance2;
                                secondSite = bestSite;
                                secondCell = bestCell;
                                bestDistance2 = d2;
                                bestSite = site;
                                bestCell = neighborCell;
                            }
                            else if (d2 < secondDistance2)
                            {
                                secondDistance2 = d2;
                                secondSite = site;
                                secondCell = neighborCell;
                            }
                        }
                    }
                }

                // sort side to get stable A/B
                bool bestIsA =
                    (bestCell.x < secondCell.x) ||
                    (bestCell.x == secondCell.x && bestCell.y < secondCell.y) ||
                    (bestCell.x == secondCell.x && bestCell.y == secondCell.y
                     && bestCell.z < secondCell.z);
                float3 siteA = bestIsA ? bestSite : secondSite;
                float3 siteB = bestIsA ? secondSite : bestSite;
                float3 cellA = bestIsA ? bestCell : secondCell;
                float3 cellB = bestIsA ? secondCell : bestCell;

                float3 bisectorAxis = normalize(siteB - siteA);
                float3 midpoint = (siteA + siteB) * 0.5;

                // signed position relative to the bisector in cell units
                // A negative, B positive
                float signedBorder = dot(p - midpoint, bisectorAxis);

                // directions for strokes that follow this border
                float3 proxyRot = RotateLocalY(_ProxyCenter.xyz, radiansY) * _FacetDensity;
                float3 surfaceDir = normalize(p - proxyRot + float3(1e-5, 2e-5, 3e-5));
                float3 acrossRaw = bisectorAxis - surfaceDir * dot(bisectorAxis, surfaceDir);
                float projectionLength = length(acrossRaw);
                float3 fallbackAxis = abs(surfaceDir.y) < 0.85
                    ? float3(0.0, 1.0, 0.0) : float3(1.0, 0.0, 0.0);
                float3 across = projectionLength > 1e-4
                    ? acrossRaw / projectionLength : normalize(cross(surfaceDir, fallbackAxis));
                float3 along = normalize(cross(surfaceDir, across));

                float3 delta = p - midpoint;
                float2 strokeCoords = float2(dot(delta, along), dot(delta, across));

                float pairHash = Hash13(cellA + float3(8.37, 3.11, 19.71)) * 0.63
                               + Hash13(cellB + float3(11.79, 17.31, 4.13)) * 0.37;
                float brush = BrushNoise(strokeCoords, pairHash);

                //only move the nearest-site
                float edgeInfluence = 1.0 - smoothstep(_EdgeInfluence * 0.30, _EdgeInfluence, abs(signedBorder));
                float displacement = brush * _EdgeDisplacement * edgeInfluence * saturate(projectionLength * 4.0);
                float warpedSignedBorder = signedBorder - displacement;

                bool chooseA = warpedSignedBorder < 0.0;
                float3 chosenSite = chooseA ? siteA : siteB;
                float3 chosenCell = chooseA ? cellA : cellB;

                FacetRegion result;
                result.centerOS = RotateLocalY(chosenSite / _FacetDensity, -radiansY);
                result.id = Hash13(chosenCell + float3(19.1, 7.3, 4.9));
                result.originalID = Hash13(bestCell + float3(19.1, 7.3, 4.9));
                result.brushNoise = brush;
                result.edgeMask = 1.0 - smoothstep(0.0, _EdgeInfluence, abs(warpedSignedBorder));
                float bristleDeposit = saturate(abs(brush) * 1.75 - 0.12);
                result.pigmentMask = result.edgeMask * bristleDeposit;
                return result;
            }


            float BandLine(float v, float threshold, float width)
            {
                return 1.0 - smoothstep(0.0, max(width, 0.001), abs(v - threshold));
            }

            half4 frag(Varyings i) : SV_Target
            {
                float3 restNOS = normalize(i.normalOS);
                FacetRegion region = FindFacetRegion(i.positionOS);

                // a cell's normal aims outward from shape center to the region's representative center
                float3 proxyDirection = region.centerOS - _ProxyCenter.xyz;
                float proxyLength2 = dot(proxyDirection, proxyDirection);
                float3 proxyNOS = proxyLength2 > 0.000001
                    ? proxyDirection * rsqrt(proxyLength2)
                    : restNOS;

                // blending original normal with facet normal
                float3 patchNOS = normalize(lerp(proxyNOS, restNOS, _GeometryNormalBlend));
                float3 facetNOS = normalize(lerp(restNOS, patchNOS, _FacetStrength));

                float3 N = normalize(TransformObjectToWorldNormal(facetNOS));
                float3 Nrest = normalize(TransformObjectToWorldNormal(restNOS));



                //============================
                //Lighting
                //============================
                Light mainLight = GetMainLight();
                float3 L = normalize(mainLight.direction);
                float3 V = normalize(_WorldSpaceCameraPos.xyz - i.positionWS);
                float3 H = normalize(L + V);

                // half lambert is evaluated on the FACET normal
                float lightSignal = saturate(0.5 + 0.5 * dot(N, L));
                float sGate = smoothstep(_ShadowThreshold - _BandSoftness, _ShadowThreshold + _BandSoftness, lightSignal);
                float lGate = smoothstep(_LightThreshold - _BandSoftness, _LightThreshold + _BandSoftness, lightSignal);

                float3 diffusePigment = lerp(_ShadowColor.rgb, _MidColor.rgb, sGate);
                diffusePigment = lerp(diffusePigment, _LightColor.rgb, lGate);

                

                // modified Blinn-Phong highlight also uses Nfacet
                float specLobe = pow(saturate(dot(N, H)), _SpecExponent);
                float specMask = smoothstep(_SpecThreshold - _SpecSoftness, _SpecThreshold + _SpecSoftness, specLobe);
                specMask *= smoothstep(0.15, 0.30, lightSignal);
                float3 color = lerp(diffusePigment, _HighlightColor.rgb, saturate(specMask * _SpecStrength));
                color *= lerp(float3(1.0, 1.0, 1.0), mainLight.color.rgb, 0.2);




                //============================
                // Debug View
                //============================
                if (_DebugView > 0.5 && _DebugView < 1.5)
                    return half4(Nrest * 0.5 + 0.5, 1.0);
                if (_DebugView > 1.5 && _DebugView < 2.5)
                    return half4(N * 0.5 + 0.5, 1.0);
                if (_DebugView > 2.5 && _DebugView < 3.5)
                    return half4(float3(lightSignal, lightSignal, lightSignal), 1.0);
                if (_DebugView > 3.5 && _DebugView < 4.5)
                    return half4(diffusePigment, 1.0);
                if (_DebugView > 4.5 && _DebugView < 5.5)
                    return half4(float3(specMask, specMask, specMask), 1.0);
                if (_DebugView > 5.5 && _DebugView < 6.5)
                    return half4(float3(region.id, frac(region.id * 3.17), frac(region.id * 7.91)), 1.0);
                if (_DebugView > 6.5 && _DebugView < 7.5)
                {
                    float b = saturate(region.brushNoise * 0.5 + 0.5);
                    return half4(b, b, b, 1.0);
                }
                if (_DebugView > 7.5 && _DebugView < 8.5)
                    return half4(float3(region.edgeMask, region.edgeMask, region.edgeMask), 1.0);
                if (_DebugView > 8.5)
                    return half4(float3(region.originalID,
                        frac(region.originalID * 3.17),
                        frac(region.originalID * 7.91)), 1.0);
                return half4(color, 1.0);
            }

            ENDHLSL
        }
    }
}
