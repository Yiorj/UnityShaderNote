Shader "Jerry/Disort"
{
    Properties
    {
        _MainTex ("MainTexture", 2D) = "white" {}
        _NoiseTex("Noise",2D) = "white"{}
        _RampTex("RampTex",2D) = "white"{}
        _MainColor("MainColor",Color) = (0.8,0.6,0.35,1)
        _Intensity("Intensity",Range(0,40)) = 1
        _noiseIntensity("NoiseStength",Range(0,1)) = 0.1


        [Header(Disorted)]
        [Toggle]_Animate("Animate",int) = 0
        _Clip("Clip",Range(0,1)) = 0
        _DisortEdge("DiesortEdge",Range(0,1)) = 0.4

        
        //FireSpeed
        [Header(Speed)]
        _FireSpeed("FireSpeed",float) = 0.5


        //Gradient Intensity
        _GradientPower("GradientPower",Range(0,10)) = 5

        //控制GradientMode的模式
        [Header(Gradient Mode)]
        [Enum(UV,0,WorldPos,1,sphere,2)]_GradientMode("GradientMode",int) = 0
        _ModelHeight("ModelHeight",float) = 0
    }
    SubShader
    {
        Tags { "Queue" = "Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _ANIMATE_ON
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float2 uv_Noise : TEXCOORD1;
                float4 vertex : SV_POSITION;

                //存储顶点的世界坐标
                float3 position_world : TEXCOORD2;
                float3 pivot_world : TEXCOORD3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            //Color
            fixed4 _MainColor;
            float _Intensity;

            //noise
            sampler2D _NoiseTex;
            float4 _NoiseTex_ST;
            float _noiseIntensity;

            //fire Speed
            float _FireSpeed;

            //clip
            float _Clip;

            //_Mask
            sampler2D _RampTex;

            //gradient
            float _GradientPower;
            int _GradientMode;

            //Disort Edge
            float _DisortEdge;

            //ModelHeight
            float _ModelHeight;


            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.uv_Noise = TRANSFORM_TEX(v.uv, _NoiseTex) + _Time.y * float2(0,-_FireSpeed);

                //将顶点和轴心转换到世界坐标
                o.position_world = mul(unity_ObjectToWorld,v.vertex);
                o.pivot_world = mul(unity_ObjectToWorld,float4(0,0,0,1));

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);

                //边缘噪波
                float2 noise = tex2D(_NoiseTex,i.uv_Noise);

                float alpha = col.w;

                //利用UV生成一张渐变图
                float gradient;
                if(_GradientMode == 0)
                {
                    // UV模式
                    gradient = i.uv.y;
                }else if(_GradientMode == 1)
                {
                    // 世界坐标模式
                    float worldPosition = (i.position_world - i.pivot_world).y;
                    //这里模型的轴心是在中心点，所以用顶点坐标Y减去中点坐标Y后，
                    //加上一般的高度后，再除以模型高度来归一化UV坐标
                    gradient = (worldPosition + (0.5 * _ModelHeight))/_ModelHeight;
                }else
                {
                    //世界坐标圆形反射
                    float3 worldPosition3 = (i.position_world - i.pivot_world).xyz;
                    gradient = length(worldPosition3) / _ModelHeight;
                }
                ;

                float disort = 1.5 * _Clip;
                #if _ANIMATE_ON
                    disort = (_SinTime.y+1)/2*1.5;
                #endif
                gradient += .5;
                gradient -= disort;
                gradient -= noise * _noiseIntensity;
                gradient *= _GradientPower;
                
                // gradient /= _DesortEdge;
                
                //计算衰减范围
                float gradientEdge = distance(gradient,0) / _DisortEdge;
                gradientEdge = 1-gradientEdge;
                gradientEdge = saturate(gradientEdge);

                gradient = smoothstep(0,1,gradient);

                
                //求溶解边缘的颜色
                //利用边缘渐变graidentEdge来采样边缘颜色
                float4 edgeColor = tex2D(_RampTex,1 - gradientEdge);
                edgeColor *= _Intensity;

                
                col = lerp(col,edgeColor,gradientEdge);


                //Mask,利用noise来扰动mask的边缘


                //设置透明度
                alpha *= gradient;


                return float4(col.rgb, alpha);
            }
            ENDCG
        }
    }
}
