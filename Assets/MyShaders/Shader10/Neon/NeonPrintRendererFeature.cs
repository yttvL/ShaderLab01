using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

// 全屏颜色后处理：物体与 skybox 使用相同效果，不读取深度。
public sealed class NeonPrintRendererFeature : ScriptableRendererFeature
{
    public Material material;
    public bool applyToSceneView = true;
    NeonPrintPass effectPass;
    bool warnedInvalidMaterial;

    public override void Create()
    {
        effectPass = new NeonPrintPass
        {
            renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing,
            requiresIntermediateTexture = true
        };
        effectPass.ConfigureInput(ScriptableRenderPassInput.None);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        var type = renderingData.cameraData.cameraType;
        if (material == null || material.passCount < 2 || !material.shader.isSupported)
        {
            if (!warnedInvalidMaterial)
            {
                Debug.LogWarning($"Neon Print: invalid material. Material={material}, passes={(material != null ? material.passCount : 0)}, supported={(material != null && material.shader.isSupported)}",this);
                warnedInvalidMaterial=true;
            }
            return;
        }
        if (type != CameraType.Game && !(applyToSceneView && type == CameraType.SceneView)) return;
        effectPass.material = material;
        renderer.EnqueuePass(effectPass);
    }

    sealed class NeonPrintPass : ScriptableRenderPass
    {
        public Material material;
        bool warnedTarget;
        sealed class PassData
        {
            public TextureHandle source, original;
            public Material material;
            public int index, width, height;
        }

        public override void RecordRenderGraph(RenderGraph graph, ContextContainer frameData)
        {
            var resources = frameData.Get<UniversalResourceData>();
            if (resources.isActiveTargetBackBuffer)
            {
                if (!warnedTarget)
                {
                    Debug.LogWarning("Neon Print: a readable intermediate color target is required.");
                    warnedTarget=true;
                }
                return;
            }
            var source = resources.activeColorTexture;
            var desc = graph.GetTextureDesc(source);
            desc.clearBuffer = false;
            desc.msaaSamples = MSAASamples.None;
            desc.depthBufferBits = DepthBits.None;
            desc.name = "Neon Print - Paint Blocks";
            var smooth = graph.CreateTexture(desc);
            desc.name = "Neon Print - Composite";
            var result = graph.CreateTexture(desc);
            AddPass(graph,source,source,smooth,0,desc.width,desc.height,"Neon Print / Smooth");
            AddPass(graph,smooth,source,result,1,desc.width,desc.height,"Neon Print / Composite");
            resources.cameraColor = result;
        }

        void AddPass(RenderGraph graph, TextureHandle source, TextureHandle original,
            TextureHandle destination, int index, int width, int height, string label)
        {
            using var builder = graph.AddRasterRenderPass<PassData>(label,out var data);
            data.source=source; data.original=original;
            data.material=material; data.index=index; data.width=width; data.height=height;
            builder.UseTexture(source,AccessFlags.Read);
            if (index != 0) builder.UseTexture(original,AccessFlags.Read);
            builder.SetRenderAttachment(destination,0,AccessFlags.Write);
            builder.SetRenderFunc(static (PassData pass, RasterGraphContext context) =>
            {
                // 在执行阶段解析 TextureHandle；显式声明的读写关系由 RenderGraph 管理。
                RTHandle sourceRT = pass.source;
                RTHandle originalRT = pass.original;
                var properties = new MaterialPropertyBlock();
                properties.SetTexture("_BlitTexture",sourceRT.rt);
                properties.SetTexture("_NeonOriginalTexture",originalRT.rt);
                properties.SetVector("_BlitScaleBias",new Vector4(1,1,0,0));
                properties.SetVector("_BlitTexture_TexelSize",new Vector4(1f/pass.width,1f/pass.height,pass.width,pass.height));
                context.cmd.DrawProcedural(Matrix4x4.identity,pass.material,pass.index,MeshTopology.Triangles,3,1,properties);
            });
        }
    }
}
