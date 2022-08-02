Shader "Jerry/IBL_Probe"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}

        _MainColor("MainColor",Color) = (1,1,1,1)

        _CubeMap("CubeMap",Cube) = "white"{}


        _Roughness("Roughness",2D) = "white"{}
		_RoughnessMin("Rough Min",Range(0,1)) = 0
		_RoughnessMax("Rough Max",Range(0,1)) = 1
		_RoughnessBrightness("Roughness Brightness",Range(0,3)) = 1
        _NormalMap("NormalMap",2D) = "bump"{}
    }
    SubShader
    {
        
        Tags { "RenderType"="Opaque" }

        Pass
        {
            Tags{"LightMode" = "ForwardBase"}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            //申明光照模式
            #pragma multi_compile_fwdbase
            #include "AutoLight.cginc"
            #include "UnityLightingCommon.cginc"

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                SHADOW_COORDS(0)
                float2 uv : TEXCOORD1;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                LIGHTING_COORDS(0,1)
                float2 uv : TEXCOORD2;
                float4 pos : SV_POSITION;
                float3 normal_world : TEXCOORD3;
                float3 pos_world : TEXCOORD4;
                float3 tangent_world : TEXCOORD5;
                float3 bioNormal_world : TEXCOORD6;
                float3 diff : TEXCOORD7;

            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            float4 _MainColor;

            samplerCUBE _CubeMap;
			float4 _CubeMap_HDR;

            sampler2D _NormalMap;


            sampler2D _Roughness;
            half _RoughnessMin;
            half _RoughnessMax;
            half _RoughnessContrast;
            half _RoughnessBrightness;


            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                //计算世界坐标
				o.pos_world = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.normal_world = normalize(mul(float4(v.normal, 0.0), unity_WorldToObject)).xyz;
                o.tangent_world = normalize(mul(unity_ObjectToWorld,float4(v.tangent.xyz,0.0))).xyz;
                o.bioNormal_world = normalize(cross(o.tangent_world,o.normal_world)*v.tangent.w);
                //阴影
                TRANSFER_VERTEX_TO_FRAGMENT(o);

                //环境光(环境光探针)
                // 除了来自主光源的漫射光照，
                // 还可添加来自环境或光照探针的光照
                // 来自 UnityCG.cginc 的 ShadeSH9 函数使用世界空间法线
                // 对其进行估算

                o.diff.rgb = ShadeSH9(half4(o.normal_world,1));

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //阴影
                half shadow = LIGHT_ATTENUATION(i);

                //通用数据
                //0. 法线
                float3 normal_world = normalize(i.normal_world);
                float3 bioNormal_world = normalize(i.bioNormal_world);
                float3 tangent_world = normalize(i.tangent_world);
                //1.光源 ：世界空间方向 方向光0,其他光源1
                float3 light_direction = normalize(UnityWorldSpaceLightDir(i.pos_world));
                //2.相机(人眼)到顶点的向量
                half3 view_dir = normalize(_WorldSpaceCameraPos.xyz - i.pos_world);
            
                //计算法线贴图
                float3 normalData = UnpackNormal(tex2D(_NormalMap,i.uv));
                float3 postedNormal = tangent_world * normalData.x + bioNormal_world* normalData.y + 
                normal_world * normalData.z;

                

                
                // sample the texture
                float3 normal = postedNormal;
                half3 reflect_dir = reflect(-view_dir,normal);
                fixed4 col = tex2D(_MainTex, i.uv);

                half roughness = tex2D(_Roughness,i.uv);
                roughness = saturate(roughness * _RoughnessBrightness);
                roughness = roughness * (1.7 - 0.7 * roughness);
                roughness = lerp(_RoughnessMin*6,_RoughnessMax*6,roughness);

                //使用Probe探针的话,需要用到Unity内置变量unity_specCube0
                // sample the default reflection cubemap, using the reflection vector
				// half4 color_cubemap = texCUBElod(_CubeMap, float4(reflect_dir,roughness));
                half4 color_cubemap = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflect_dir, roughness);
                
				half3 env_color = DecodeHDR(color_cubemap, _CubeMap_HDR);//确保在移动端能拿到HDR信息
                


                //光线计算
                float3 normal_Phong = postedNormal;
                float NdotL = dot(normal_Phong, light_direction);
                NdotL = min(shadow, NdotL);

                float4 Diffuse = max(0.0,NdotL) * _LightColor0 * float4(env_color,1.0) * _MainColor + unity_AmbientSky + float4(i.diff,1);

                half alpha = 1;
                return float4(Diffuse.rgb,alpha);
            }
            ENDCG
        }

        // Pass
        // {
        //     Tags{"LightMode" = "ForwardAdd"}

        //     blend One One

        //     CGPROGRAM
        //     #pragma vertex vert
        //     #pragma fragment frag
            
        //     //申明光照模式
        //     #pragma multi_compile_fwdadd
        //     #include "AutoLight.cginc"
        //     #include "UnityLightingCommon.cginc"

        //     #include "UnityCG.cginc"

        //     struct appdata
        //     {
        //         float4 vertex : POSITION;
        //         SHADOW_COORDS(0)
        //         float2 uv : TEXCOORD1;
        //         float3 normal : TEXCOORD2;
        //     };

        //     struct v2f
        //     {
        //         float2 uv : TEXCOORD0;
        //         float4 pos : SV_POSITION;
        //         float3 normal_world : TEXCOORD1;
        //         float3 position_world : TEXCOORD2;
        //         LIGHTING_COORDS(3,4)
        //     };

        //     sampler2D _MainTex;
        //     float4 _MainTex_ST;

        //     v2f vert (appdata v)
        //     {
        //         v2f o;
        //         o.pos = UnityObjectToClipPos(v.vertex);
        //         o.uv = TRANSFORM_TEX(v.uv, _MainTex);

        //         //计算世界坐标
        //         o.normal_world = normalize(mul(float4(v.normal,0.0),unity_WorldToObject).xyz);
        //         o.position_world = mul(unity_ObjectToWorld,v.vertex).xyz;

                
        //         //阴影
        //         TRANSFER_SHADOW(o);
        //         return o;
        //     }

        //     fixed4 frag (v2f i) : SV_Target
        //     {
        //         //阴影
        //         half shadow = LIGHT_ATTENUATION(i);
                
        //         //通用数据
        //         //世界空间方向 方向光0,其他光源1
        //         float3 light_direction = UnityWorldSpaceLightDir(i.position_world);

                
        //         //光线计算
        //         float3 normal_Phong = i.normal_world;
        //         float NdotL = dot(normal_Phong, light_direction);
        //         NdotL = min(shadow, NdotL);
        //         float4 Diffuse = max(0.0,NdotL) * _LightColor0;
        //         half alpha = 1;

        //         return float4(Diffuse.xxx,alpha);
        //     }
        //     ENDCG
        // }
    }
    //使用
    Fallback "Diffuse"
}
