Shader "shader lab/week 9/IBL metallic" {
    Properties {
        _albedo ("albedo", 2D) = "white" {}
        [NoScaleOffset] _normalMap ("normal map", 2D) = "bump" {}
        [NoScaleOffset] _displacementMap ("displacement map", 2D) = "gray" {}
        [NoScaleOffset] _roughnessMap ("roughness map", 2D) = "white" {}
        [NoScaleOffset] _metallicMap ("metallic map", 2D) = "black" {}
        [NoScaleOffset] _IBL ("IBL cube map", Cube) = "black" {}

        // brightness of specular reflection - proportion of color contributed by diffuse and specular
        // reflectivity at 1, color is all specular
        _reflectivity ("reflectivity", Range(0,1)) = 0.5
        _fresnelPower ("fresnel power", Range(0, 10)) = 5
        _normalIntensity ("normal intensity", Range(0, 1)) = 1
        _displacementIntensity ("displacement intensity", Range(0, 0.5)) = 0
    }
    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #define DIFFUSE_MIP_LEVEL 5
            #define SPECULAR_MIP_STEPS 4
            #define MAX_SPECULAR_POWER 256
            
            CBUFFER_START(UnityPerMaterial)
            float _reflectivity;
            float _normalIntensity;
            float _displacementIntensity;
            float _fresnelPower;
            float4 _albedo_ST;
            CBUFFER_END

            TEXTURE2D(_albedo);
            SAMPLER(sampler_albedo);

            TEXTURE2D(_normalMap);
            SAMPLER(sampler_normalMap);

            TEXTURE2D(_displacementMap);
            SAMPLER(sampler_displacementMap);

            TEXTURE2D(_roughnessMap);
            SAMPLER(sampler_roughnessMap);
            
            TEXTURE2D(_metallicMap);
            SAMPLER(sampler_metallicMap);
            
            TEXTURECUBE(_IBL);
            SAMPLER(sampler_IBL);
            
            struct MeshData {
                float4 vertex : POSITION;
                float3 normal : NORMAL;

                // xyz is the tangent direction, w is the tangent sign
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float3 tangent : TEXCOORD2;
                float3 bitangent : TEXCOORD3;
                float3 worldPos : TEXCOORD4;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.uv = TRANSFORM_TEX(v.uv, _albedo);
                
                float height = SAMPLE_TEXTURE2D_LOD(_displacementMap, sampler_displacementMap, o.uv, 0).r;
                v.vertex.xyz += v.normal * height * _displacementIntensity;

                o.normal = TransformObjectToWorldNormal(v.normal);
                o.tangent = TransformObjectToWorldNormal(v.tangent);
                o.bitangent = cross(o.normal, o.tangent) * v.tangent.w;
                
                o.vertex = TransformObjectToHClip(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                
                return o;
            }

            // sample our normal map and transform it from tangent to object space
            float3 get_normal (Interpolators i) {
                float3 vNormal = normalize(i.normal);
                float3 tsNormal = UnpackNormal(SAMPLE_TEXTURE2D(_normalMap, sampler_normalMap, i.uv));
                tsNormal = normalize(lerp(float3(0, 0, 1), tsNormal, _normalIntensity));
                
                return i.tangent * tsNormal.x + i.bitangent * tsNormal.y + vNormal * tsNormal.z;
            }

            // function to claculate direct diffuse and direct specular falloff
            // r: diffuse falloff
            // g: specular falloff
            float2 lighting_falloff (Interpolators i, float3 normal, float roughness) {
                Light light = GetMainLight();
                
                float3 viewDirection = normalize(GetCameraPositionWS() - i.worldPos);
                float3 halfDirection = normalize(viewDirection + light.direction);

                float directDiffuse = max(0, dot(normal, light.direction));
                float directSpecular = max(0, dot(normal, halfDirection));
                float gloss = 1-roughness;
                directSpecular = pow(directSpecular, gloss * MAX_SPECULAR_POWER + 1) * gloss;

                return float2(directDiffuse, directSpecular);
            }

            float4 frag (Interpolators i) : SV_Target {
                float3 color = 0;
                float3 normal = get_normal(i);
                float roughness = 1;

                roughness = SAMPLE_TEXTURE2D(_roughnessMap, sampler_roughnessMap, i.uv).r;
                
                float2 directFalloff = lighting_falloff(i, normal, roughness);
                float directDiffuseFalloff  = directFalloff.r;
                float directSpecularFalloff = directFalloff.g;
                
                // INDIRECT DIFFUSE
                float3 indirectDiffuse = SAMPLE_TEXTURECUBE_LOD(_IBL, sampler_IBL, normal, DIFFUSE_MIP_LEVEL);
                
                // INDIRECT SPECULAR
                float3 viewDirection = normalize(GetCameraPositionWS() - i.worldPos);
                float3 viewReflection = reflect(-viewDirection, normal);

                // gloss value corresponds to how smooth or rough a surface is
                // the smoother the surface the sharper the specular reflection
                float mip = roughness * SPECULAR_MIP_STEPS;
                float3 indirectSpecular = SAMPLE_TEXTURECUBE_LOD(_IBL, sampler_IBL, viewReflection, mip);
                
                float3 albedo = SAMPLE_TEXTURE2D(_albedo, sampler_albedo, i.uv);
                
                float fresnel = 1 - saturate(dot(viewDirection, normal));
                fresnel = pow(fresnel, _fresnelPower);
                
                
                
                // METALLIC LOGIC
                // in truth metallic is 0 or 1, either a metal or dielectric, but a map allows us to show metal with rust, or dirt or other surface conditions
                float3 metallic = SAMPLE_TEXTURE2D(_metallicMap, sampler_metallicMap, i.uv);
                
                // dielectrics: weak reflection that grows at grazing angles
                // metals: strong reflection at every angle
                float reflectivity = lerp(_reflectivity * fresnel, 1, metallic);
                
                // metals have no diffuse component - free electrons absorb refracted light into the surface, that would normally scatter out for dielectrics as the diffuse component
                // metals have a reflectivity of 1 so this line below will zero out the albedo color for metals
                float3 surfaceColor = albedo * (1 - reflectivity);
                
                // metallic reflections take on the color of the albedo, technically dielectrics do too, but they're effected so little we tend to use white 
                float3 specularColor = lerp(1, albedo, metallic);
                
                // reflectivity of all wavelengths approaches 100% at grazing angles so metallic specular color moves toward white
                specularColor = lerp(specularColor, 1, fresnel * metallic);
                
                
                
                
                Light light = GetMainLight();
                float3 diffuse = surfaceColor * (directDiffuseFalloff * light.color + indirectDiffuse);

                float3 directSpecular = light.color * directSpecularFalloff;
                float3 specular = (directSpecular + indirectSpecular * reflectivity) * specularColor;
                
                color = diffuse + specular;
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}