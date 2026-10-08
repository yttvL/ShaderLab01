Shader "ShaderLab/assignment03/time03"
{
    Properties {
        _hour ("hour", Float) = 0
        _minute ("minute", Float) = 0
        _second ("second", Float) = 0

        _timeScale ("time scale", Float) = 60

        _backgroundColor ("background color", Color) = (0, 0, 0, 1)
        _faceColor ("clock face color", Color) = (0, 0, 0, 1)

        _hourColor ("hour color", Color) = (0, 0, 0, 1)
        _minuteColor ("minute color", Color) = (0, 0, 0, 1)
        _secondColor ("second color", Color) = (0, 0, 0, 1)

        TILT_X ("tilt x", Float) = -0.25
        TILT_Y ("tilt y", Float) = 0.3

        DEPTH_LENGTH ("depth length", Float) = 2 //fake z length
        Z_SPEED ("z speed", Float) = 1

        CAMERA_DISTANCE ("camera distance", Float) = 0.6 //cam dist to z=0
        FOCAL_LENGTH ("focal length", Float) = 0.6

        CENTER_X ("centerX", Float) = 0.0
        CENTER_Y ("centerY", Float) = 0.0
    }

    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }

        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #define TAU 6.28318530718
            #define TRAIL_SEGMENTS_SECONDS 1920
            #define TRAIL_SEGMENTS_OTHERS 96
            #define FACE_SEGMENTS 48

            CBUFFER_START(UnityPerMaterial)
            float _hour;
            float _minute;
            float _second;
            float _timeScale;

            float4 _backgroundColor;
            float4 _faceColor;
            float4 _hourColor;
            float4 _minuteColor;
            float4 _secondColor;

            float TILT_X;
            float TILT_Y;

            float DEPTH_LENGTH = 2; //fake z length
            float Z_SPEED = 1;

            float CAMERA_DISTANCE = 0.6; //cam dist to z=0
            float FOCAL_LENGTH = 0.6;

            float CENTER_X = 0.0;
            float CENTER_Y = 0.0;

            CBUFFER_END

            static const float HOUR_RADIUS = 0.08;
            static const float MINUTE_RADIUS = 0.16;
            static const float SECOND_RADIUS = 0.22;

            


            static const float TRAIL_NEAR_WIDTH = 0.0016; //after projection on 2D width
            static const float TRAIL_FAR_WIDTH  = 0.00035;

            static const float FADE_START = 0.04;
            static const float HOUR_FADE_END = 1;
            static const float MINUTE_FADE_END = 1;
            static const float SECOND_FADE_END = 0.2;

            static const float FACE_LINE_WIDTH = 0.0015;
            static const float HAND_LINE_WIDTH = 0.003;
            static const float CENTER_RADIUS = 0.005;
            static const float POINT_RADIUS = 0.005;



            struct MeshData {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            struct ProjectedPoint {
                float2 xy;
                float cameraDepth;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float3 rotateX(float3 p, float a) {
                float s = sin(a);
                float c = cos(a);

                return float3(
                    p.x,
                    c * p.y - s * p.z,
                    s * p.y + c * p.z
                );
            }

            float3 rotateY(float3 p, float a) {
                float s = sin(a);
                float c = cos(a);

                return float3(
                    c * p.x + s * p.z,
                    p.y,
                    -s * p.x + c * p.z
                );
            }

            //calculate tilt from camera
            float3 transformClockPoint(float3 p) {
                p = rotateX(p, TILT_X);
                p = rotateY(p, TILT_Y);
                return p;
            }
            
            //tilt and project to 2d
            //packed with cameraDepth
            ProjectedPoint projectPoint(float3 p) {
                ProjectedPoint o;

                p = transformClockPoint(p);

                float zCam = CAMERA_DISTANCE - p.z;
                zCam = max(zCam, 0.05);

                o.xy = p.xy * (FOCAL_LENGTH / zCam);
                o.xy += float2(CENTER_X, CENTER_Y);
                o.cameraDepth = zCam;

                return o;
            }

            //distance 2d point p to segment ab
            float sdSegment(float2 p, float2 a, float2 b) {
                float2 pa = p - a;
                float2 ba = b - a;
                float denom = max(dot(ba, ba), 1e-6);
                float h = saturate(dot(pa, ba) / denom);
                return length(pa - ba * h);
            }

            // whether p close enough to draw segment ab
            float segmentMask(float2 p, float2 a, float2 b, float width) {
                float d = sdSegment(p, a, b);
                float aa = max(fwidth(d), 1e-5);
                return 1.0 - smoothstep(width, width + aa * 1.15, d);
            }

            float discMask(float2 p, float2 c, float radius) {
                float d = length(p - c);
                float aa = max(fwidth(d), 1e-5);
                return 1.0 - smoothstep(radius, radius + aa * 1.15, d);
            }

            //important:counterclockwise PI/2 to turn to clock rotation
            float currentHourAngle() {
                float h = fmod(_hour, 12.0);
                float hour01 = (h + _minute / 60.0 + _second / 3600.0) / 12.0;
                return -TAU * hour01 * _timeScale + 1.57079632679;
            }

            float currentMinuteAngle() {
                float minute01 = (_minute + _second / 60.0) / 60.0;
                return -TAU * minute01 * _timeScale + 1.57079632679;
            }

            float currentSecondAngle() {
                float second01 = _second / 60.0;
                return -TAU * second01 * _timeScale + 1.57079632679;
            }

            float3 helixPoint(
                float t, //01 curve
                float radius,
                float currentAngle,
                float turnsAcrossDepth
            ) {
                float z = -t * DEPTH_LENGTH * Z_SPEED;

                float angle = currentAngle + TAU * turnsAcrossDepth * t;

                return float3(
                    radius * cos(angle),
                    radius * sin(angle),
                    z
                );
            }

            // whether pixel should be drawn for one trail
            float trailMask(
                float2 pixel,
                float radius,
                float currentAngle,
                float turnsAcrossDepth,
                float widthScale,
                float fadeEnd,
                int trail_segments
            ) {
                float best = 0.0;

                for (int s = 0; s < trail_segments; s++) {
                    //small segment start and end
                    float t0 = s / (float)trail_segments;
                    float t1 = (s + 1) / (float)trail_segments;
                    if (t0 >= fadeEnd) break;
                    float tm = 0.5 * (t0 + t1);

                    //projected points of segment ends
                    ProjectedPoint p0 =
                        projectPoint(
                            helixPoint(
                                t0,
                                radius,
                                currentAngle,
                                turnsAcrossDepth
                            )
                        );

                    ProjectedPoint p1 =
                        projectPoint(
                            helixPoint(
                                t1,
                                radius,
                                currentAngle,
                                turnsAcrossDepth
                            )
                        );

                    float width = lerp(TRAIL_NEAR_WIDTH, TRAIL_FAR_WIDTH, tm) * widthScale;

                    float fade = 1.0 - smoothstep(FADE_START, fadeEnd, tm);

                    float segment =
                        segmentMask(
                            pixel,
                            p0.xy,
                            p1.xy,
                            width
                        );

                    //fade again based on cameraZ
                    float segmentDepth = 0.5 * (p0.cameraDepth + p1.cameraDepth);
                    float cameraZFade = 1.0 - smoothstep(0.1, 6, segmentDepth);
                    //cameraZFade = pow(cameraZFade, 2);

                    best = max(best, segment * fade * cameraZFade);

                    //should sample 640 segments
                }

                return saturate(best);
            }

            //for clock countour
            float faceCircleMask(float2 pixel, float radius) {
                float best = 0.0;

                for (int s = 0; s < FACE_SEGMENTS; s++) {
                    float a0 = TAU * s / (float)FACE_SEGMENTS;
                    float a1 = TAU * (s + 1) / (float)FACE_SEGMENTS;

                    ProjectedPoint p0 =
                        projectPoint(
                            float3(
                                radius * cos(a0),
                                radius * sin(a0),
                                0.0
                            )
                        );

                    ProjectedPoint p1 =
                        projectPoint(
                            float3(
                                radius * cos(a1),
                                radius * sin(a1),
                                0.0
                            )
                        );

                    best = max(
                        best,
                        segmentMask(
                            pixel,
                            p0.xy,
                            p1.xy,
                            FACE_LINE_WIDTH
                        )
                    );
                }

                return saturate(best);
            }

            float4 frag (Interpolators i) : SV_Target {
                float2 pixel = i.uv - 0.5;

                float du = max(length(ddx(i.uv)), 1e-6);
                float dv = max(length(ddy(i.uv)), 1e-6);
                float quadAspect = dv / du;
                pixel.x *= quadAspect;

                float hourAngle = currentHourAngle();
                float minuteAngle = currentMinuteAngle();
                float secondAngle = currentSecondAngle();

                const float HOUR_TURNS = 1.0 / 12.0;
                const float MINUTE_TURNS = 1.0;
                const float SECOND_TURNS = 60.0;

                float hourTrail =
                    trailMask(
                        pixel,
                        HOUR_RADIUS,
                        hourAngle,
                        HOUR_TURNS,
                        0.72,
                        HOUR_FADE_END,
                        TRAIL_SEGMENTS_OTHERS
                    );

                float minuteTrail =
                    trailMask(
                        pixel,
                        MINUTE_RADIUS,
                        minuteAngle,
                        MINUTE_TURNS,
                        0.62,
                        MINUTE_FADE_END,
                        TRAIL_SEGMENTS_OTHERS
                    );

                float secondTrail =
                    trailMask(
                        pixel,
                        SECOND_RADIUS,
                        secondAngle,
                        SECOND_TURNS,
                        0.30,
                        SECOND_FADE_END,
                        TRAIL_SEGMENTS_SECONDS
                    );


                float faceRadius = max(HOUR_RADIUS, max(MINUTE_RADIUS, SECOND_RADIUS));

                float face = faceCircleMask(pixel, faceRadius);

                ProjectedPoint centerP = projectPoint(float3(0.0, 0.0, 0.0));
                ProjectedPoint hourEndP = projectPoint(float3(HOUR_RADIUS * cos(hourAngle), HOUR_RADIUS * sin(hourAngle), 0.0));
                ProjectedPoint minuteEndP = projectPoint(float3(MINUTE_RADIUS * cos(minuteAngle), MINUTE_RADIUS * sin(minuteAngle), 0.0));
                ProjectedPoint secondEndP = projectPoint(float3(SECOND_RADIUS * cos(secondAngle), SECOND_RADIUS * sin(secondAngle), 0.0));

                //draw hands
                float hourHand =
                    segmentMask(
                        pixel,
                        centerP.xy,
                        hourEndP.xy,
                        HAND_LINE_WIDTH
                    );

                float minuteHand =
                    segmentMask(
                        pixel,
                        centerP.xy,
                        minuteEndP.xy,
                        HAND_LINE_WIDTH
                    );

                float secondHand =
                    segmentMask(
                        pixel,
                        centerP.xy,
                        secondEndP.xy,
                        HAND_LINE_WIDTH
                    );

                float centerDot =
                    discMask(
                        pixel,
                        centerP.xy,
                        CENTER_RADIUS
                    );

                float hourPoint =
                    discMask(
                        pixel,
                        hourEndP.xy,
                        POINT_RADIUS
                    );

                float minutePoint =
                    discMask(
                        pixel,
                        minuteEndP.xy,
                        POINT_RADIUS
                    );

                float secondPoint =
                    discMask(
                        pixel,
                        secondEndP.xy,
                        POINT_RADIUS * 0.82
                    );

                float3 color = _backgroundColor.rgb;

                
                color = lerp(color, _hourColor.rgb, hourTrail);
                color = lerp(color, _minuteColor.rgb, minuteTrail);
                color = lerp(color, _secondColor.rgb, secondTrail * 0.6);

                //color = lerp(color, _faceColor.rgb, face);
                color = lerp(color, _hourColor.rgb, max(hourHand, hourPoint));
                color = lerp(color, _minuteColor.rgb, max(minuteHand, minutePoint));
                color = lerp(color, _secondColor.rgb, max(secondHand, secondPoint));
                color = lerp(color, _faceColor.rgb, centerDot);

                return half4(color, 1.0);
            }

            ENDHLSL
        }
    }
}
