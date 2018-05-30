// Copyright 2018 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <metal_stdlib>
using namespace metal;
#include <SceneKit/scn_metal>

#import "ShaderTypes.h"


typedef struct {
    float3 scnPosition [[ attribute(SCNVertexSemanticPosition) ]];
    float3 normal   [[ attribute(SCNVertexSemanticNormal) ]];
} SCNVertexInput;


struct MyVertexOutput{
    float4 position [[position]];
    float3 normal;
    float4 color;
    float depth;
    float2 borderTexCoord;
    float2 endCapTexCoord;
    float2 startCapTexCoord;
};

struct MyNodeBuffer {
    float4x4 modelTransform;
    float4x4 modelViewProjectionTransform;
};


struct FrameBuffer{
    vector_float2 resolution;
    vector_float4 color;
};


float2 fix( float4 i, float aspect ) {
    float2 res = i.xy / i.w;
    res.x *= aspect;

    return res;
}

float map(float value, float inMin, float inMax, float outMin, float outMax) {
    //  return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
    return ((value - inMin) / (inMax - inMin) * (outMax - outMin) + outMin);
}



vertex MyVertexOutput basic_vertex(SCNVertexInput in [[ stage_in ]],
                               constant SCNSceneBuffer& scn_frame [[buffer(0)]],
                               constant MyNodeBuffer& scn_node [[buffer(1)]],
                               device MyVertex *vertices [[buffer(4)]],
                               uint v_id [[vertex_id]]) {
    MyVertexOutput out;
    
    MyVertex currentVertex = vertices[v_id];
    float2 myResolution = currentVertex.resolution;
    float4 color = currentVertex.color;
    
    int iGood = v_id;
    iGood = clamp(iGood, 0, currentVertex.vertexCount-1);
    
    int i_m_1 = (iGood > 1) ? iGood - 2 : iGood;

    int i_p_1 = (iGood < (currentVertex.vertexCount - 2)) ? iGood + 2 : iGood;
    
    
    MyVertex previousVertex = vertices[i_m_1];
    MyVertex nextVertex = vertices[i_p_1];    
    
    float4x4 m = scn_node.modelViewProjectionTransform;
    float aspect = myResolution.x / myResolution.y;
    
    float4 finalPosition = m * float4( currentVertex.position, 1.0 );
    float4 prevPos = m * float4( previousVertex.position, 1.0 );
    float4 nextPos = m * float4( nextVertex.position, 1.0 );
    
    float2 currentP = fix( finalPosition, aspect);
    float2 prevP = fix( prevPos, aspect);
    float2 nextP = fix( nextPos, aspect);
    
    float2 dir;
    if( v_id >= currentVertex.vertexCount - 4){
        dir = normalize( currentP - prevP );
    }
    else if( v_id < 2 ){
        dir = normalize( nextP - currentP );
    }
    else {
        float2 dir1 = normalize( currentP - prevP );
        float2 dir2 = normalize( nextP - currentP );
        dir = normalize( dir1 + dir2 );
    }
    
    float2 normal = float2( -dir.y, dir.x );
    
    // portrait orientation
    if (aspect < 1) {
        normal.x = (normal.x / aspect);
        
    // landscape orientation
    } else {
        normal.y = (normal.y * aspect);
    }
    normal *= 0.5 * currentVertex.width;
    
    
    float4 offset = float4( normal * currentVertex.side, 0.0, 1.0 );
    finalPosition.xy += offset.xy;
    
    out.color = color;
    out.position = finalPosition;
    out.depth = out.position.z;
    out.borderTexCoord = float2( 2.0 * currentVertex.length / currentVertex.width, (currentVertex.side + 1.0)/2.0);
    out.endCapTexCoord = float2( 2.0 * (currentVertex.length - currentVertex.endCap + currentVertex.width/2.0)/ currentVertex.width, (currentVertex.side + 1.0)/2.0);
    out.startCapTexCoord = float2( 1.0 - 2.0 * currentVertex.length / currentVertex.width, (currentVertex.side + 1.0)/2.0);

    return out;
}

fragment float4 basic_fragment(MyVertexOutput in [[stage_in]],
                               constant SCNSceneBuffer& scn_frame [[buffer(0)]],
                               texture2d<float, access::sample> endCapTexture [[texture(0)]]) {
    float4 out;
    
    constexpr sampler samplerEndCap(coord::normalized, filter::linear, address::clamp_to_edge);
    constexpr sampler samplerStartCap(coord::normalized, filter::linear, address::clamp_to_edge);
    constexpr sampler samplerBorder(coord::normalized, filter::nearest, address::repeat);

    float4 endCapColor = endCapTexture.sample(samplerEndCap, in.endCapTexCoord);
    float4 startCapColor = endCapTexture.sample(samplerStartCap, in.startCapTexCoord);


    out = float4(1,1,1,1);
//    out = float4(scn_frame.random01, scn_frame.random01, scn_frame.random01, 1);
    out.a *= min(startCapColor.a, endCapColor.a);
    
    // Calculate the distance
//    float4 control = borderTexture.sample(samplerBorder, in.borderTexCoord);
//    float distDiff = abs(0.17 - in.depth);
//
//    float c = 1.0;
//    if(distDiff > 0.0){
//        c = saturate(0.002/distDiff); // same as clamp between 0-1
//    }
//
////    out = max(out, mix(float4(0,0,0,0), control, c));
//    out = max(out, control * c);
////    out.rgb *= out.a;
    
    if(in.endCapTexCoord.x > 1.0 || out.a < 0.5){
        discard_fragment();
    }
    
    return out;
}
