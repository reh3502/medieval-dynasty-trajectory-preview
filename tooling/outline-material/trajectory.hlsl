// UV.x is cumulative arc distance in centimetres; UV.y crosses the strip.
// Mask.r is the far-end envelope; Mask.g distinguishes the contact ring.
float across = abs(UV.y * 2.0 - 1.0);
float edge = 1.0 - smoothstep(0.35, 1.0, across);
float core = 1.0 - smoothstep(0.0, 0.50, across);
float marker = step(0.5, Mask.g);
float phase = frac(UV.x / 650.0 - Clock * 0.32);
float wave = pow(0.5 + 0.5*cos(phase * 6.2831853), 8.0);
// A readable continuous thread with a low-contrast moving highlight.
float flow = lerp(0.88 + 0.12*wave, 1.0 + 0.12*ContactPulse, marker);
float envelope = lerp(smoothstep(450.0,650.0,UV.x)*Mask.r, 1.0, marker);
float3 amber = float3(0.82,0.58,0.26);
float3 ivory = float3(1.0,0.91,0.72);
float3 tint = lerp(amber,ivory,core*0.80);
float alpha = edge * envelope * Reveal * Opacity * flow * lerp(0.78,1.0,saturate(DrawStrength));
return float4(tint,saturate(alpha));
