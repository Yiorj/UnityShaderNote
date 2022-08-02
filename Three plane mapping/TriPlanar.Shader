Shader "Jery/TriPlanar"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _TriTest("TriTest",float) = 5
        _TriOffset("_TriOffset",Range(0,50)) = 0.1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 pos_world : TEXCOORD1;
                float3 normal_world : TEXCOORD2;
                float3 pivot_world : TEXCOORD3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            float _TriTest;
            float _TriOffset;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                o.pos_world = mul(unity_ObjectToWorld,v.vertex).xyz;
                
                o.normal_world = normalize(mul(float4(v.normal,0.0),unity_WorldToObject)).xyz;

                o.pivot_world = mul(unity_ObjectToWorld,float4(0,0,0,1)).xyz;

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //三平面映射 使用世界坐标的三个方向对纹理进行采样最后融合的技术
                //1. 世界空间位置
                float3 pos_world = i.pos_world - i.pivot_world;
                float2 triPlannerXY = pos_world.xy * _TriOffset;
                float2 triPlannerXZ = pos_world.xz * _TriOffset;
                float2 triPlannerYZ = pos_world.yz * _TriOffset;
                //2. 世界法线
                float3 normal_world = normalize(i.normal_world);
                normal_world.x = abs(normal_world.x);
                normal_world.y = abs(normal_world.y);
                normal_world.z = abs(normal_world.z);
                normal_world = pow(normal_world,_TriTest) / (normal_world.x+normal_world.y+normal_world.z);

                //采样
                sampler2D triPlannerTex = _MainTex;
                float4 triPlannerCol = (tex2D(triPlannerTex,triPlannerXY) * normal_world.z  
                + tex2D(triPlannerTex,triPlannerXZ) * normal_world.y 
                + tex2D(triPlannerTex,triPlannerYZ) * normal_world.x);

                return triPlannerCol;
            }
            ENDCG
        }
    }
}
