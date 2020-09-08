using UnityEditor;
using UnityEngine;

public class ShadeFlat
{
    [MenuItem ("CONTEXT/MeshFilter/Shade Flat")]
    public static void CalcFaceNormals (MenuCommand command)
    {
        MeshFilter mf = (MeshFilter) command.context;
        Mesh mesh = mf.sharedMesh;

        int[ ] trisSrc = mesh.triangles;
        Vector3[ ] vsSrc = mesh.vertices;
        Vector2[ ] vtsSrc = mesh.uv;
        Vector3[ ] vnsSrc = mesh.normals;

        int trisSrcLen = trisSrc.Length;

        int[ ] trisTrg = new int[trisSrcLen];
        Vector3[ ] vsTrg = new Vector3[trisSrcLen];
        Vector2[ ] vtsTrg = new Vector2[trisSrcLen];
        Vector3[ ] vnsTrg = new Vector3[trisSrcLen];

        for (int i = 0; i < trisSrcLen; i += 3)
        {
            int j = i + 1;
            int k = i + 2;

            int aIdx = trisSrc[i];
            int bIdx = trisSrc[j];
            int cIdx = trisSrc[k];

            Vector3 a = vsSrc[aIdx];
            Vector3 b = vsSrc[bIdx];
            Vector3 c = vsSrc[cIdx];

            Vector3 vn = Vector3.Normalize (Vector3.Cross (b - a, c - a));

            vnsTrg[i] = vn;
            vnsTrg[j] = vn;
            vnsTrg[k] = vn;

            vsTrg[i] = vsSrc[aIdx];
            vsTrg[j] = vsSrc[bIdx];
            vsTrg[k] = vsSrc[cIdx];

            vtsTrg[i] = vtsSrc[aIdx];
            vtsTrg[j] = vtsSrc[bIdx];
            vtsTrg[k] = vtsSrc[cIdx];

            trisTrg[i] = i;
            trisTrg[j] = j;
            trisTrg[k] = k;
        }

        mesh.vertices = vsTrg;
        mesh.uv = vtsTrg;
        mesh.normals = vnsTrg;
        mesh.triangles = trisTrg;

        mesh.RecalculateTangents ( );
        mesh.Optimize ( );
    }
}