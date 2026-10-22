using UnityEngine;
using System.Collections.Generic;

[RequireComponent(typeof (MeshFilter))]
[RequireComponent(typeof (MeshRenderer))]
public class BadMinecraft : MonoBehaviour {

    Mesh mesh;
    List<Vector3> vertices;
    List<Vector3> normals;
    List<Vector2> uvs;
    List<int> triangles;

    void Start() {
       MeshFilter meshFilter = GetComponent<MeshFilter>();

        mesh = meshFilter.sharedMesh;
        vertices = new List<Vector3>();
        uvs = new List<Vector2>();
        triangles = new List<int>();

        mesh = CreateCube();
        meshFilter.mesh = mesh;
    }

    Mesh CreateCube()
    {
        mesh = new Mesh();
        float hs = 0.5f;

        // front face +z
        CreateQuad(
            new Vector3(hs, -hs, hs),   //bottom left
            new Vector3(hs, hs, hs),    //top left
            new Vector3(-hs, hs, hs),   //top right
            new Vector3(-hs, -hs, hs),  //bottom right
            new Vector3(0, 0, 1),   //normal
            new Vector2Int(0, 0)
        );

        // back face -z
        CreateQuad(
            new Vector3(-hs, -hs, -hs),   //bottom left
            new Vector3(-hs, hs, -hs),    //top left
            new Vector3(hs, hs, -hs),   //top right
            new Vector3(hs, -hs, hs),  //bottom right
            new Vector3(0, 0, -1),   //normal
            new Vector2Int(0, 0)
        );

        // west face -x
        CreateQuad(
            new Vector3(-hs, -hs, hs),   //bottom left
            new Vector3(-hs, hs, hs),    //top left
            new Vector3(-hs, hs, -hs),   //top right
            new Vector3(-hs, -hs, -hs),  //bottom right
            new Vector3(-1, 0, 0),   //normal
            new Vector2Int(0, 0)
        );

        // east face +x
        CreateQuad(
            new Vector3(hs, -hs, -hs),   //bottom left
            new Vector3(hs, hs, -hs),    //top left
            new Vector3(hs, hs, hs),   //top right
            new Vector3(hs, -hs, hs),  //bottom right
            new Vector3(1, 0, 0),   //normal
            new Vector2Int(0, 0)
        );

        // top face +y
        CreateQuad(
            new Vector3(-hs, hs, -hs),   //bottom left
            new Vector3(-hs, hs, hs),    //top left
            new Vector3(hs, hs, hs),   //top right
            new Vector3(hs, hs, -hs),  //bottom right
            new Vector3(0, 1, 0),   //normal
            new Vector2Int(0, 1)
        );

        // bottom face -y
        CreateQuad(
            new Vector3(hs, -hs, -hs),   //bottom left
            new Vector3(hs, -hs, hs),    //top left
            new Vector3(-hs, -hs, hs),   //top right
            new Vector3(-hs, -hs, -hs),  //bottom right
            new Vector3(0, -1, 0),   //normal
            new Vector2Int(1, 0)
        );

        mesh.vertices = vertices.ToArray();
        mesh.normals = normals.ToArray();



        return mesh;
    }
    
    void CreateQuad(
        Vector3 bl, 
        Vector3 tl, 
        Vector3 tr, 
        Vector3 br, 
        Vector3 normal, 
        Vector2Int uvTile
    )
    {
        int startIndex = vertices.Count;

        vertices.Add(bl);
        vertices.Add(tl);
        vertices.Add(tr);
        vertices.Add(br);

        triangles.Add(startIndex + 0);
        triangles.Add(startIndex + 1);
        triangles.Add(startIndex + 2);
        triangles.Add(startIndex + 0);
        triangles.Add(startIndex + 2);
        triangles.Add(startIndex + 3);

        Vector3[] _normals = { normal, normal, normal, normal };
        normals.AddRange(_normals);

        Vector2 tilePos = new Vector2(uvTile.x, uvTile.y) * 0.5f;
        uvs.Add(new Vector2(0.0f + tilePos.x, 0.0f + tilePos.y));
        uvs.Add(new Vector2(0.0f + tilePos.x, 0.5f + tilePos.y));
        uvs.Add(new Vector2(0.5f + tilePos.x, 0.5f + tilePos.y));
        uvs.Add(new Vector2(0.5f + tilePos.x, 0.0f + tilePos.y));
    }
}