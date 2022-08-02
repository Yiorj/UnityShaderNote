Shader "Jerry/Jade"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _CubeMap("CubeMap",Cube) = "white"{}
        _BaseColor("BaseColor",Color) = (1,1,1,1)
        
        [Header(NormalDisort)]
        _Disort("Disort",Range(0,1)) = 0.2
        _BackLightPower("BackLightPower",Range(0,20)) = 14
        _BackLightScale("BackLightPower",Range(0,20)) = 1

        _ThicknessMap("Thickness Map",2D) = "black"{}
        _ThicknessIntensity("ThicknessIntensity",Range(0,1)) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            Tags { "LightMode" = "ForwardBase"}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // #pragma multi_compile_fwdbase

            // 将着色器编译成多个有阴影和没有阴影的变体
            //（我们还不关心任何光照贴图，所以跳过这些变体）
            #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
            // 阴影 helper 函数和宏
            // #include "AutoLight.cginc"


            #include "AutoLight.cginc"                // 对于 _LightColor0
            #include "UnityCG.cginc"                  // 对于 UnityObjectToWorldNormal
            #include "UnityLightingCommon.cginc"

            struct appdata
            {
                SHADOW_COORDS(0)
                float4 pos : POSITION;
                float2 uv : TEXCOORD1;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                LIGHTING_COORDS(0,1)
                float2 uv : TEXCOORD2;
                float4 pos : SV_POSITION;
                half4 diff : COLOR0;           //漫反射颜色
                half4 backLight : COLOR1;
                float3 normal_world : TEXCOORD3;
                float3 bioNormal_world : TEXCOORD4;
                float3 tangent_world : TEXCOORD5;
                float3 pos_world : TEXCOORD6;
                float3 view_direction_world : TEXCOORD7;


            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _BaseColor;

            half _BackLightPower;
            half _BackLightScale;
            
            samplerCUBE _CubeMap;
			float4 _CubeMap_HDR;

            half _Disort;

            sampler2D _ThicknessMap;
            half _ThicknessIntensity;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.pos);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                // 在世界空间中获取顶点法线
                // o.normal_world = UnityObjectToWorldNormal(v.normal);
                o.normal_world = normalize(mul(v.normal,(float3x3)unity_WorldToObject));
                // 标准漫射（兰伯特）光照的法线和
                //光线方向之间的点积
                half NdotL = max(0, dot(o.normal_world, _WorldSpaceLightPos0.xyz));
                //光线漫反射
                o.diff =  NdotL * _LightColor0;
                //添加SH光照
                o.diff.rgb += ShadeSH9(half4(o.normal_world,1));

                // 计算阴影数据
                TRANSFER_VERTEX_TO_FRAGMENT(o);

                //计算顶点世界坐标
                // o.pos_world = mul((float3x3)unity_ObjectToWorld,v.pos);
                o.pos_world = mul(unity_ObjectToWorld, v.pos).xyz;
                //计算切线方向\法线

                //视线方向
                o.view_direction_world = normalize(_WorldSpaceCameraPos.xyz - o.pos_world);



                //光源方向
                float3 light_direction = normalize(UnityWorldSpaceLightDir(o.pos_world));
                float3 view_direction = normalize(_WorldSpaceCameraPos.xyz - o.pos_world);
                float3 light_direction_N = - normalize(light_direction + o.normal_world * _Disort);
                float3 VdotL = max(0.0,dot(view_direction, light_direction_N));
                float3 backLight = pow(VdotL,_BackLightPower) * _BackLightScale;

                o.backLight = float4(backLight,1);





                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // 计算阴影衰减（1.0 = 完全照亮，0.0 = 完全阴影）
                fixed shadow = LIGHT_ATTENUATION(i);

                //_ThicknessMap
                float thickness = 1 - tex2D(_ThicknessMap,i.uv) * _ThicknessIntensity;

                // Reflect
                float3 reflect_direction = reflect(-i.view_direction_world,i.normal_world);
                half4 color_cubemap = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0,reflect_direction);
                half4 env_color = float4(DecodeHDR(color_cubemap, _CubeMap_HDR),1.0);//确保在移动端能拿到HDR信息

                //Fresnel 
                float fresnel = 1.0 - max(0.0, dot(i.normal_world, i.view_direction_world));
                fresnel = pow(fresnel,2);
                env_color *= fresnel;

                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv) * i.diff * shadow *_BaseColor + i.backLight * thickness * _BaseColor+ env_color;
                return col;
            }
            ENDCG
        }

        Pass
        {
            Tags { "LightMode" = "ForwardAdd"}

            Blend One One

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdadd

            #include "AutoLight.cginc"                // 对于 _LightColor0
            #include "UnityCG.cginc"                  // 对于 UnityObjectToWorldNormal
            #include "UnityLightingCommon.cginc"


            struct appdata
            {
                SHADOW_COORDS(0)
                float4 pos : POSITION;
                float2 uv : TEXCOORD1;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;

            };

            struct v2f
            {
                // LIGHTING_COORDS(0,1)
                float2 uv : TEXCOORD2;
                float4 pos : SV_POSITION;
                half4 diff : COLOR0;           //漫反射颜色
                half4 backLight : COLOR1;
                float3 normal_world : TEXCOORD3;
                float3 bioNormal_world : TEXCOORD4;
                float3 tangent_world : TEXCOORD5;
                float3 pos_world : TEXCOORD6;
                float3 view_direction_world : TEXCOORD7;


            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _BaseColor;

            half _BackLightPower;
            half _BackLightScale;
            
            samplerCUBE _CubeMap;
			float4 _CubeMap_HDR;

            half _Disort;

            sampler2D _ThicknessMap;
            half _ThicknessIntensity;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.pos);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                // 在世界空间中获取顶点法线
                // o.normal_world = UnityObjectToWorldNormal(v.normal);
                o.normal_world = normalize(mul(v.normal,(float3x3)unity_WorldToObject));
                // 标准漫射（兰伯特）光照的法线和
                //光线方向之间的点积
                half NdotL = max(0, dot(o.normal_world, _WorldSpaceLightPos0.xyz));
                //光线漫反射
                o.diff =  NdotL * _LightColor0;
                //添加SH光照
                o.diff.rgb += ShadeSH9(half4(o.normal_world,1));


                //计算顶点世界坐标
                // o.pos_world = mul((float3x3)unity_ObjectToWorld,v.pos);
                o.pos_world = mul(unity_ObjectToWorld, v.pos).xyz;
                //计算切线方向\法线

                //视线方向
                o.view_direction_world = normalize(_WorldSpaceCameraPos.xyz - o.pos_world);

                



                //光源方向
                float3 light_world_direction = normalize(_WorldSpaceLightPos0.xyz);
                float3 light_world_point = normalize(UnityWorldSpaceLightDir(o.pos_world));
                float3 light_direction =  lerp(light_world_direction,light_world_point,_WorldSpaceLightPos0.w);
                float3 view_direction = normalize(_WorldSpaceCameraPos.xyz - o.pos_world);
                float3 light_direction_N = - normalize(light_direction + o.normal_world * _Disort);
                float3 VdotL = max(0.0,dot(view_direction, light_direction_N));
                float3 backLight = pow(VdotL,_BackLightPower) * _BackLightScale;

                o.backLight = float4(backLight,1);


                
                // // 计算阴影数据
                // TRANSFER_VERTEX_TO_FRAGMENT(o);
                TRANSFER_SHADOW(o);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // 计算阴影衰减（1.0 = 完全照亮，0.0 = 完全阴影）
                fixed shadow = SHADOW_ATTENUATION(i);

                //_ThicknessMap
                float thickness = 1 - tex2D(_ThicknessMap,i.uv) * _ThicknessIntensity;

                //衰减
                float attenuation = 1.0;
                float3 light_world =  _WorldSpaceLightPos0.xyz;
                #if defined(DIRECTIONAL)
                    float3 light_direction = normalize(_WorldSpaceLightPos0.xyz);
                    attenuation = 1.0;    //默认无衰减
                #elif defined(POINT)
                    float3 light_direction = normalize(light_world -i.pos_world);
                    float distance = length(light_world - i.pos_world);
                    //世界/光源矩阵。用于对剪影和衰减纹理进行采样。
                    float range = 1.0 / unity_WorldToLight[0][0];
                    attenuation = (range - distance)/ range;
                #endif


                // sample the texture
                fixed4 col = i.backLight * attenuation * thickness * _BaseColor * _LightColor0;
                return col;
            }
            
            ENDCG
        }


        pass
        {
            //希望通过这个单独的Pass来处理阴影
            Tags{"LightMode" = "ShadowCaster"}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"


            struct v2f
            {
                V2F_SHADOW_CASTER;
            };



            v2f vert(appdata_base v)
            {
                v2f o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;

            }

            fixed4 frag(v2f i):SV_TARGET
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }



        // 实现阴影的最快的一种方法
        // // 通过 VertexLit 内置着色器捕捉阴影投射物
        // UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }
    FallBack "Diffuse"
}
