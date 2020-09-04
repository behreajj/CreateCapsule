using System.Text;
using UnityEditor;
using UnityEngine;

public class CapsuleMaker : EditorWindow
{
    public enum UvProfile : int
    {
        Fixed = 0,
        Aspect = 1,
        Uniform = 2
    }

    string folderPath = "Assets/";
    string meshName = "Capsule";
    bool createInstance = true;
    int longitudes = 32;
    int latitudes = 16;
    int rings = 0;
    float depth = 1.0f;
    float radius = 0.5f;
    UvProfile profile = UvProfile.Aspect;

    [MenuItem ("Window/Capsule Maker")]
    static void Init ( )
    {
        CapsuleMaker window = (CapsuleMaker) EditorWindow.GetWindow (
            t: typeof (CapsuleMaker),
            utility: false,
            title: "Capsule Maker",
            focus : true);
        window.Show ( );
    }

    void OnGUI ( )
    {
        meshName = EditorGUILayout.TextField ("Name", meshName);
        folderPath = EditorGUILayout.TextField ("Path", folderPath);
        createInstance = EditorGUILayout.ToggleLeft ("Instantiate", createInstance);

        longitudes = Mathf.Max (3, EditorGUILayout.IntField ("Longitudes", longitudes));
        latitudes = Mathf.Max (2, EditorGUILayout.IntField ("Latitudes", latitudes));
        rings = Mathf.Max (0, EditorGUILayout.IntField ("Rings", rings));
        depth = Mathf.Max (Mathf.Epsilon, EditorGUILayout.FloatField ("Depth", depth));
        radius = Mathf.Max (Mathf.Epsilon, EditorGUILayout.FloatField ("Radius", radius));
        profile = (UvProfile) EditorGUILayout.EnumPopup ("UV Profile", profile);

        if (GUILayout.Button ("Create"))
        {
            Mesh mesh = CreateCapsuleNative ( );
            string pth = new StringBuilder (96)
                .Append (folderPath)
                .Append (meshName)
                .Append (".mesh")
                .ToString ( );
            AssetDatabase.CreateAsset (mesh, pth);
            AssetDatabase.SaveAssets ( );

            if (createInstance)
            {
                GameObject go = InstantMesh (meshName, mesh);
            }
        }
    }

    Mesh CreateCapsuleNative ( )
    {
        bool calcMiddle = rings > 0;
        int halfLats = latitudes / 2;
        int halfLatsn1 = halfLats - 1;
        int halfLatsn2 = halfLats - 2;
        int ringsp1 = rings + 1;
        int lonsp1 = longitudes + 1;
        float halfDepth = depth * 0.5f;
        float summit = halfDepth + radius;

        // Vertex Index offsets.
        int vertOffsetNorthHemi = longitudes;
        int vertOffsetNorthEquator = vertOffsetNorthHemi + lonsp1 * halfLatsn1;
        int vertOffsetCylinder = vertOffsetNorthEquator + lonsp1;
        int vertOffsetSouthEquator = calcMiddle ? vertOffsetCylinder + lonsp1 * rings : vertOffsetCylinder;
        int vertOffsetSouthHemi = vertOffsetSouthEquator + lonsp1;
        int vertOffsetSouthPolar = vertOffsetSouthHemi + lonsp1 * halfLatsn2;
        int vertOffsetSouthCap = vertOffsetSouthPolar + lonsp1;

        // Initialize arrays.
        int vertLen = vertOffsetSouthCap + longitudes;
        Vector3[ ] vs = new Vector3[vertLen];
        Vector2[ ] vts = new Vector2[vertLen];
        Vector3[ ] vns = new Vector3[vertLen];

        Vector2[ ] thetaCartesian = new Vector2[longitudes];
        Vector2[ ] rhoThetaCartesian = new Vector2[longitudes];

        float toTheta = 2.0f * Mathf.PI / longitudes;
        float toPhi = Mathf.PI / latitudes;
        float toTexHorizontal = 1.0f / longitudes;
        float toTexVertical = 1.0f / halfLats;

        // Calculate positions for texture coordinates vertical.
        float vtAspectRatio = 1.0f;
        switch (profile)
        {
            case UvProfile.Aspect:
                vtAspectRatio = radius / (depth + radius + radius);
                break;

            case UvProfile.Uniform:
                vtAspectRatio = (float) halfLats / (ringsp1 + latitudes);
                break;

            case UvProfile.Fixed:
            default:
                vtAspectRatio = 1.0f / 3.0f;
                break;
        }

        float vtAspectNorth = 1.0f - vtAspectRatio;
        float vtAspectSouth = vtAspectRatio;

        // Polar vertices.
        for (int j = 0; j < longitudes; ++j)
        {
            float jf = j;
            float sTexturePolar = 1.0f - (jf + 0.5f) * toTexHorizontal;
            float theta = jf * toTheta;

            float cosTheta = Mathf.Cos (theta);
            float sinTheta = Mathf.Sin (theta);

            thetaCartesian[j] = new Vector2 (cosTheta, sinTheta);
            rhoThetaCartesian[j] = new Vector2 (
                radius * cosTheta,
                radius * sinTheta);

            // North coordinate.
            int idx = j;
            vs[idx] = new Vector3 (0.0f, summit, 0.0f);
            vts[idx] = new Vector2 (sTexturePolar, 1.0f);
            vns[idx] = new Vector3 (0.0f, 1.0f, 0f);

            // South coordinates.
            idx = vertOffsetSouthCap + j;
            vs[idx] = new Vector3 (0.0f, -summit, 0.0f);
            vts[idx] = new Vector2 (sTexturePolar, 0.0f);
            vns[idx] = new Vector3 (0.0f, -1.0f, 0.0f);
        }

        float[ ] sTextureCache = new float[lonsp1];

        // Equatorial vertices.
        for (int j = 0; j < lonsp1; ++j)
        {
            float sTexture = 1.0f - j * toTexHorizontal;
            sTextureCache[j] = sTexture;

            int jMod = j % longitudes;
            Vector2 tc = thetaCartesian[jMod];
            Vector2 rtc = rhoThetaCartesian[jMod];

            // North equator.
            int idx = vertOffsetNorthEquator + j;
            vs[idx] = new Vector3 (rtc.x, halfDepth, -rtc.y);
            vts[idx] = new Vector2 (sTexture, vtAspectNorth);
            vns[idx] = new Vector3 (tc.x, 0.0f, -tc.y);

            // South equator.
            idx = vertOffsetSouthEquator + j;
            vs[idx] = new Vector3 (rtc.x, -halfDepth, -rtc.y);
            vts[idx] = new Vector2 (sTexture, vtAspectSouth);
            vns[idx] = new Vector3 (tc.x, 0.0f, -tc.y);
        }

        // Hemisphere vertices.
        for (int i = 0; i < halfLatsn1; ++i)
        {
            float ip1f = i + 1.0f;
            float phi = ip1f * toPhi;

            // For coordinates.
            float cosPhiSouth = Mathf.Cos (phi);
            float sinPhiSouth = Mathf.Sin (phi);

            // Symmetrical hemispheres mean cosine and sine only needs
            // to be calculated once.
            float cosPhiNorth = sinPhiSouth;
            float sinPhiNorth = -cosPhiSouth;

            float rhoCosPhiNorth = radius * cosPhiNorth;
            float rhoSinPhiNorth = radius * sinPhiNorth;
            float zOffsetNorth = halfDepth - rhoSinPhiNorth;

            float rhoCosPhiSouth = radius * cosPhiSouth;
            float rhoSinPhiSouth = radius * sinPhiSouth;
            float zOffsetSouth = -halfDepth - rhoSinPhiSouth;

            // For texture coordinates.
            float tTexFac = ip1f * toTexVertical;
            float cmplTexFac = 1.0f - tTexFac;
            float tTexNorth = cmplTexFac + vtAspectNorth * tTexFac;
            float tTexSouth = cmplTexFac * vtAspectSouth;

            int iLonsp1 = i * lonsp1;
            int vertCurrLatNorth = vertOffsetNorthHemi + iLonsp1;
            int vertCurrLatSouth = vertOffsetSouthHemi + iLonsp1;

            for (int j = 0; j < lonsp1; ++j)
            {
                int jp1 = j + 1;
                int jMod = j % longitudes;

                float sTexture = sTextureCache[j];
                Vector2 tc = thetaCartesian[jMod];

                // North hemisphere.
                int idx = vertCurrLatNorth + j;
                vs[idx] = new Vector3 (
                    rhoCosPhiNorth * tc.x,
                    zOffsetNorth, // 
                    -rhoCosPhiNorth * tc.y);
                vts[idx] = new Vector2 (sTexture, tTexNorth);
                vns[idx] = new Vector3 (
                    cosPhiNorth * tc.x, //
                    -sinPhiNorth, //
                    -cosPhiNorth * tc.y);

                // South hemisphere.
                idx = vertCurrLatSouth + j;
                vs[idx] = new Vector3 (
                    rhoCosPhiSouth * tc.x,
                    zOffsetSouth, //
                    -rhoCosPhiSouth * tc.y);
                vts[idx] = new Vector2 (sTexture, tTexSouth);
                vns[idx] = new Vector3 (
                    cosPhiSouth * tc.x, //
                    -sinPhiSouth, //
                    -cosPhiSouth * tc.y);

            }
        }

        // Cylinder vertices.
        if (calcMiddle)
        {
            float toFac = 1.0f / ringsp1;
            int idxCylFlat = vertOffsetCylinder;
            for (int h = 1; h < ringsp1; ++h)
            {
                float fac = h * toFac;
                float cmplFac = 1.0f - fac;
                float tTexture = cmplFac * vtAspectNorth + fac * vtAspectSouth;
                float z = cmplFac * halfDepth - fac * halfDepth;

                for (int j = 0; j < lonsp1; ++j)
                {
                    int jMod = j % longitudes;
                    Vector2 tc = thetaCartesian[jMod];
                    Vector2 rtc = rhoThetaCartesian[jMod];
                    float sTexture = sTextureCache[j];

                    vs[idxCylFlat] = new Vector3 (rtc.x, z, -rtc.y);
                    vts[idxCylFlat] = new Vector2 (sTexture, tTexture);
                    vns[idxCylFlat] = new Vector3 (tc.x, 0.0f, -tc.y);

                    ++idxCylFlat;
                }
            }
        }

        // Triangle indices.
        // Stride is 3 for polar triangles;
        // stride is 6 for two triangles forming a quad.
        int lons3 = longitudes * 3;
        int lons6 = longitudes * 6;
        int hemiLons = halfLatsn1 * lons6;

        int triOffsetNorthHemi = lons3;
        int triOffsetCylinder = triOffsetNorthHemi + hemiLons;
        int triOffsetSouthHemi = triOffsetCylinder + ringsp1 * lons6;
        int triOffsetSouthCap = triOffsetSouthHemi + hemiLons;

        int fsLen = triOffsetSouthCap + lons3;
        int[ ] tris = new int[fsLen];

        // Polar caps.
        for (int i = 0, k = 0, m = triOffsetSouthCap; i < longitudes; ++i, k += 3, m += 3)
        {
            tris[k] = i;
            tris[k + 1] = vertOffsetNorthHemi + i;
            tris[k + 2] = vertOffsetNorthHemi + i + 1;

            tris[m] = vertOffsetSouthCap + i;
            tris[m + 1] = vertOffsetSouthPolar + i + 1;
            tris[m + 2] = vertOffsetSouthPolar + i;
        }

        // Hemispheres.
        for (int i = 0, k = triOffsetNorthHemi, m = triOffsetSouthHemi; i < halfLatsn1; ++i)
        {
            int iLonsp1 = i * lonsp1;

            int vertCurrLatNorth = vertOffsetNorthHemi + iLonsp1;
            int vertNextLatNorth = vertCurrLatNorth + lonsp1;

            int vertCurrLatSouth = vertOffsetSouthEquator + iLonsp1;
            int vertNextLatSouth = vertCurrLatSouth + lonsp1;

            for (int j = 0; j < longitudes; ++j, k += 6, m += 6)
            {
                int vn00 = vertCurrLatNorth + j;
                int vn01 = vertNextLatNorth + j;
                int vn11 = vertNextLatNorth + j + 1;
                int vn10 = vertCurrLatNorth + j + 1;

                tris[k] = vn00;
                tris[k + 1] = vn11;
                tris[k + 2] = vn10;

                tris[k + 3] = vn00;
                tris[k + 4] = vn01;
                tris[k + 5] = vn11;

                int vs00 = vertCurrLatSouth + j;
                int vs01 = vertNextLatSouth + j;
                int vs11 = vertNextLatSouth + j + 1;
                int vs10 = vertCurrLatSouth + j + 1;

                tris[m] = vs00;
                tris[m + 1] = vs11;
                tris[m + 2] = vs10;

                tris[m + 3] = vs00;
                tris[m + 4] = vs01;
                tris[m + 5] = vs11;
            }
        }

        // Cylinder.
        for (int i = 0, k = triOffsetCylinder; i < ringsp1; ++i)
        {
            int iLonsp1 = i * lonsp1;
            int vertCurrLat = vertOffsetNorthEquator + iLonsp1;
            int vertNextLat = vertCurrLat + lonsp1;

            for (int j = 0; j < longitudes; ++j, k += 6)
            {
                int v00 = vertCurrLat + j;
                int v01 = vertNextLat + j;
                int v11 = vertNextLat + j + 1;
                int v10 = vertCurrLat + j + 1;

                tris[k] = v00;
                tris[k + 1] = v11;
                tris[k + 2] = v10;

                tris[k + 3] = v00;
                tris[k + 4] = v01;
                tris[k + 5] = v11;
            }
        }

        Mesh mesh = new Mesh ( );
        mesh.vertices = vs;
        mesh.uv = vts;
        mesh.normals = vns;
        mesh.triangles = tris;
        mesh.RecalculateTangents ( );
        mesh.Optimize ( );

        return mesh;
    }

    static GameObject InstantMesh (in string name, in Mesh mesh)
    {
        GameObject go = new GameObject (name);

        MeshFilter mf = go.AddComponent<MeshFilter> ( );
        MeshRenderer mr = go.AddComponent<MeshRenderer> ( );

        mf.sharedMesh = mesh;
        mr.sharedMaterial = AssetDatabase.GetBuiltinExtraResource<Material> ("Default-Diffuse.mat");

        if (mesh.triangles.Length < 768)
        {
            MeshCollider mc = go.AddComponent<MeshCollider> ( );
            mc.sharedMesh = mesh;
            mc.convex = true;
        }

        return go;
    }
}