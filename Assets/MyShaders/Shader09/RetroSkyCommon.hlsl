#ifndef RETRO_COSMIC_SKY_COMMON_INCLUDED
#define RETRO_COSMIC_SKY_COMMON_INCLUDED


float2 RetroVortex(float3 d, float3 axis, float t, float ringFrequency, float spin)
{
    float3 right = normalize(cross(float3(0.0, 1.0, 0.0), axis));
    float3 up = cross(axis, right);

    float2 p = float2(dot(d, right), dot(d, up));
    float r = length(p);
    float a = atan2(p.y, p.x);

    float phase = ringFrequency * r + 3.0 * a + 1.4 * sin(8.0 * r - 0.20 * t) - spin * t;
    float s = 0.5 + 0.5 * sin(phase);

    float front = smoothstep(0.06, 0.52, dot(d, axis));
    float fade = (1.0 - smoothstep(0.35, 0.98, r)) * front;

    float thinLine = pow(saturate(s), 11.0) * fade;
    float softRibbon = smoothstep(0.34, 0.86, s) * fade;
    return float2(thinLine, softRibbon);
}

float RetroStar(float3 d)
{
    float3 q = d * 102.0;
    float3 cell = floor(q);
    float3 offset = frac(q) - 0.5;
    float hash = frac(sin(dot(cell, float3(127.1, 311.7, 74.7))) * 43758.5453);
    float isolated = smoothstep(0.997, 1.0, hash);
    float starSpot = pow(saturate(1.0 - length(offset) * 1.9), 20.0);
    return isolated * starSpot;
}

float3 RetroSkyColor(
    float3 direction,
    float timeSeconds,
    float3 deepColor,
    float3 highColor,
    float3 ribbonColor,
    float3 accentColor,
    float swirlStrength,
    float speed,
    float exposure)
{
    float3 d = normalize(direction);
    float t = timeSeconds * speed;

    float skyGradient = smoothstep(-0.85, 0.9, d.y);
    float3 color = lerp(deepColor, highColor, skyGradient);

    float cloudPhase = 5.8 * d.x + 3.5 * d.y - 2.8 * d.z
                     + 1.2 * sin(4.2 * d.z - 0.12 * t) + 0.10 * t;
    float cloud = smoothstep(0.05, 0.97, 0.5 + 0.5 * sin(cloudPhase));
    color += highColor * (cloud * 0.35);

    float3 axisA = normalize(float3(-0.23, 0.35, 1.0));
    float3 axisB = normalize(float3( 0.88,-0.27, 0.62));

    float2 vortexA = RetroVortex(d, axisA, t, 22.0, 0.75);
    float2 vortexB = RetroVortex(d, axisB, t, 18.0,-0.42);

    color += swirlStrength * ribbonColor * (1.70 * vortexA.x + 0.27 * vortexA.y);
    color += swirlStrength * accentColor * (1.15 * vortexB.x + 0.22 * vortexB.y);

    float coreGlow = pow(saturate(dot(d, axisA)), 22.0);
    color += ribbonColor * (0.26 * coreGlow);

    float stars = RetroStar(d);
    color += stars * float3(1.2, 1.5, 2.2);

    return max(color * exposure, float3(0.0, 0.0, 0.0));
}

#endif
