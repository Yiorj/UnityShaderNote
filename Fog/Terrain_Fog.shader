Shader "Jerry/Terrain_Fog"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "black" {}

        [Toggle]_DistanceFog("_DistanceFog",int) = 1
        [Toggle]_HeightFog("HeightFog",int) = 1
        [Toggle]_SunEffect("SunEffect",int) = 1
        //Fog
        _FogColor("FogColor",Color) = (1,1,1,1)
        _SunColor("SunColor",Color) = (1,1,1,1)
        _SunRadius("SunRadius",Range(0,1))= 0
        _Fog_Start("Fog Start",float) = 0
        _Fog_End("Fog End",float) = 1000
        _Fog_Level("Fog Height",Range(0,1000)) = 120
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            Tags {"LightMode" = "ForwardBase"}
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // 将着色器编译成多个有阴影和没有阴影的变体
            //（我们还不关心任何光照贴图，所以跳过这些变体）
            #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight

            #include "AutoLight.cginc"
            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                SHADOW_COORDS(0)
                float2 uv : TEXCOORD1;
                float4 pos : SV_POSITION;
                float3 diff : TEXCOORD2; //存放SH光照
                float3 normal_world : TEXCOORD3;
                float3 pos_world : TEXCOORD4;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            //Toggle
            int _DistanceFog;
            int _HeightFog;
            int _SunEffect;

            //Fog
            float4 _FogColor;
            float _Fog_Start;
            float _Fog_End;
            float _Fog_Level;
            float _SunRadius;
            float4 _SunColor;

            v2f vert (appdata v)
            {
                v2f o;

                //坐标映射
                o.normal_world = mul(v.normal,(float3x3)unity_WorldToObject);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.pos_world = mul(unity_ObjectToWorld,v.vertex).xyz;
                //SH光照
                //环境光(环境光探针)
                // 除了来自主光源的漫射光照，
                // 还可添加来自环境或光照探针的光照
                // 来自 UnityCG.cginc 的 ShadeSH9 函数使用世界空间法线
                // 对其进行估算
                o.diff.rgb = ShadeSH9(half4(o.normal_world,1));
                //阴影
                TRANSFER_SHADOW(o);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //阴影
                half shadow = SHADOW_ATTENUATION(i);
                //阴影衰减
                //直射光无衰减                

                // sample the texture
                fixed4 col = (tex2D(_MainTex, i.uv) + float4(i.diff,1.0)) * shadow;

                //IBL模拟天空光
                float3 normal = normalize(i.normal_world);
                half3 view_dir = normalize(_WorldSpaceCameraPos.xyz - i.pos_world);
                half3 reflect_dir = reflect(-view_dir,normal);
                half4 color_cubemap = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflect_dir, 9) * float4(i.diff,1.0);

                //实现雾气
                //通用数据
                float3 worldPos = i.pos_world;
                float3 eyePos = _WorldSpaceCameraPos;
                float fog;
                // 1.距离雾
                float fog_Distance;
                float fog_Start = _Fog_Start;
                float fog_End = _Fog_End;
                float distance = length(worldPos - eyePos);
                fog_Distance = clamp(0,1,(distance-fog_Start)/(fog_End-fog_Start));


                
                // 2.高度雾
                float fog_Height;
                float height = worldPos.y;
                float fog_Level = _Fog_Level;
                fog_Height = 1.0 - clamp(0,1,(height)/(fog_Level));
                fog_Height = pow(fog_Height,2);
                
                // 3.根据太阳光方向产生光晕
                float3 lightDir = _WorldSpaceLightPos0;
                float3 viewDir2 = -view_dir;
                float LdotV = max(0.0,dot(lightDir,viewDir2));
                float sunRadius = lerp(500,10,_SunRadius);
                float sunHalo = clamp(0,1,pow(LdotV,sunRadius));

                fog_Distance = lerp(0,fog_Distance,_DistanceFog);
                fog_Height = lerp(0,fog_Height,_HeightFog);
                sunHalo = lerp(0,sunHalo,_SunEffect);

                fog = fog_Distance*(fog_Height + 0.2);
                float4 fogColor = lerp(_FogColor,_SunColor,sunHalo);

                float4 final_color = lerp(color_cubemap,fogColor,fog);


                return final_color;
            }
            ENDCG
        }
        Pass
        {
            Tags {"LightMode" = "ForwardAdd"}
            Blend One One
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdadd
            // 将着色器编译成多个有阴影和没有阴影的变体
            //（我们还不关心任何光照贴图，所以跳过这些变体）
            // #pragma multi_compile_fwdadd nolightmap nodirlightmap nodynlightmap novertexlight

            #include "AutoLight.cginc"
            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                SHADOW_COORDS(0)
                float2 uv : TEXCOORD1;
                float4 pos : SV_POSITION;
                float3 pos_world : TEXCOORD2;
                float3 normal_world : TEXCOORD3;
                float4 LightCoord : TEXCOORD4;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                
                //坐标映射
                o.pos_world = mul(unity_ObjectToWorld,v.vertex).xyz;
                o.normal_world = mul(v.normal,(float3x3)unity_WorldToObject);
                #if defined(SPOT)
                    o.LightCoord = mul(unity_WorldToLight, mul(unity_ObjectToWorld, v.vertex));
                #endif

                //阴影
                TRANSFER_SHADOW(o);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //阴影
                half shadow = SHADOW_ATTENUATION(i);
                
                //衰减
                float attenuation;
                #if defined(DIRECTIONAL)
                    attenuation = 1;
                #elif defined(POINT)
                    // 1/unity_WorldToLight[0][0]  即为点光的范围值；
                    float rangeMax = 1/unity_WorldToLight[0][0];
                    attenuation = 1.0 - pow(saturate(distance(i.pos_world,_WorldSpaceLightPos0.xyz) / rangeMax),2);
                #elif defined(SPOT)
                    float4 lightCoord = i.LightCoord;
                    attenuation = (lightCoord.z > 0) * tex2D(_LightTextureB0,dot(lightCoord,lightCoord).xx).r * tex2D(_LightTexture0, lightCoord.xy / lightCoord.w + 0.5).w;
                #endif
                
                //阴影衰减
                shadow *= attenuation ;

                //Phong光照模型
                //1.漫反射
                float3 light_direction = UnityWorldSpaceLightDir(i.pos_world);
                float3 normal_Phong = normalize(i.normal_world);
                float NdotL = dot(normal_Phong, light_direction);
                NdotL = min(shadow, NdotL);
                float4 Diffuse = max(0.0,NdotL) * _LightColor0;

                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv) * shadow;
                return Diffuse;
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}
