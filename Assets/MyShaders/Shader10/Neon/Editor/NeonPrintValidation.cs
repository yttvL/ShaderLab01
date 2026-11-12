#if UNITY_EDITOR
using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Rendering;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

// 可在无窗口 Unity 中验证实际相机输出；不保存测试时的材质/场景变化。
public static class NeonPrintValidation
{
    [MenuItem("Tools/ShaderLab/Validate Neon Print")]
    public static void RunFromMenu()
    {
        if (UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty)
        {
            Debug.LogWarning("Neon Print: save the scene before running validation.");
            return;
        }
        Run();
    }

    public static void Run()
    {
        try
        {
            const string root = "Assets/MyShaders/Shader10/Neon/";
            var shader = AssetDatabase.LoadAssetAtPath<Shader>(root+"NeonPrint.shader");
            var material = AssetDatabase.LoadAssetAtPath<Material>(root+"NeonPrint.mat");
            var renderer = AssetDatabase.LoadAssetAtPath<UniversalRendererData>(root+"NeonPrint_Renderer.asset");
            if (!shader || !material || !renderer) throw new Exception("Missing NeonPrint assets.");
            if (material.shader != shader || material.passCount != 2) throw new Exception("Incorrect material shader/pass count.");
            var feature = renderer.rendererFeatures.OfType<NeonPrintRendererFeature>().Single();
            if (feature.material != material || !feature.isActive) throw new Exception("Material not assigned to active renderer feature.");
            EditorSceneManager.OpenScene("Assets/topics/10 image effects/scene/image effects.unity");
            var camera = Camera.main;
            if (!camera) throw new Exception("Scene has no MainCamera.");
            var data = camera.GetUniversalAdditionalCameraData();
            Undo.RecordObject(data,"Use Neon Print renderer");
            data.SetRenderer(1);
            EditorSceneManager.MarkSceneDirty(camera.gameObject.scene);
            EditorSceneManager.SaveScene(camera.gameObject.scene);
            if (!data.scriptableRenderer.GetType().Name.Contains("UniversalRenderer")) throw new Exception("Unexpected camera renderer.");
            Directory.CreateDirectory("Temp/NeonPrintValidation");
            float debug = material.GetFloat("_DebugView");
            try
            {
                var original = Capture(camera,material,1,"original");
                var final = Capture(camera,material,0,"final");
                Capture(camera,material,3,"edges");
                Capture(camera,material,4,"dots");
                Capture(camera,material,5,"tone");
                double difference = 0;
                double backgroundDifference = 0;
                int pinkPixels = 0;
                for (int i=0;i<original.Length;i++)
                {
                    double pixelDifference = Math.Abs(original[i].r-final[i].r)+Math.Abs(original[i].g-final[i].g)+Math.Abs(original[i].b-final[i].b);
                    difference += pixelDifference;
                    // 本周茶壶位于画面中央；最底部的一条区域用于验证 skybox 也参与效果。
                    if(i<original.Length/6) backgroundDifference += pixelDifference;
                    if(final[i].r>final[i].g+25 && final[i].b>final[i].g+10) pinkPixels++;
                }
                difference /= original.Length*3*255;
                backgroundDifference /= (original.Length/6)*3*255;
                if(difference<0.04 || backgroundDifference<0.04 || pinkPixels<100) throw new Exception($"Effect validation failed. RGB change={difference:F4}, background change={backgroundDifference:F4}, pink={pinkPixels}");
                var errors = ShaderUtil.GetShaderMessages(shader).Where(m=>m.severity==ShaderCompilerMessageSeverity.Error).ToArray();
                if(errors.Length>0) throw new Exception(string.Join("\n",errors.Select(m=>m.message)));
                File.WriteAllText("Temp/NeonPrintValidation/result.txt",$"PASS\nShader: {shader.name}\nPasses: {material.passCount}\nRenderer material linked: yes\nMean RGB change: {difference:F4}\nSkybox RGB change: {backgroundDifference:F4}\nPink pixels: {pinkPixels}\nDepth input: none\n");
                Debug.Log("NEON_PRINT_VALIDATION_PASS");
            }
            finally { material.SetFloat("_DebugView",debug); }
            if (Application.isBatchMode) EditorApplication.Exit(0);
        }
        catch(Exception error)
        {
            Debug.LogException(error);
            if (Application.isBatchMode) EditorApplication.Exit(1);
        }
    }

    static Color32[] Capture(Camera camera,Material material,int debug,string filename)
    {
        material.SetFloat("_DebugView",debug);
        var target = new RenderTexture(960,720,24,RenderTextureFormat.ARGB32);
        target.Create();
        var previous = RenderTexture.active;
        var previousTarget = camera.targetTexture;
        var image = new Texture2D(target.width,target.height,TextureFormat.RGB24,false);
        try
        {
            camera.targetTexture = target;
            camera.Render();
            RenderTexture.active = target;
            image.ReadPixels(new Rect(0,0,target.width,target.height),0,0);
            image.Apply();
            File.WriteAllBytes($"Temp/NeonPrintValidation/{filename}.png",image.EncodeToPNG());
            return image.GetPixels32();
        }
        finally
        {
            camera.targetTexture = previousTarget;
            RenderTexture.active = previous;
            UnityEngine.Object.DestroyImmediate(image);
            target.Release();
            UnityEngine.Object.DestroyImmediate(target);
        }
    }
}
#endif
