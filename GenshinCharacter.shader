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
            "UniversalMaterialType" = "Lit"         // ����PBR����
            "Queue" = "Geometry"
        }

        HLSLINCLUDE
        // URP�ع����ֶ��ṩ������Ⱦ�����ṩ�Ĺ���
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        TEXTURE2D(_BaseMap);        SAMPLER(sampler_BaseMap);
        TEXTURE2D(_LightMap);       SAMPLER(sampler_LightMap);
        TEXTURE2D(_RampMap);        SAMPLER(sampler_RampMap);
        TEXTURE2D(_FaceShadowMap);  SAMPLER(sampler_FaceShadowMap);
        TEXTURE2D(_BloomMap);       SAMPLER(sampler_BloomMap);

        // SRP�ع������������ı����洢��CBUFFER��
        CBUFFER_START(UnityPerMaterial)
        float4 _BaseMap_ST;
        float4 _BaseColor;

        float4 _LightMap_ST;
        float4 _ShadowColor;

        float4 _RampMap_ST;
        half _TimeOneDay;
        half _ShadowArea;       // ����������Ӱɫ�����ɫ�ı�ֵ
        half _RampShadowArea;     // ��halfLambert��������ֱ�Ӳ��������ұ�
        half _AOStep;           // ��������AOͼֵΪ1������Ϊ0

        float4 _FaceShadowMap_ST;
        half _FaceShadowSmooth;
        half _FaceShadowOffset;

        float _EnableSpecular;
        half _Shininess;        // ���Ƹ߹�ǿ��
        half4 _SpecularColor;

        float4 _BloomMap_ST;
        CBUFFER_END

        // ��ô��Щ��Ȼ���������ı���
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
            // ��ʼ������ֵ
            Varyings output = (Varyings)0;
            output.color = input.color;

            // ��÷�����Ϣ
            VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
            output.normalWS = vertexNormalInput.normalWS;

            // ����ϵת��
            output.positionWS = TransformObjectToWorld(input.positionOS);
            output.positionVS = TransformWorldToView(output.positionWS);
            output.positionCS = TransformWorldToHClip(output.positionWS);

            // ��ȡlambert������Ϣ
            //float3 lightDirWS = normalize(_MainLightPosition.xyz);
            float3 lightDirWS = normalize(GetMainLight().direction.xyz);
            lightDirWS.y = 0;
            output.lambert = dot(output.normalWS, lightDirWS);
            output.halfLambert = output.lambert * 0.5 + 0.5;

            // ��ȡ��Ӱ����
            output.shadowCoord = TransformWorldToShadowCoord(output.positionWS);

            // ��ȡ������ͼ�������ͼ����
            output.uv.xy = TRANSFORM_TEX(input.texcoord, _BaseMap);
            output.uv.zw = TRANSFORM_TEX(input.texcoord, _BloomMap);
            return output;
        }
        ENDHLSL

        // ��ȾPass
        Pass
        {
            // ����Pass������
            Name "CHARACTER_BASE"
            // ��ȾPass����Pass��tag���Կ�������¼����ʲô��Ϣ���ⲻ����Tag��������
            Tags {"LightMode" = "UniversalForward"}

            Cull Back       // ִ�б����޳�
            ZTest LEqual    // �����С�ڵ����������������ͨ����Ȳ���
            ZWrite On       // ��ͨ����Ȳ��Ե��������д��Depth buffer
            Blend One Zero  // ����ǰ�����ɫ����ʷ��ɫ������������
            
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
                half4 FinalColor = half4(1, 1, 1, 1);               // ����ֵ
                Light MainLight = GetMainLight();                   // ����Դ
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv.xy);
                half4 LightMapColor = SAMPLE_TEXTURE2D(_LightMap, sampler_LightMap, input.uv.xy);

                // ����Rampͼ����̬��Ӱ��
                #if ENABLE_RAMP_SHADOW
                float halfLambert;    
                halfLambert = smoothstep(0, _RampShadowArea, input.halfLambert);   // ������ֵ��ֱ�Ӳ������ұ߽磬��һ���ֽ�
                halfLambert = clamp(halfLambert, 0.004, 0.996);     // ��ֹ���������ұ߽�
                float ShadowAOMask = smoothstep(_AOStep, _AOStep + 0.001, LightMapColor.g);
                half RampV = _TimeOneDay > 0.5 ? LightMapColor.a * 0.45 + 0.5 + 0.025: LightMapColor.a * 0.45 + 0.025;      // '0.025' Ϊ20�е�RampMap��ÿһ�����صİ뾶
                half4 RampColor = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(halfLambert * ShadowAOMask, RampV));
                half4 RampShadowColor = RampColor * _ShadowColor * baseColor;
                half4 BaseShadowColor = lerp(RampShadowColor, baseColor, step(_ShadowArea, input.halfLambert * ShadowAOMask));

                FinalColor = BaseShadowColor;
                #endif

#if SHOW_RAMP_COLOR
                return RampColor;
#endif
                
                // �沿��Ӱ
                #if ENABLE_FACE_SHADOW_MAP
                // ������תƫ��
                float sinx = sin(_FaceShadowOffset);
                float cosx = cos(_FaceShadowOffset);
                float2x2 rotationOffset = float2x2(cosx, -sinx, sinx, cosx);
                float2 lightDir = mul(rotationOffset, MainLight.direction.xz);

                float3 Right = -mul(unity_ObjectToWorld, float4(1, 0, 0, 0));
                float3 Front = mul(unity_ObjectToWorld, float4(0, 0, 1, 0));
                float FoL = dot(normalize(Front.xz), normalize(lightDir));
                float RoL = dot(normalize(Right.xz), normalize(lightDir));

                // ���Ҳ���FaceShadowMap�õ�FaceShadow
                half FaceShadowL = SAMPLE_TEXTURE2D(_FaceShadowMap, sampler_FaceShadowMap, float2(input.uv.x, input.uv.y)).r;
                half FaceShadowR = SAMPLE_TEXTURE2D(_FaceShadowMap, sampler_FaceShadowMap, float2(-input.uv.x, input.uv.y)).r;
                // ƽ��FaceShadow
                half2 FaceShadow = pow(abs(half2(FaceShadowL, FaceShadowR)), _FaceShadowSmooth);
                // ��ʱ�㲻��
                float lightAttenuation = step(0, FoL) * min(step(RoL, FaceShadow.x), step(-RoL, FaceShadow.y));
                // ���沿��Rampͼ���в���
                half4 RampFaceColor = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(0.85, _TimeOneDay));
                half4 RampFaceShadowColor = _ShadowColor * RampFaceColor * baseColor;
                half4 FaceColor = lerp(RampFaceShadowColor, baseColor, lightAttenuation);
                FinalColor = FaceColor;
                #endif

                // Bling��Phong����ģ��
                half3 viewDirWS = normalize(_WorldSpaceCameraPos.xyz - input.positionWS.xyz);
                half3 halfVectorDirWS = normalize(viewDirWS + MainLight.direction.xyz);
                half spec = pow(clamp(dot(viewDirWS, input.normalWS), 0, 1), 1 - _Shininess + 0.01);
                // LightMapColor.b��߹ⷶΧ�����ȡ��������Ƹ߹ⷶΧ��
                spec = step(1 - LightMapColor.b, spec);
                // LightMapColor.r��߹�ǿ�ȳ����ȣ�����������Ӻ������Ա仯��
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
