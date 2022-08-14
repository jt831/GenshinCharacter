Shader "GenshinCharacter"
{
    Properties
    {
        [Header(Model)]
        [Space(5)]
        [Toggle(SHOW_RAMP_COLOR)] _ShowRampColor("Ramp Color", float) = 1
        [Space(20)]

        [Header(Main Texture)]
        [Space(5)]
        [MainTexture] _BaseMap("BaseMap", 2D) = "white" { }
        [HDR][MainColor] _BaseColor("BaseColor", Color) = (1.0, 1.0, 1.0, 1.0)
        [Toggle(ENABLE_SHADOW)] _EableShadow("Enable Shadow", float) = 1
        [Space(20)]

        [Header(LightMap)]
        [Space(5)]
        _LightMap("LightMap", 2D) = "grey" { }
        _ShadowColor("Shadow Color", Color) = (0.6, 0.6, 0.6, 1.0)
        [Space(20)]

        [Header(Shadow Ramp)]
        [Space(5)]
        [Toggle(ENABLE_RAMP_SHADOW)] _EnableRampShadow("Enable Ramp Shadow", float) = 1
        _RampMap("RampMap", 2D) = "black" { }
        _TimeOneDay("Time", range(0, 1)) = 1.0
        _ShadowArea("ShadowArea", range(0, 1)) = 0.5
        _RampShadowArea("Ramp Shadow Area", range(0, 1)) = 0.3
        _AOStep("AO Step", range(0.01, 0.15)) = 0.1
        [Sapce(20)]

        [Header(Shadow AO)]
        [Space(5)]
        [Toggle(ENABLE_AO)] _EnableAO("Enable AO", float) = 1
        [Space(20)]

        [Header(Face Shadow Map)]
        [Sapce(5)]
        [Toggle(ENABLE_FACE_SHADOW_MAP)] _EnableFaceShadowMap("Enable Face Shadow Map", float) = 0
        _FaceShadowMap("Face Shadow Map", 2D) = "black" { }
        _FaceShadowSmooth("Face Shadow Smooth", range(0.001, 1.0)) = 0.2
        _FaceShadowOffset("Face Shadow Offset", range(-1, 1)) = 0.0
        [Space(20)]

        [Header(Specular)]
        [Space(5)]
        [Toggle] _EnableSpecular("Enable Specular", float) = 0
        _Shininess("Shininess", range(0, 1)) = 1
        _SpecularColor("SpecualrColor", Color) = (1.0, 1.0, 1.0, 1.0)
        [Space(20)]

        [Header(BloomMap)]
        [Space(5)]
        [NoScaleOffset]_BloomMap("BloomMap", 2D) = "white" { }
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "UniversalMaterialType" = "Lit"         // 采用PBR光照
            "Queue" = "Geometry"
        }

        HLSLINCLUDE
        // URP特供，手动提供内置渲染管线提供的功能
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        TEXTURE2D(_BaseMap);        SAMPLER(sampler_BaseMap);
        TEXTURE2D(_LightMap);       SAMPLER(sampler_LightMap);
        TEXTURE2D(_RampMap);        SAMPLER(sampler_RampMap);
        TEXTURE2D(_FaceShadowMap);  SAMPLER(sampler_FaceShadowMap);
        TEXTURE2D(_BloomMap);       SAMPLER(sampler_BloomMap);

        // SRP特供，将轻量级的变量存储到CBUFFER中
        CBUFFER_START(UnityPerMaterial)
        float4 _BaseMap_ST;
        float4 _BaseColor;

        float4 _LightMap_ST;
        float4 _ShadowColor;

        float4 _RampMap_ST;
        half _TimeOneDay;
        half _ShadowArea;       // 控制最终阴影色与基础色的比值
        half _RampShadowArea;     // 若halfLambert大于它，直接采样到最右边
        half _AOStep;           // 大于它的AO图值为1，否则为0

        float4 _FaceShadowMap_ST;
        half _FaceShadowSmooth;
        half _FaceShadowOffset;

        float _EnableSpecular;
        half _Shininess;        // 控制高光强度
        half4 _SpecularColor;

        float4 _BloomMap_ST;
        CBUFFER_END

        // 那么这些自然是重量级的变量
        struct Attributes
        {
            float3 positionOS: POSITION;
            half4 color: COLOR0;
            half3 normalOS: NORMAL;
            half4 tangentOS: TANGENT;
            float2 texcoord: TEXCOORD0;
        };

        struct Varyings
        {
            float4 positionCS: POSITION;
            float4 color: COLOR0;
            float4 uv: TEXCOORD0;
            float3 positionWS: TEXCOORD1;
            float3 positionVS: TEXCOORD2;
            float3 normalWS: TEXCOORD3;
            float lambert : TEXCOORD4;
            float halfLambert : TEXCOORD5;
            float4 shadowCoord: TEXCOORD6;
        };

        // Vertex Shader
        Varyings ToonPassVertex(Attributes input)
        {
            // 初始化返回值
            Varyings output = (Varyings)0;
            output.color = input.color;

            // 获得法线信息
            VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
            output.normalWS = vertexNormalInput.normalWS;

            // 坐标系转换
            output.positionWS = TransformObjectToWorld(input.positionOS);
            output.positionVS = TransformWorldToView(output.positionWS);
            output.positionCS = TransformWorldToHClip(output.positionWS);

            // 获取lambert光照信息
            //float3 lightDirWS = normalize(_MainLightPosition.xyz);
            float3 lightDirWS = normalize(GetMainLight().direction.xyz);
            lightDirWS.y = 0;
            output.lambert = dot(output.normalWS, lightDirWS);
            output.halfLambert = output.lambert * 0.5 + 0.5;

            // 获取阴影坐标
            output.shadowCoord = TransformWorldToShadowCoord(output.positionWS);

            // 获取基础贴图与光照贴图坐标
            output.uv.xy = TRANSFORM_TEX(input.texcoord, _BaseMap);
            output.uv.zw = TRANSFORM_TEX(input.texcoord, _BloomMap);
            return output;
        }
        ENDHLSL

        // 渲染Pass
        Pass
        {
            // 声明Pass的名称
            Name "CHARACTER_BASE"
            // 渲染Pass。从Pass的tag可以看出他记录的是什么信息（这不就是Tag的作用吗）
            Tags {"LightMode" = "UniversalForward"}

            Cull Back       // 执行背面剔除
            ZTest LEqual    // 让深度小于等于现有物体的物体通过深度测试
            ZWrite On       // 将通过深度测试的物体深度写入Depth buffer
            Blend One Zero  // 将当前输出颜色与历史颜色按比例混合输出
            
            HLSLPROGRAM
            #pragma shader_feature_local_fragment ENABLE_SHADOW
            #pragma shader_feature_local_fragmant ENABLE_AO
            #pragma shader_feature_local_fragment ENABLE_RAMP_SHADOW
            #pragma shader_feature_local_fragment ENABLE_FACE_SHADOW_MAP
            #pragma shader_feature_local_fragment SHOW_RAMP_COLOR
            #pragma vertex ToonPassVertex
            #pragma fragment ToonPassFragment
            // Fragment shader
            float4 ToonPassFragment(Varyings input) : COLOR
            {
                half4 FinalColor = half4(1, 1, 1, 1);               // 返回值
                Light MainLight = GetMainLight();                   // 主光源
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv.xy);
                half4 LightMapColor = SAMPLE_TEXTURE2D(_LightMap, sampler_LightMap, input.uv.xy);

                // 采样Ramp图（动态阴影）
                #if ENABLE_RAMP_SHADOW
                float halfLambert;    
                halfLambert = smoothstep(0, _RampShadowArea, input.halfLambert);   // 超出阈值的直接采样到右边界，做一个分界
                halfLambert = clamp(halfLambert, 0.004, 0.996);     // 防止采样到左右边界
                float ShadowAOMask = smoothstep(_AOStep, _AOStep + 0.001, LightMapColor.g);
                half RampV = _TimeOneDay > 0.5 ? LightMapColor.a * 0.45 + 0.5 + 0.025: LightMapColor.a * 0.45 + 0.025;      // '0.025' 为20行的RampMap中每一个像素的半径
                half4 RampColor = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(halfLambert * ShadowAOMask, RampV));
                half4 RampShadowColor = RampColor * _ShadowColor * baseColor;
                half4 BaseShadowColor = lerp(RampShadowColor, baseColor, step(_ShadowArea, input.halfLambert * ShadowAOMask));

                FinalColor = BaseShadowColor;
                #endif

#if SHOW_RAMP_COLOR
                return RampColor;
#endif
                
                // 面部阴影
                #if ENABLE_FACE_SHADOW_MAP
                // 光照旋转偏移
                float sinx = sin(_FaceShadowOffset);
                float cosx = cos(_FaceShadowOffset);
                float2x2 rotationOffset = float2x2(cosx, -sinx, sinx, cosx);
                float2 lightDir = mul(rotationOffset, MainLight.direction.xz);

                float3 Right = -mul(unity_ObjectToWorld, float4(1, 0, 0, 0));
                float3 Front = mul(unity_ObjectToWorld, float4(0, 0, 1, 0));
                float FoL = dot(normalize(Front.xz), normalize(lightDir));
                float RoL = dot(normalize(Right.xz), normalize(lightDir));

                // 左右采样FaceShadowMap得到FaceShadow
                half FaceShadowL = SAMPLE_TEXTURE2D(_FaceShadowMap, sampler_FaceShadowMap, float2(input.uv.x, input.uv.y)).r;
                half FaceShadowR = SAMPLE_TEXTURE2D(_FaceShadowMap, sampler_FaceShadowMap, float2(-input.uv.x, input.uv.y)).r;
                // 平滑FaceShadow
                half2 FaceShadow = pow(abs(half2(FaceShadowL, FaceShadowR)), _FaceShadowSmooth);
                // 暂时搞不懂
                float lightAttenuation = step(0, FoL) * min(step(RoL, FaceShadow.x), step(-RoL, FaceShadow.y));
                // 对面部的Ramp图进行采样
                half4 RampFaceColor = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(0.85, _TimeOneDay));
                half4 RampFaceShadowColor = _ShadowColor * RampFaceColor * baseColor;
                half4 FaceColor = lerp(RampFaceShadowColor, baseColor, lightAttenuation);
                FinalColor = FaceColor;
                #endif

                // Bling—Phong光照模型
                half3 viewDirWS = normalize(_WorldSpaceCameraPos.xyz - input.positionWS.xyz);
                half3 halfVectorDirWS = normalize(viewDirWS + MainLight.direction.xyz);
                half spec = pow(clamp(dot(viewDirWS, input.normalWS), 0, 1), 1 - _Shininess + 0.01);
                // LightMapColor.b与高光范围成正比。用它限制高光范围。
                spec = step(1 - LightMapColor.b, spec);
                // LightMapColor.r与高光强度成正比（不过这里叠加后无明显变化）
                half4 specularColor = _EnableSpecular * spec * LightMapColor.r * _SpecularColor;
                half4 SpecDiffuse = specularColor + FinalColor;
                SpecDiffuse *= _BaseColor;
                SpecDiffuse.a = specularColor.a * 10;
                FinalColor = SpecDiffuse;

                return FinalColor;
            }
            ENDHLSL
        }

    }
}
