// Per-target silhouette, restricted by stencil and scene depth.
// Inputs from SceneTexture nodes also declare their renderer dependencies.
float2 uv = GetDefaultSceneTextureUV(Parameters, 13);
float2 texel = View.BufferSizeAndInvSize.zw;
float centerSelected = abs(CenterStencil.r - StencilId) < 0.5;
if (centerSelected) return SceneColor.rgb;
float edge = 0.0;
const float2 offsets[8] = {
    float2(-1,0),float2(1,0),float2(0,-1),float2(0,1),
    float2(-0.7071,-0.7071),float2(0.7071,-0.7071),
    float2(-0.7071,0.7071),float2(0.7071,0.7071)
};
[unroll] for (int i=0; i<8; ++i) {
    float2 p = ClampSceneTextureUV(uv + offsets[i] * texel * clamp(Width,1.0,5.0),13);
    float stencil = SceneTextureLookup(p,25,false).r;
    float selected = abs(stencil-StencilId)<0.5;
    // Most screen pixels have no selected neighbour. Avoid the two depth
    // samples for those pixels while preserving the same eight-point edge.
    [branch] if (selected) {
        float depth = SceneTextureLookup(p,13,false).r;
        float sceneDepth = SceneTextureLookup(p,1,false).r;
        float visible = (depth<=sceneDepth+1.0) && (depth<=CenterDepth.r+1.0);
        edge = max(edge,visible);
    }
}
float alpha = saturate(edge * (1.0-centerSelected) * Strength);
return lerp(SceneColor.rgb,OutlineColor.rgb,alpha);
