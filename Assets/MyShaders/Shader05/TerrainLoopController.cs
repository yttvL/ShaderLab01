using UnityEngine;

[RequireComponent(typeof(Renderer))]
public class TerrainLoopController : MonoBehaviour
{
    [Header("Loop")]
    [SerializeField] private float loopDuration = 20f;

    [Header("Water")]
    [SerializeField] private float startWaterLevel = -0.25f;
    [SerializeField] private float raisedWaterLevel = 0f;

    private const float HoldFlatEnd   = 2f;
    private const float MorphUpEnd    = 6f;
    private const float WaterRiseEnd  = 10f;
    private const float HoldFullEnd   = 16f;
    private const float MorphDownEnd  = 20f;

    private static readonly int MorphID = Shader.PropertyToID("_Morph");
    private static readonly int WaterLevelID = Shader.PropertyToID("_WaterLevel");

    private Renderer targetRenderer;
    private MaterialPropertyBlock propertyBlock;
    private float startTime;

    private void Awake()
    {
        targetRenderer = GetComponent<Renderer>();
        propertyBlock = new MaterialPropertyBlock();
    }

    private void OnEnable()
    {
        startTime = Time.time;
        ApplyValues(0f, startWaterLevel);
    }

    private void Update()
    {
        float safeLoopDuration = Mathf.Max(loopDuration, 0.0001f);

        float normalizedTime =
            Mathf.Repeat(Time.time - startTime, safeLoopDuration) / safeLoopDuration;

        float t = normalizedTime * 20f;

        float morph;
        float waterLevel;

        if (t < HoldFlatEnd)
        {
            morph = 0f;
            waterLevel = startWaterLevel;
        }

        else if (t < MorphUpEnd)
        {
            float phase = Mathf.InverseLerp(HoldFlatEnd, MorphUpEnd, t);

            phase = Smooth01(phase);

            morph = phase;
            waterLevel = startWaterLevel;
        }

        else if (t < WaterRiseEnd)
        {
            float phase = Mathf.InverseLerp(MorphUpEnd, WaterRiseEnd, t);
            phase = Smooth01(phase);

            morph = 1f;
            waterLevel = Mathf.Lerp(startWaterLevel, raisedWaterLevel, phase);
        }

        else if (t < HoldFullEnd)
        {
            morph = 1f;
            waterLevel = raisedWaterLevel;
        }

        else
        {
            float phase = Mathf.InverseLerp(HoldFullEnd, MorphDownEnd, t);

            phase = Smooth01(phase);

            morph = 1f - phase;
            waterLevel = raisedWaterLevel;
        }

        ApplyValues(morph, waterLevel);
    }

    private void ApplyValues(float morph, float waterLevel)
    {
        targetRenderer.GetPropertyBlock(propertyBlock);

        propertyBlock.SetFloat(MorphID, morph);
        propertyBlock.SetFloat(WaterLevelID, waterLevel);

        targetRenderer.SetPropertyBlock(propertyBlock);
    }

    private static float Smooth01(float t)
    {
        t = Mathf.Clamp01(t);
        return t * t * (3f - 2f * t);
    }
}
