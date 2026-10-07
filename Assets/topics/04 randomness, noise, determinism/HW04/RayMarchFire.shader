Shader "ShaderLab/assignment04/RayMarchFire"
{
    Properties
    {
        //gyroid volume box boundary
        _FloorY ("floor y", Range(-2.5, 0.0)) = -2.03
        _FireHeight ("fire height", Range(0.5, 4.0)) = 2.8
        _FieldWidth ("field width", Range(2.0, 12.0)) = 4
        _FieldDepth ("field depth", Range(1.0, 8.0)) = 2.4

        //simplex noise
        _NoiseScale ("noise scale", Range(0.1, 4.0)) = 1.15
        _NoiseSpeed ("noise speed", Range(0.0, 3.0)) = 2
        _NoiseWarp ("noise warp", Range(0.0, 1.5)) = 0.3
        _TopWarpBoost ("top warp boost", Range(0.0, 3.0)) = 1.2

        _HeightFalloff ("height falloff", Range(0.1, 4.0)) = 1.35
        _HeightVariation ("height variation", Range(0.0, 5)) = 1.9

        //main gyroid field
        _GyroidScale ("gyroid scale", Range(0.2, 5.0)) = 1.5
        _GyroidSpeed ("gyroid rise speed", Range(0.0, 3.0)) = 1.29
        _HorizontalSpeed ("horizontal speed", Range(-6.0, 6.0)) = 3.2
        _DepthSpeed ("depth speed", Range(-3.0, 3.0)) = 0.75
        _GyroidFieldBias ("gyroid field bias", Range(0.0, 8.0)) = 3.5
        _GyroidFieldGain ("gyroid field gain", Range(0.1, 4.0)) = 1.15  //impact on density

        //rendering
        _Density ("volume density", Range(0.1, 10.0)) = 1.05
        _Brightness ("brightness", Range(0.1, 8.0)) = 5.03
        _HeatFalloff ("heat falloff", Range(0.2, 5.0)) = 1.31
        _TipHeat ("tip heat", Range(0.0, 0.5)) = 0.295

        _CameraHeight ("camera height", Range(-0.5, 2.0)) = 0.36
        _CameraTilt ("camera tilt", Range(-0.5, 0.6)) = -0.078
        _CameraFocal ("camera focal", Range(0.7, 2.5)) = 1.93
    }


    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
        }

        Pass
        {
            Cull Off
            ZWrite Off

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #define RAY_STEPS 64
            #define NOISE_OCTAVES 3


            CBUFFER_START(UnityPerMaterial)

            float _FloorY;
            float _FireHeight;
            float _FieldWidth;
            float _FieldDepth;

            float _NoiseScale;
            float _NoiseSpeed;
            float _NoiseWarp;
            float _TopWarpBoost;

            float _HeightFalloff;
            float _HeightVariation;

            float _GyroidScale;
            float _GyroidSpeed;
            float _HorizontalSpeed;
            float _DepthSpeed;
            float _GyroidFieldBias;
            float _GyroidFieldGain;

            float _Density;
            float _Brightness;
            float _HeatFalloff;
            float _TipHeat;

            float _CameraHeight;
            float _CameraTilt;
            float _CameraFocal;

            CBUFFER_END


            // 3D SIMPLEX NOISE
            // HLSL adaptation of the textureless simplex implementation by
            // Ian McEwan / Ashima Arts, maintained by Stefan Gustavson.
            // MIT License:
            // https://github.com/ashima/webgl-noise

            // x mod 289
            float3 mod289(float3 x)
            {
                return x - floor(x * (1.0 / 289.0)) * 289.0;
            }

            float4 mod289(float4 x)
            {
                return x - floor(x * (1.0 / 289.0)) * 289.0;
            }

            //pseudo random gradient scalar id
            float4 permute(float4 x)
            {
                return mod289(((x * 34.0) + 1.0) * x);
            }

            // =============================================================
            // 3d simplex here
            float snoise(float3 v)
            {
                const float2 C = float2(1.0 / 6.0, 1.0 / 3.0);
                const float4 D = float4(0.0, 0.5, 1.0, 2.0);

                float3 i  = floor(v + dot(v, C.yyy));
                float3 x0 = v - i + dot(i, C.xxx);

                float3 g  = step(x0.yzx, x0.xyz);
                float3 l  = 1.0 - g;
                float3 i1 = min(g.xyz, l.zxy);
                float3 i2 = max(g.xyz, l.zxy);

                float3 x1 = x0 - i1 + C.xxx;
                float3 x2 = x0 - i2 + C.yyy;
                float3 x3 = x0 - D.yyy;

                i = mod289(i);

                float4 p =
                    permute(
                        permute(
                            permute(
                                i.z + float4(0.0, i1.z, i2.z, 1.0)
                            )
                            + i.y + float4(0.0, i1.y, i2.y, 1.0)
                        )
                        + i.x + float4(0.0, i1.x, i2.x, 1.0)
                    );

                float n_ = 1.0 / 7.0;
                float3 ns = n_ * D.wyz - D.xzx;

                float4 j = p - 49.0 * floor(p * ns.z * ns.z);

                float4 x_ = floor(j * ns.z);
                float4 y_ = floor(j - 7.0 * x_);

                float4 x = x_ * ns.x + ns.yyyy;
                float4 y = y_ * ns.x + ns.yyyy;
                float4 h = 1.0 - abs(x) - abs(y);

                float4 b0 = float4(x.xy, y.xy);
                float4 b1 = float4(x.zw, y.zw);

                float4 s0 = floor(b0) * 2.0 + 1.0;
                float4 s1 = floor(b1) * 2.0 + 1.0;
                float4 sh = -step(h, 0.0);

                float4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
                float4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

                float3 p0 = float3(a0.xy, h.x);
                float3 p1 = float3(a0.zw, h.y);
                float3 p2 = float3(a1.xy, h.z);
                float3 p3 = float3(a1.zw, h.w);

                float4 norm = rsqrt(
                    float4(
                        dot(p0, p0),
                        dot(p1, p1),
                        dot(p2, p2),
                        dot(p3, p3)
                    )
                );

                p0 *= norm.x;
                p1 *= norm.y;
                p2 *= norm.z;
                p3 *= norm.w;

                float4 m = max(
                    0.6
                    - float4(
                        dot(x0, x0),
                        dot(x1, x1),
                        dot(x2, x2),
                        dot(x3, x3)
                    ),
                    0.0
                );

                m *= m;

                return 42.0 * dot(
                    m * m,
                    float4(
                        dot(p0, x0),
                        dot(p1, x1),
                        dot(p2, x2),
                        dot(p3, x3)
                    )
                );
            }
            // =============================================================
            // =============================================================


            //simplex fbm
            float simplexFBM(float3 p)
            {
                float result = 0.0;
                float amplitude = 0.5;
                float amplitudeSum = 0.0;

                [unroll]
                for (int octave = 0; octave < NOISE_OCTAVES; octave++)
                {
                    result += amplitude * snoise(p);
                    amplitudeSum += amplitude;

                    p *= 2.03;
                    amplitude *= 0.5;
                }
                return result / amplitudeSum;
            }


            //use simplex noise for domain warping
            //return float2(primary, secondary)
            //fbm primary for X warp
            //cheap secondary for z warp
            float2 sampleNoiseWarp(float3 p)
            {
                float time = _Time.y;
                float3 noiseP = p * _NoiseScale;

                noiseP += time * float3(0.1, -_NoiseSpeed, 0.3 * _NoiseSpeed);

                float primary = simplexFBM(noiseP);

                //one layer simplex with huge offset
                float secondary = snoise(noiseP.zxy + float3(123.4, 456.7, 789.1));

                return float2(primary, secondary);
            }


            //============================================================
            // GYROID FIELD


            static const float3x3 OCTAVE_ROT =
                float3x3(
                    0.111111, -0.222222, -0.333333,
                    0.444444, 0.555555, -0.666666,
                    0.777777, 0.888888, 0.999999
                );

            // GYROID FUNCTION
            // G(x,y,z) = sin(x) * cos(y) + sin(y) * cos(z) + sin(z) * cos(x)
            float gyroidCore(float3 p)
            {
                float3 s;
                float3 c;

                sincos(p, s, c);

                return dot(c, s.zxy);
            }


            // 3-octave gyroid
            float gyroidField(float3 p, float time)
            {
                float field = 0.0;

                // ==========================================================
                // octave 0
                // broad structure
                // sdf-like, field is strongest near gyroid surface
                field -= abs(gyroidCore(p));

                // rotate and scale for next octave
                // larger scale higher frequency
                p = mul(p, OCTAVE_ROT) * 1.8;

                // move for next octave
                p -= time * float3(_HorizontalSpeed, _GyroidSpeed, _DepthSpeed);


                // ==========================================================
                // octave 1
                // medium structure
                field -= abs(gyroidCore(p)) * 0.6;

                p = mul(p, OCTAVE_ROT) * 1.8;

                p -= time * float3(
                    // must be negative for tearing effect
                    -0.7 * _HorizontalSpeed, 

                    1.2 * _GyroidSpeed,
                    0.8 * _DepthSpeed
                );


                // ==========================================================
                // octave 2
                field -= abs(gyroidCore(p)) * 0.4;


                return field;
            }

            // GYROID FIELD END
            // scalar field of pos + distance to gyroid structure
            //============================================================



            // FIRE SAMPLE
            //x = density
            //y = heat
            // pos p is for current raymarch pos
            float2 sampleFire(float3 p)
            {
                float time = _Time.y;
                float height = p.y - _FloorY;

                if (height <= 0.0)
                {
                    return 0.0;
                }

                float height01 = saturate(height / _FireHeight);

                //domain warp from simplex
                float2 noiseControl = sampleNoiseWarp(p);
                float primaryNoise   = noiseControl.x;
                float secondaryNoise = noiseControl.y;

                //warp strength is stronger at the top
                float warpStrength =
                    _NoiseWarp
                    * lerp(
                        0.5,
                        1.0 + _TopWarpBoost,
                        height01
                    );

                // q is the warped sample pos for p
                float3 q = p;

                q.x += primaryNoise * warpStrength;
                q.z += secondaryNoise * warpStrength * 0.7;

                //small global rise
                q.y -= time * _GyroidSpeed * 0.35;

                q *= _GyroidScale;


                float g = gyroidField(q, time);

                // approx 0.75-1
                float heightNoise = primaryNoise * (0.75 + 0.25 * abs(secondaryNoise));

                //bias = base bias - height decay + noise variation
                //bias is stronger with higher height
                float verticalBias =_GyroidFieldBias - height * _HeightFalloff + heightNoise * _HeightVariation;

                float potential = verticalBias + g * _GyroidFieldGain;

                //density01
                float density = saturate(potential);
                density *= density;


                //temprature independet from density
                height01 = saturate(1.0 - height / _FireHeight);

                return float2(density, height01);
            }



            // FIRE COLOR
            float3 fireColor(float heat)
            {
                heat = saturate(heat);

                float f = lerp(_TipHeat, 1.0, heat);
                float f3 = f * f * f;
                float f9 = f3 * f3 * f3;

                return float3(f, f3, f9) * _Brightness;
            }


            // RAY BOX CHECK
            bool rayBoxIntersection(
                float3 ro,  //ray origin
                float3 rd,  //ray direction
                float3 boxMin,
                float3 boxMax,
                out float tNear,  //nearest intersection
                out float tFar  //farthest intersection
            )
            {
                float3 safeRD = rd + 0.000001;
                float3 invRD = 1.0 / safeRD;

                // boxMin.x = ro.x + trd.x
                // t = (boxMin.x - ro.x) / rd.x
                // t.x is the intersection distance(raymarching step) with x plane
                float3 t0 = (boxMin - ro) * invRD;
                float3 t1 = (boxMax - ro) * invRD;

                float3 tMin3 = min(t0, t1);
                float3 tMax3 = max(t0, t1);

                // enter all three axis requires the max of the three tMin
                tNear = max(max(tMin3.x, tMin3.y), tMin3.z);
                // exit all three axis requires the min of the three tMax
                tFar = min(min(tMax3.x, tMax3.y), tMax3.z);

                return tFar > max(tNear, 0.0);
            }



            // VOLUME RAYMARCH
            // output: accumulated color
            float3 raymarchFire(
                float3 ro,
                float3 rd
            )
            {
                float3 boxMin = float3(-_FieldWidth, _FloorY, 0.0);
                float3 boxMax = float3(_FieldWidth, _FloorY + _FireHeight * 1.35, _FieldDepth);

                float tNear;
                float tFar;

                if (
                    !rayBoxIntersection(
                        ro,
                        rd,
                        boxMin,
                        boxMax,
                        tNear,
                        tFar
                    )
                )
                {
                    return 0.0; // if outside fire field, return black
                }

                tNear = max(tNear, 0.0);

                float stepSize = (tFar - tNear) / RAY_STEPS;
                //sample middle point
                //float t = tNear + stepSize * 0.5;
                float3 pos = ro + rd * (tNear + stepSize * 0.5);
                float3 stepVector = rd *stepSize;

                float3 accumulatedColor = 0.0;
                float accumulatedAlpha = 0.0;

                [loop]
                for (int stepIndex = 0; stepIndex < RAY_STEPS; stepIndex++)
                {
                    if (accumulatedAlpha > 0.995)
                    {
                        break;
                    }

                    // current raymarch pos
                    //float3 pos = ro + rd * t;
                  

                    float2 fireSample = sampleFire(pos);
                    float density = fireSample.x;
                    float height01 = fireSample.y;

                    if (density > 0.001)
                    {
                        float alpha = saturate(density * _Density * stepSize);
                        float heat = pow(height01, _HeatFalloff);
                        float3 emission = fireColor(heat);

                        //remaining weight: later sample must pass through the accumulated alpha
                        float remaining = 1.0 - accumulatedAlpha;

                        accumulatedColor += emission * alpha * remaining;
                        accumulatedAlpha += alpha* remaining;
                    }

                    //t += stepSize;
                    pos += stepVector;
                }

                return accumulatedColor;
            }


            struct MeshData
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };


            struct Interpolators
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };


            Interpolators vert(MeshData v)
            {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }


            float4 frag(Interpolators i) : SV_Target
            {
                float2 uv = i.uv * 2.0 - 1.0;
                uv.x *= _ScreenParams.x / _ScreenParams.y;
                
                float3 ro = float3(0.0, _CameraHeight, -2.8);
                float3 rd = normalize(float3(uv.x, uv.y + _CameraTilt, _CameraFocal));
                
                float3 color = raymarchFire(ro, rd);
                //color = 1 - exp(-color);    //tone mapping


                return float4(color, 1.0);
            }

            ENDHLSL
        }
    }
}
