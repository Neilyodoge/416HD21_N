using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
using System;
using UnityEngine.Experimental.Rendering;

[Serializable, VolumeComponentMenu("Custom/PP_SNN&Sharp")]
public sealed class PP_SNNandSharp : CustomPostProcessVolumeComponent, IPostProcessComponent
{
    //[Tooltip("Controls the intensity of the effect.")]
#if UNITY_EDITOR
    public BoolParameter PP_ON = new BoolParameter(true);
#endif
    public ClampedFloatParameter _SNNPixelWidth = new ClampedFloatParameter(3f, 2f, 7f);
    public ClampedFloatParameter _SNNIntensity = new ClampedFloatParameter(0.8f, 0f, 1f);
    public ClampedFloatParameter _SharpIntensity = new ClampedFloatParameter(0.2f, 0f, 1f);

    Material snn_Material;
    Material sharp_Material;

    RTHandle temp;

    public bool IsActive() => snn_Material != null;

    // Do not forget to add this post process in the Custom Post Process Orders list (Project Settings > Graphics > HDRP Global Settings).
    public override CustomPostProcessInjectionPoint injectionPoint => CustomPostProcessInjectionPoint.BeforePostProcess;

    const string snnShaderName = "Hidden/Shader/PP_SNN";
    const string sharpShaderName = "Hidden/Shader/PP_Sharpen";

    public override void Setup()
    {
        if (Shader.Find(snnShaderName) != null)
            snn_Material = new Material(Shader.Find(snnShaderName));
        if(Shader.Find(sharpShaderName) != null)
            sharp_Material = new Material(Shader.Find(sharpShaderName));
        
        //else
        //    Debug.LogError($"Unable to find shader '{snnShaderName}' or '{sharpShaderName}'. Post Process Volume PP_SNN is unable to load.");

    }

    public override void Render(CommandBuffer cmd, HDCamera camera, RTHandle source, RTHandle destination)
    {
#if UNITY_EDITOR
        // easy to check PP close effect
        if (!PP_ON.value)
        {
            _SNNIntensity.value = 0f;
            _SharpIntensity.value = 0f;
        }
#endif
        if (snn_Material == null || sharp_Material == null)
            return;

        if (temp?.rt == null || !temp.rt.IsCreated())
        {
            temp = RTHandles.Alloc(
            Vector2.one, TextureXR.slices, dimension: TextureXR.dimension,
            colorFormat: GraphicsFormat.B10G11R11_UFloatPack32, // We don't need alpha in the blur
            useDynamicScale: true, name: "SNN_RT");
        }

        snn_Material.SetFloat("_SNNIntensity", _SNNIntensity.value);
        snn_Material.SetFloat("_SNNPixelWidth", _SNNPixelWidth.value);
        snn_Material.SetTexture("_MainTex", source);
        HDUtils.DrawFullScreen(cmd, snn_Material, temp, shaderPassId: 0);

        sharp_Material.SetTexture("_MainTex", temp);
        sharp_Material.SetFloat("_SharpIntensity", _SharpIntensity.value);
        HDUtils.DrawFullScreen(cmd, sharp_Material, destination, shaderPassId: 0);
    }

    public override void Cleanup()
    {
        CoreUtils.Destroy(snn_Material);
        CoreUtils.Destroy(sharp_Material);

        temp?.Release();
    }
}
