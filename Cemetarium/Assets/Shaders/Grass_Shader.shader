Shader "Unlit/NewUnlitShader 1"
{
	//Tutorial from https://roystan.net/articles/grass-shader.html, updated for 2020 URP
    Properties
    {
        //_MainTex ("Texture", 2D) = "white" {}
		[Header(Shading)]
		_TopColor("Top Color", Color) = (1,1,1,1)
		_BottomColor("Bottom Color", Color) = (1,1,1,1)
		_TranslucentGain("Translucent Gain", Range(0,1)) = 0.5
		_BendRotationRandom("Bend Rotation Random", Range(0, 1)) = 0.2

		_BladeWidth("Blade Width", Float) = 0.05
		_BladeWidthRandom("Blade Width Random", Float) = 0.02 //additive
		_BladeHeight("Blade Height", Float) = 0.5
		_BladeHeightRandom("Blade Height Random", Float) = 0.3 //additive

		//smaller value => better tended glass, like for mowed lawns
		_BladeForward("Blade Forward Amount", Float) = 0.38
		_BladeCurve("Blade Curvature Amount", Range(1, 4)) = 2

	    //subdivision => larger is more grass per area
		_TessellationUniform("Tessellation Uniform", Range(1, 64)) = 5

		_WindDistortionMap("Wind Distortion Map", 2D) = "white" {}
        _WindFrequency("Wind Frequency", Vector) = (0.05, 0.05, 0, 0)
		_WindStrength("Wind Strength", Float) = 1
    }

	CGINCLUDE
	#include "UnityCG.cginc"
	#include "Autolight.cginc"
    #include "CustomTessellation.cginc"
	
    #define BLADE_SEGMENTS 3

    float _BendRotationRandom;

	float _BladeHeight;
	float _BladeHeightRandom;
	float _BladeWidth;
	float _BladeWidthRandom;

	float _BladeForward;
	float _BladeCurve;

	sampler2D _WindDistortionMap;
	float4 _WindDistortionMap_ST;
	float2 _WindFrequency;
	float _WindStrength;

	// Simple noise function, sourced from http://answers.unity.com/answers/624136/view.html
	// Extended discussion on this function can be found at the following link:
	// https://forum.unity.com/threads/am-i-over-complicating-this-random-function.454887/#post-2949326
	// Returns a number in the 0...1 range.
	float rand(float3 co)
	{
		return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
	}

	// Construct a rotation matrix that rotates around the provided axis, sourced from:
	// https://gist.github.com/keijiro/ee439d5e7388f3aafc5296005c8c3f33
	float3x3 AngleAxis3x3(float angle, float3 axis)
	{
		float c, s;
		sincos(angle, s, c);

		float t = 1 - c;
		float x = axis.x;
		float y = axis.y;
		float z = axis.z;

		return float3x3(
			t * x * x + c, t * x * y - s * z, t * x * z + s * y,
			t * x * y + s * z, t * y * y + c, t * y * z - s * x,
			t * x * z - s * y, t * y * z + s * x, t * z * z + c
			);
	}

	/* 
	Definted in tesselation file
	kept this to remind me how to do this step for future shaders

	struct vertexInput
	{
		float4 vertex : POSITION;
		float3 normal : NORMAL;
		float4 tangent : TANGENT;
	};

	struct vertexOutput
	{
		float4 vertex : SV_POSITION;
		float3 normal : NORMAL;
		float4 tangent : TANGENT;
	};

	vertexOutput vert(vertexInput v)
	{
		vertexOutput o;
	    
	    o.vertex = v.vertex;
		o.normal = v.normal;
		o.tangent = v.tangent;

		return o;
	}*/

	struct geometryOutput
	{
		float4 pos : SV_POSITION;
		float2 uv : TEXCOORD0;
		//UNITY_FOG_COORDS(1)
	};

	geometryOutput VertexOutput(float3 pos, float2 uv)
	{
		geometryOutput o;
		o.pos = UnityObjectToClipPos(pos);
		o.uv = uv;
		return o;
	}

	//tangent position goes from -width to width. second floats are uv map, which goes from 0 to 1
	geometryOutput GenerateGrassVertex(float3 vertexPosition, float width, float height, float forward, float2 uv, float3x3 transformMatrix)
	{
		//point in tangent space
		float3 tangentPoint = float3(width, forward, height); //forward = bend

		float3 localPosition = vertexPosition + mul(transformMatrix, tangentPoint);
		return VertexOutput(localPosition, uv);
	}

	//three points input as using a triangle mesh
	[maxvertexcount(BLADE_SEGMENTS * 2 + 1)] // two per square + one at top for tip
	void geo(triangle vertexOutput IN[3], inout TriangleStream<geometryOutput> triStream)
	{
		float3 pos = IN[0].vertex;

		float3 vNormal = IN[0].normal;
		float4 vTangent = IN[0].tangent;
		float3 vBinormal = cross(vNormal, vTangent) * vTangent.w;

		//random * 2 - 1 => between -1 and 1 [then mult by a max, called BladeHeightRandom]
		//this makes the height and width vary positively and negatively
		float height = (rand(pos.zyx) * 2 - 1) * _BladeHeightRandom + _BladeHeight;
		float width = (rand(pos.xzy) * 2 - 1) * _BladeWidthRandom + _BladeWidth;
		float forward = rand(pos.yyz) * _BladeForward;

		/* Matrices */

		float3x3 tangentToLocal = float3x3(
			vTangent.x, vBinormal.x, vNormal.x,
			vTangent.y, vBinormal.y, vNormal.y,
			vTangent.z, vBinormal.z, vNormal.z
			);

		float2 uv = pos.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;
		float2 windSample = (tex2Dlod(_WindDistortionMap, float4(uv, 0, 0)).xy * 2 - 1) * _WindStrength;
		float3 wind = normalize(float3(windSample.x, windSample.y, 0));

		//a x & y rot
		float3x3 windRotation = AngleAxis3x3(UNITY_PI * windSample, wind);

		//seed = pos: stays consistent between each frame
		float3x3 facingRotationMatrix = AngleAxis3x3(rand(pos) * UNITY_TWO_PI, float3(0, 0, 1));
		//pi/2 so only bend up to 90 deg, swizzling seed generation method
		float3x3 bendRotationMatrix = AngleAxis3x3(rand(pos.zzx) * _BendRotationRandom * UNITY_PI * 0.5, float3(-1, 0, 0));

		//tangent space * y rot * x rot multiplication order
		float3x3 transformationMatrix = mul(mul(mul(tangentToLocal, windRotation), facingRotationMatrix), bendRotationMatrix);
		
		//dont rotate the base of the grass, as that need to be stuck to the ground
		float3x3 transformationMatrixFacing = mul(tangentToLocal, facingRotationMatrix);
		
		/* Applying to input */

		for(int i = 0; i < BLADE_SEGMENTS; i++)
		{
			float t = i / (float) BLADE_SEGMENTS;

			float segmentHeight = height * t;
			float segmentWidth = width * (1 - t); //width decreases as go up grass (tapers)
			float segmentForward = pow(t, _BladeCurve) * forward; //bend, non-linear => curves blade nicely

			float3x3 transformMatrix = i == 0 ? transformationMatrixFacing : transformationMatrix;

			triStream.Append(GenerateGrassVertex(pos, segmentWidth, segmentHeight, segmentForward, float2(0, t), transformMatrix));
			triStream.Append(GenerateGrassVertex(pos, -segmentWidth, segmentHeight, segmentForward, float2(1, t), transformMatrix));
		}
		triStream.Append(GenerateGrassVertex(pos, 0, height, forward, float2(0.5, 1), transformationMatrix)); //tip of blade

		
		//UNITY_TRANSFER_FOG(o, o.vertex);
	}

	ENDCG

    SubShader
    {
		CULL off

        Tags 
	    { 
			"RenderType"="Opaque"
			"RenderPipeline" = "UniversalPipeline"
	    }

        //LOD 100

        Pass
        {
            CGPROGRAM

			//requires this ordering, even tho goes vertex -> tessellation (hull/domain) -> geo -> frag
            #pragma vertex vert
			#pragma fragment frag
			#pragma geometry geo
			#pragma hull hull
			#pragma domain domain

            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
			#include "Lighting.cginc"

			float4 _TopColor;
			float4 _BottomColor;
			float _TranslucentGain;

			// Modify the function signature of the fragment shader.
			float4 frag(geometryOutput i, fixed facing : VFACE) : SV_Target
			{

			    return lerp(_BottomColor, _TopColor, i.uv.y);
                // sample the texture
                //fixed4 col = tex2D(_MainTex, i.uv);

                // apply fog
                //UNITY_APPLY_FOG(i.fogCoord, col);
                //return col;
            }
            ENDCG
        }
    }
}
