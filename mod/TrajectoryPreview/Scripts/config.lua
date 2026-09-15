-- Local-only settings. Ctrl+R reloads after editing this file.
return {
    enabled=true,
    world_renderer=true, -- False restores the UMG renderer; Ctrl+R reloads.
    color={R=0.15,G=1.0,B=0.65},
    ribbon_color={R=0.82,G=0.84,B=0.86},
    highlight_color={R=0.78,G=0.86,B=0.82},
    opacity=0.85,
    thickness=2.0,
    marker_radius=7,
    horizon=5.0,
    max_distance=20000,
    step=1/60,
    max_steps=512,
    telemetry=false, -- Enable diagnostic logging and timing when troubleshooting.
}
