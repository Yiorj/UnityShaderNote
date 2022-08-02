Shader "Jerry/Phong4"
//實現陰影的效果
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}

        _NormalMap("Normap",2D) = "bump"{}
        _NormalIntensity("NormalIntensity",Range(0,4)) = 1

        _AO("AO Texture",2D) = "blakc"{}
        _SpecMask("SpecMask",2D)  = "black"{}

        _HeightMap("HeightMap(视差偏移）",2D) = "black"{}
        _Parallax("_Parallax",float) = 0.1
        _HeightInteraction("迭代次数",int) = 3
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            //申明光照模型类型
            Tags{"LightMode" = "ForwardBase"}
            //在ForwardBase的pass当中只对主光源饥和光源数量之外的光源进行计算


            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            //申明光照模式
            #pragma multi_compile_fwdbase
            #include "AutoLight.cginc"

            //光源颜色引用
            #include "UnityLightingCommon.cginc"

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float3 normal_world : TEXCOORD1;
                float3 position_world : TEXCOORD2;
                float3 bionormal_world : TEXCOORD3;
                float3 tangent_world : TEXCOORD4;
                SHADOW_COORDS(5)
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler2D _NormalMap;
            float _NormalIntensity;

            sampler2D _AO;
            sampler2D _SpecMask;

            sampler2D _HeightMap;
            float _Parallax;
            float _HeightInteraction;


            half2 ParallaxBump(half2 uv_parallax,sampler2D HeightMap,half2 uv,int itr,float3 view_tangentSpace)
            {
                //视差偏移函数
                //输入初始值，高度图，uv值，迭代次数和切线空间下的视线向量
                //得到偏移后的UV值
                uv_parallax = uv;
                for(int i = 0; i <= itr; i ++)
                {
                    float height = tex2D(HeightMap,uv_parallax);
                    uv_parallax = uv_parallax - (0.5 - height) * view_tangentSpace.xy * _Parallax;
                }
                return uv_parallax;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal_world = normalize(mul(float4(v.normal,0.0),unity_WorldToObject).xyz);
                o.position_world = mul(unity_ObjectToWorld,v.vertex).xyz;

                //法线贴图
                o.tangent_world = normalize(mul(unity_ObjectToWorld,float4(v.tangent.xyz,0.0)).xyz);
                //v.tangent.w 可以修复不同平台法线反转的问题
                o.bionormal_world = normalize(cross(o.normal_world, o.tangent_world)) * v.tangent.w; 

                //阴影
                TRANSFER_SHADOW(o);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //阴影
                half shadow = SHADOW_ATTENUATION(i);

                //通用数据
                half3 normal_dir = normalize(i.normal_world);
                half3 bionormal_dir = normalize(i.bionormal_world);
                half3 tangent_dir = normalize(i.tangent_world);
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.position_world);
                //世界空间方向 方向光0,其他光源1
                float3 light_world =  _WorldSpaceLightPos0.xyz;
                float3 light_direction = normalize(light_world);

                //视线偏移（制造假Bump效果）
                float3x3 TBN = float3x3(tangent_dir,bionormal_dir,normal_dir);
                half3 view_tangentSpace = normalize(mul(TBN,viewDir));
                
                int itr = _HeightInteraction;
                half2 uv_parallax = ParallaxBump(uv_parallax,_HeightMap,i.uv,itr,view_tangentSpace);  //自定义函数


                //实现法线贴图
                float4 normalMap = tex2D(_NormalMap, uv_parallax);
                float3 normalData = UnpackNormal(normalMap);
                normalData.xy *= _NormalIntensity;

                float3 finalNormal = tangent_dir * normalData.x + bionormal_dir * normalData.y + normal_dir * normalData.z;
                finalNormal = normalize(finalNormal);

                

                // sample the texture
                half4 basecCol = tex2D(_MainTex, uv_parallax);
                half4 aoCol = tex2D(_AO,uv_parallax);
                half4 speCol = tex2D(_SpecMask,uv_parallax);
                // speCol *= basecCol;

                //Phong光照模型
                //计算公式
                //1.漫反射
                float3 normal_Phong = finalNormal;
                float NdotL = dot(normal_Phong, light_direction);
                NdotL = min(shadow, NdotL);
                float4 phongDiffuse = max(0.0,NdotL) * _LightColor0 * basecCol;

                //2. 反射
                // float3 reflect_Dir = reflect(-light_direction, normal_Phong);
                // float RdotV = dot(reflect_Dir,viewDir);
                // float4 phongSpecular = pow(max(0.0,RdotV),10) * _LightColor0;

                //2-1 BlinPhong 反射
                float3 half_dir = normalize(light_direction + viewDir);
                half NdotH = dot(normal_Phong,half_dir);
                float4 phongSpecular = min(pow(max(0.0,NdotH),10),speCol) * _LightColor0;
                // return speCol;

                phongSpecular.w = 1;


                half3 finalCol = (phongDiffuse + phongSpecular  + unity_AmbientSky.rgb)*aoCol;
                half alpha = 1;

                return float4(finalCol, alpha);
            }
            ENDCG
        }

        Pass
        {
            //申明光照模型类型
            Tags{"LightMode" = "ForwardAdd"}
            //在ForwardBase的pass当中只对主光源饥和光源数量之外的光源进行计算

            Blend One One

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            //申明光照模式
            #pragma multi_compile_fwdadd
            #include "AutoLight.cginc"

            //光源颜色引用
            #include "UnityLightingCommon.cginc"

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float3 normal_world : TEXCOORD1;
                float3 position_world : TEXCOORD2;
                float3 bionormal_world : TEXCOORD3;
                float3 tangent_world : TEXCOORD4;
                // SHADOW_COORDS(5)
                LIGHTING_COORDS(5,6)
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler2D _NormalMap;
            float _NormalIntensity;

            sampler2D _AO;
            sampler2D _SpecMask;

            sampler2D _HeightMap;
            float _Parallax;
            float _HeightInteraction;


            half2 ParallaxBump(half2 uv_parallax,sampler2D HeightMap,half2 uv,int itr,float3 view_tangentSpace)
            {
                //视差偏移函数
                //输入初始值，高度图，uv值，迭代次数和切线空间下的视线向量
                //得到偏移后的UV值
                uv_parallax = uv;
                for(int i = 0; i <= itr; i ++)
                {
                    float height = tex2D(HeightMap,uv_parallax);
                    uv_parallax = uv_parallax - (0.5 - height) * view_tangentSpace.xy * _Parallax;
                }
                return uv_parallax;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal_world = normalize(mul(float4(v.normal,0.0),unity_WorldToObject).xyz);
                o.position_world = mul(unity_ObjectToWorld,v.vertex).xyz;

                //法线贴图
                o.tangent_world = normalize(mul(unity_ObjectToWorld,float4(v.tangent.xyz,0.0)).xyz);
                //v.tangent.w 可以修复不同平台法线反转的问题
                o.bionormal_world = normalize(cross(o.normal_world, o.tangent_world)) * v.tangent.w; 

                //阴影
                // TRANSFER_SHADOW(o);
                TRANSFER_VERTEX_TO_FRAGMENT(o);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //阴影
                half shadow = LIGHT_ATTENUATION(i);

                //通用数据
                half3 normal_dir = normalize(i.normal_world);
                half3 bionormal_dir = normalize(i.bionormal_world);
                half3 tangent_dir = normalize(i.tangent_world);
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.position_world);
                //世界空间方向 方向光0,其他光源1
                float3 light_world_direction = normalize(_WorldSpaceLightPos0.xyz);
                // float3 light_world_point = normalize(_WorldSpaceLightPos0.xyz - i.position_world);
                float3 light_world_point = UnityWorldSpaceLightDir(i.position_world);
                
                float3 light_direction = lerp(light_world_direction,light_world_point,_WorldSpaceLightPos0.w);

                //视线偏移（制造假Bump效果）
                float3x3 TBN = float3x3(tangent_dir,bionormal_dir,normal_dir);
                half3 view_tangentSpace = normalize(mul(TBN,viewDir));
                
                int itr = _HeightInteraction;
                half2 uv_parallax = ParallaxBump(uv_parallax,_HeightMap,i.uv,itr,view_tangentSpace);  //自定义函数


                //实现法线贴图
                float4 normalMap = tex2D(_NormalMap, uv_parallax);
                float3 normalData = UnpackNormal(normalMap);
                normalData.xy *= _NormalIntensity;

                float3 finalNormal = tangent_dir * normalData.x + bionormal_dir * normalData.y + normal_dir * normalData.z;
                finalNormal = normalize(finalNormal);

                

                // sample the texture
                half4 basecCol = tex2D(_MainTex, uv_parallax);
                half4 aoCol = tex2D(_AO,uv_parallax);
                half4 speCol = tex2D(_SpecMask,uv_parallax);
                // speCol *= basecCol;

                //Phong光照模型
                //计算公式
                //1.漫反射
                float3 normal_Phong = finalNormal;
                float NdotL = dot(normal_Phong, light_direction);
                NdotL = min(shadow, NdotL);
                float4 phongDiffuse = max(0.0,NdotL) * _LightColor0 * basecCol;

                //2. 反射
                // float3 reflect_Dir = reflect(-light_direction, normal_Phong);
                // float RdotV = dot(reflect_Dir,viewDir);
                // float4 phongSpecular = pow(max(0.0,RdotV),10) * _LightColor0;

                //2-1 BlinPhong 反射
                float3 half_dir = normalize(light_direction + viewDir);
                half NdotH = dot(normal_Phong,half_dir);
                float4 phongSpecular = min(pow(max(0.0,NdotH),10),speCol) * _LightColor0;
                // return speCol;

                phongSpecular.w = 1;


                half3 finalCol = (phongDiffuse + phongSpecular)*aoCol;
                half alpha = 1;

                return float4(finalCol, alpha);
            }
            ENDCG
        }
    }
    
    Fallback "Diffuse"
}
