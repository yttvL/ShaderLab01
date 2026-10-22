using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>
/// UV0.x: bell radial parameter u / appendage longitudinal parameter t
/// UV0.y: bell angular parameter v / appendage index normalized into 01
/// Color.r: 0 bell, 0.5 oral arm, 1 tentacle
/// Color.g: normalized angular coordinate
/// Color.b: tentacle root radius as a fraction of bellRadius
/// </summary>
[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class JellyfishMesh : MonoBehaviour
{
    [Header("Bell")]
    [Min(3)] public int angularSegments = 48;
    [Min(2)] public int bellRings = 24;
    [Min(0.01f)] public float bellRadius = 1f;
    [Min(0.01f)] public float bellHeight = 0.65f;
    [Min(0f)] public float rimDrop = 0.12f;
    [Range(0f, 0.6f)] public float rimInset = 0.18f;
    [Range(0.4f, 1f)] public float rimInsetStart = 0.78f;


    [Header("Tentacles (tubes)")]
    [Range(0, 64)] public int tentacleCount = 28;
    [Min(1)] public int tentacleSegments = 32;
    [Range(3, 12)] public int tubeSides = 10;
    [Min(0.01f)] public float tentacleLength = 2.4f;
    [Range(0f, 0.5f)] public float tentacleLengthVariation = 0.25f;
    [Min(0.001f)] public float tentacleRadius = 0.012f;
    [Range(0f, 0.7f)] public float tentacleRootInnerRadius = 0.12f;
    [Range(0f, 0.7f)] public float tentacleRootOuterRadius = 0.58f;
    [Range(0f, 0.2f)] public float tentacleRootDepth = 0.025f;


    [Header("Oral Arms (ribbons)")]
    [Range(0, 12)] public int oralArmCount = 10;
    [Min(1)] public int oralArmSegments = 20;
    [Min(0.01f)] public float oralArmLength = 1.25f;
    [Min(0.001f)] public float oralArmWidth = 0.13f;
    [Range(0f, 0.6f)] public float oralArmOffset = 0.16f;
    [Range(0.01f, 0.4f)] public float oralArmRootDepth = 0.08f;

    readonly List<Vector3> vertices = new List<Vector3>();
    readonly List<Vector2> uvs = new List<Vector2>();
    readonly List<Color> colors = new List<Color>();
    readonly List<int> triangles = new List<int>();

    Mesh generatedMesh;

    void Start() => GenerateMesh();

    [ContextMenu("Regenerate Jellyfish Mesh")]
    public void GenerateMesh()
    {
        //safety checks
        angularSegments = Mathf.Max(3, angularSegments);
        bellRings = Mathf.Max(2, bellRings);
        tentacleSegments = Mathf.Max(1, tentacleSegments);
        tubeSides = Mathf.Max(3, tubeSides);
        oralArmSegments = Mathf.Max(1, oralArmSegments);

        vertices.Clear();
        uvs.Clear();
        colors.Clear();
        triangles.Clear();

        GenerateBell();
        GenerateTentacles();
        GenerateOralArms();

        Mesh mesh = new Mesh { name = "Procedural Jellyfish (Rest Mesh)" };

        if (vertices.Count > 65535)
        {
            mesh.indexFormat = IndexFormat.UInt32;
        }

        mesh.SetVertices(vertices);
        mesh.SetUVs(0, uvs);
        mesh.SetColors(colors);
        mesh.SetTriangles(triangles, 0);
        mesh.RecalculateNormals();
        mesh.RecalculateBounds();

        GetComponent<MeshFilter>().sharedMesh = mesh;
        if (generatedMesh != null)
        {
            if (Application.isPlaying) Destroy(generatedMesh);
            else DestroyImmediate(generatedMesh);
        }
        generatedMesh = mesh;
    }


    // bell: u = 0 at the pole, u = 1 at the rim
    Vector3 BellPosition(float u, float v)
    {
        float angle = v * Mathf.PI * 2f;

        // hemisphere
        float baseRadius = bellRadius * Mathf.Sin(u * Mathf.PI * 0.5f);

        // inward lower rim inset
        float insetMask = Mathf.InverseLerp(rimInsetStart, 1f, u);
        insetMask = insetMask * insetMask * (3f - 2f * insetMask); // smoothstep
        float radius = baseRadius * (1f - rimInset * insetMask);

        float y = bellHeight * (1f - u * u) - rimDrop * Mathf.Pow(u, 8f);
        return new Vector3(radius * Mathf.Cos(angle), y, radius * Mathf.Sin(angle));
    }

    void AddVertex(Vector3 p, Vector2 uv, float partID, float angle01, float rootRadius01 = 0f)
    {
        vertices.Add(p);
        uvs.Add(uv);

        //rgba info to vertex shader
        colors.Add(new Color(partID, angle01, rootRadius01, 1f));
    }

    void AddTriangle(int a, int b, int c)
    {
        triangles.Add(a);
        triangles.Add(b);
        triangles.Add(c);
    }

    void GenerateBell()
    {
        //avoids zero-area triangles at the top
        int pole = vertices.Count;
        AddVertex(BellPosition(0f, 0f), new Vector2(0f, 0f), 0f, 0f);

        int firstRing = vertices.Count;
        int rowStride = angularSegments + 1;
        for (int ring = 1; ring <= bellRings; ring++)
        {
            float u = ring / (float)bellRings;
            for (int j = 0; j <= angularSegments; j++)
            {
                float v = j / (float)angularSegments;
                AddVertex(BellPosition(u, v), new Vector2(u, v), 0f, v);
            }
        }

        // outward-facing winding
        for (int j = 0; j < angularSegments; j++)
            AddTriangle(pole, firstRing + j + 1, firstRing + j);

        for (int ring = 0; ring < bellRings - 1; ring++)
        {
            int row = firstRing + ring * rowStride;
            int next = row + rowStride;
            for (int j = 0; j < angularSegments; j++)
            {
                int a = row + j;
                int b = row + j + 1;
                int c = next + j;
                int d = next + j + 1;
                AddTriangle(a, b, c);
                AddTriangle(b, d, c);
            }
        }
    }

    void GenerateTentacles()
    {
        // golden-angle sampling places roots throughout a disk instead of a ring
        const float goldenAngle = 2.39996323f;
        float inner = Mathf.Clamp01(Mathf.Min(tentacleRootInnerRadius, tentacleRootOuterRadius));
        float outer = Mathf.Clamp01(Mathf.Max(tentacleRootInnerRadius, tentacleRootOuterRadius));

        for (int id = 0; id < tentacleCount; id++)
        {
            float angle = id * goldenAngle;
            float v = Mathf.Repeat(angle / (Mathf.PI * 2f), 1f);
            float areaT = (id + 0.5f) / tentacleCount;
            float rootRadius01 = Mathf.Sqrt(Mathf.Lerp(inner * inner, outer * outer, areaT));

            //r = R * sin(u * PI/2)
            // invert equation
            float bellU = 2f / Mathf.PI * Mathf.Asin(Mathf.Clamp(rootRadius01, 0f, 0.999f));
            Vector3 attachment = BellPosition(bellU, v) + Vector3.down * tentacleRootDepth;

            Vector3 radial = new Vector3(Mathf.Cos(angle), 0f, Mathf.Sin(angle));
            Vector3 tangent = new Vector3(-Mathf.Sin(angle), 0f, Mathf.Cos(angle));

            //psuedo random length
            float strandLength = tentacleLength * (1f + tentacleLengthVariation * Mathf.Sin((id + 1) * 2.7f));

            int first = vertices.Count;
            int stride = tubeSides + 1;
            for (int row = 0; row <= tentacleSegments; row++)
            {
                float t = row / (float)tentacleSegments;
                Vector3 center = attachment + Vector3.down * (strandLength * t);

                float tipWeight = t * t;
                center += radial * (0.07f * tipWeight);
                center += tangent * (0.09f * Mathf.Sin(t * 4f + id * 1.7f) * tipWeight);
                float radius = tentacleRadius * Mathf.Max(0.08f, 1f - t);

                for (int side = 0; side <= tubeSides; side++)
                {
                    float w = side / (float)tubeSides;
                    float around = w * Mathf.PI * 2f;
                    Vector3 offset = (radial * Mathf.Cos(around) + tangent * Mathf.Sin(around)) * radius;
                    AddVertex(center + offset, new Vector2(t, v), 1f, v, rootRadius01);
                }
            }

            for (int row = 0; row < tentacleSegments; row++)
            {
                int current = first + row * stride;
                int next = current + stride;
                for (int side = 0; side < tubeSides; side++)
                {
                    int a = current + side;
                    int b = current + side + 1;
                    int c = next + side;
                    int d = next + side + 1;
                    AddTriangle(a, b, c);
                    AddTriangle(b, d, c);
                }
            }
        }
    }

    void GenerateOralArms()
    {
        for (int id = 0; id < oralArmCount; id++)
        {
            float v = id / (float)oralArmCount;
            float angle = v * Mathf.PI * 2f;
            Vector3 radial = new Vector3(Mathf.Cos(angle), 0f, Mathf.Sin(angle));
            Vector3 sideAxis = new Vector3(-Mathf.Sin(angle), 0f, Mathf.Cos(angle));

            float rootRadius01 = Mathf.Clamp(oralArmOffset / bellRadius, 0f, 0.6f);
            float rootU = 2f / Mathf.PI * Mathf.Asin(rootRadius01);
            Vector3 root = BellPosition(rootU, v) + Vector3.down * oralArmRootDepth;
            
            float totalLength = oralArmLength + Mathf.Max(0f, root.y + 0.04f);
            int first = vertices.Count;

            for (int row = 0; row <= oralArmSegments; row++)
            {
                float t = row / (float)oralArmSegments;
                Vector3 center = root + Vector3.down * (totalLength * t);
                center += radial * (0.08f * t);

                // broader in the middle
                float halfWidth = 0.5f * oralArmWidth * (0.18f + 0.82f * Mathf.Sin(Mathf.PI * t));
                AddVertex(center - sideAxis * halfWidth, new Vector2(t, v), 0.5f, v);
                AddVertex(center + sideAxis * halfWidth, new Vector2(t, v), 0.5f, v);
            }

            for (int row = 0; row < oralArmSegments; row++)
            {
                int a = first + row * 2;
                int b = a + 1;
                int c = a + 2;
                int d = a + 3;
                AddTriangle(a, c, b);
                AddTriangle(b, c, d);
            }
        }
    }

    void OnDestroy()
    {
        if (generatedMesh == null) return;
        if (Application.isPlaying) Destroy(generatedMesh);
        else DestroyImmediate(generatedMesh);
    }
}
