# Neon Print — Halftone

Two passes: edge-aware color smoothing, then full-screen neon ink shading.

Dark regions use solid deep violet ink. Bright regions use solid coral ink.
Midtones grow bright dots out of dark ink, closing into dark holes near the
bright region. Geometric paint facets have been removed.

Fine Grain and Pigment Variation preserve the procedural paper texture.
White highlights and pink color-edge outlines remain separate layers.
No depth texture is sampled; the skybox receives the same effect.

Material: NeonPrint.mat. Renderer: NeonPrint_Renderer (PC_RPAsset index 1).

- Dot Spacing Pixels: distance between dots.
- Dot Size Bias: extra dot growth; default 0.24.
- Midtone Exposure: shifts the brightness-to-coverage mapping.
- Halftone Strength: 1 for full ink shading.
- Fine Grain: fine paper grain.
- Pigment Variation: larger pigment irregularities.
- Highlight Threshold / Edge Softness: white highlight area and edge softness.

Tools > ShaderLab > Validate Neon Print selects renderer 1, saves the weekly
scene and validates captures in Temp/NeonPrintValidation.