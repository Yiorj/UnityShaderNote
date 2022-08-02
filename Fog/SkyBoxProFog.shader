Shader "Jerry/SkyBoxProFog"
{
    Properties
    {
        [Enum(UnityEngine.Rendering.CullMode)]_CullMode("CullMode",int) = 0
        _MainTex ("Texture", 2D) = "white" {}

        [Header(fog)]
        _FogColor("FogColor",Color) = (1,1,1,1)
        _Fog_Level("Fog Height",Range(0,1000)) = 120

    }
    SubShader
    {
        Tags { "Queue"="Background" }
        LOD 100

        Pass
        {
            Cull [_CullMode]
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 pos_world : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _Fog_Level;
            float4 _FogColor;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.pos_world = mul(unity_ObjectToWorld,v.vertex).xyz;

                //修改裁剪距离
                #if UNITY_REVERSED_Z
                    o.vertex.z = o.vertex.w * 0.000001f;
                #else
                    o.vertex.z = o.vertex.w * 0.999999f;
                #endif


                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //Fog
                float3 worldPos = i.pos_world;
                float fog_Height;
                float height = worldPos.y;
                float fog_Level = _Fog_Level;
                fog_Height = 1.0 - clamp(0,1,(height)/(fog_Level));
                fog_Height = pow(fog_Height,2);

                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);

                fixed4 finalColor = lerp(col,_FogColor,fog_Height);

                return finalColor;
            }
            ENDCG
        }
    }
}
