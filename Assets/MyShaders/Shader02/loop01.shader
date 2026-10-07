Shader "shader lab/assignment02/loop01" {
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
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            //rotation matrix X axis
            float3 RotateX(float3 p, float angle) {
                float c = cos(angle);
                float s = sin(angle);

                return float3(
                    p.x,
                    p.y * c - p.z * s,
                    p.y * s + p.z * c
                );
            }

            //rotation matrix Y axis
            float3 RotateY(float3 p, float angle) {
                float c = cos(angle);
                float s = sin(angle);

                return float3(
                    p.x * c + p.z * s,
                    p.y,
                    -p.x * s + p.z * c
                );
            }

            //orthographic projection
            float2 Project(float3 p) {
                return p.xy;
            }

            // draw line based on p distance to line segment
            float DrawLine(float2 p, float2 a, float2 b, float width) {
                float2 pa = p - a;
                float2 ba = b - a;

                float h = saturate(dot(pa, ba) / dot(ba, ba));

                float distanceToLine = length(pa - ba * h);

                //anti aliasing
                return 1.0 - smoothstep(
                    width,
                    width + fwidth(distanceToLine),
                    distanceToLine
                );
            }

            float4 frag (Interpolators i) : SV_Target {
                const float TAU_VALUE = 6.2831853;

                const int RING_COUNT = 6;
                const int SEGMENT_COUNT = 72;

                float2 p = i.uv * 2.0 - 1.0;

                //6 sec loop
                float time01 = frac(_Time.y / 6.0);
                float angle = time01 * TAU_VALUE;

                float drawing = 0.0;

                //global Y axis rotation
                float yRotation = angle;

                for (int ring = 0; ring < RING_COUNT; ring++) {

                    float t = float(ring) / float(RING_COUNT - 1);

                    //ring size
                    float radius = lerp(0.3, 0.9, t);

                    //inner rings rotate X faster
                    float xSpeed = float(RING_COUNT - 1 - ring);
                    float xRotation = angle * xSpeed;

                    for (int segment = 0; segment < SEGMENT_COUNT; segment++) {

                        float a0 = float(segment) / float(SEGMENT_COUNT) * TAU_VALUE;

                        float a1 = float(segment + 1) / float(SEGMENT_COUNT) * TAU_VALUE;

                        //loop draw segments
                        //two neighboring points on a circle
                        float3 q0 = float3(
                            cos(a0) * radius,
                            sin(a0) * radius,
                            0.0
                        );

                        float3 q1 = float3(
                            cos(a1) * radius,
                            sin(a1) * radius,
                            0.0
                        );

                        // X rotation
                        q0 = RotateX(q0, xRotation);
                        q1 = RotateX(q1, xRotation);

                        // Y rotation
                        q0 = RotateY(q0, yRotation);
                        q1 = RotateY(q1, yRotation);

                        //project back to 2D
                        float2 screenA = Project(q0) * 0.8;
                        float2 screenB = Project(q1) * 0.8;

                        drawing = max(
                            drawing,
                            DrawLine(
                                p,
                                screenA,
                                screenB,
                                0.005
                            )
                        );
                    }
                }

                return half4(drawing.xxx, 1.0);
            }

            ENDHLSL
        }
    }
}
