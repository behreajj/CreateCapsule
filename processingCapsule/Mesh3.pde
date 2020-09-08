static class Mesh3 {
  Index3[][] indices;
  PVector[] coords;
  PVector[] texCoords;
  PVector[] normals;

  Mesh3(
    Index3[][] fs,
    PVector[] vs,
    PVector[] vts,
    PVector[] vns) {

    indices = fs;
    coords = vs;
    texCoords = vts;
    normals = vns;
  }

  Mesh3 shadeFlat() {
    int loopsLen = indices.length;
    PVector[] vns = new PVector[loopsLen];

    PVector edge0 = new PVector();
    PVector edge1 = new PVector();
    PVector cross = new PVector();

    for(int i = 0; i < loopsLen; ++i) {
      Index3[] loop = indices[i];
      int loopLen = loop.length;
      
      // Create new face vector.
      PVector vn = vns[i] = new PVector();

      // At loop index 0, the last index is previous.
      Index3 lastVert = loop[loopLen - 1];
      PVector prev = coords[lastVert.v];
      
      // Should be triangles, but assume for simplicity
      // that ngons are properly co planar.
      for(int j = 0; j < loopLen; ++j) {
        Index3 currVert = loop[j];
        Index3 nextVert = loop[(j + 1) % loopLen];
        PVector curr = coords[currVert.v];
        PVector next = coords[nextVert.v];

        // n := (p2 - p0) x (p0 - p1)
        PVector.sub(prev, curr, edge0);
        PVector.sub(curr, next, edge1);
        PVector.cross(edge0, edge1, cross);
        
        // Sum per vertex normals to face normal.
        PVector.add(vn, cross, vn);

        currVert.vn = i;
        prev = curr;
      }
      
      // When 'averaging' the sum accumulated by the face normal,
      // there's no point in dividing by loopLen because normalize
      // is called anyway.
      vn.normalize();
    }

    normals = vns;
    return this;
  }

  static Mesh3 capsule(
    int longitudes,
    int latitudes,
    int rings,
    float depth,
    float radius,
    CapsuleUvProfile profile) {

    // Latitudes must be even for symmetry.
    int verifLats = max(2, latitudes);
    if (verifLats % 2 != 0) {
      verifLats += 1;
    }

    // Validate input arguments.
    int verifLons = max(3, longitudes);
    int verifRings = max(0, rings);
    float verifDepth = max(EPSILON, depth);
    float verifRad = max(EPSILON, radius);

    // Intermediary calculations.
    boolean calcMiddle = verifRings > 0;
    int halfLats = verifLats / 2;
    int halfLatsN1 = halfLats - 1;
    int halfLatsN2 = halfLats - 2;
    int verifRingsp1 = verifRings + 1;
    int verifLonsp1 = verifLons + 1;
    int lonsHalfLatN1 = halfLatsN1 * verifLons;
    int lonsRingsP1 = verifRingsp1 * verifLons;
    float halfDepth = verifDepth * 0.5;
    float summit = halfDepth + verifRad;

    // Index offsets for coordinates.
    int idxVNEquator = verifLonsp1 + verifLons * halfLatsN2;
    int idxVCyl = idxVNEquator + verifLons;
    int idxVSEquator = idxVCyl;
    if (calcMiddle) {
      idxVSEquator += verifLons * verifRings;
    }
    int idxVSouth = idxVSEquator + verifLons;
    int idxVSouthCap = idxVSouth + verifLons * halfLatsN2;
    int idxVSouthPole = idxVSouthCap + verifLons;

    // Index offsets for texture coordinates.
    int idxVtNEquator = verifLons + verifLonsp1 * halfLatsN1;
    int idxVtCyl = idxVtNEquator + verifLonsp1;
    int idxVtSEquator = idxVtCyl;
    if (calcMiddle) {
      idxVtSEquator += verifLonsp1 * verifRings;
    }
    int idxVtSHemi = idxVtSEquator + verifLonsp1;
    int idxVtSPolar = idxVtSHemi + verifLonsp1 * halfLatsN2;
    int idxVtSCap = idxVtSPolar + verifLonsp1;

    // Index offsets for normals.
    int idxVnSouth = idxVNEquator + verifLons;
    int idxVnSouthCap = idxVnSouth + verifLons * halfLatsN2;
    int idxVnSouthPole = idxVnSouthCap + verifLons;

    // Array lengths.
    int vsLen = idxVSouthPole + 1;
    int vtsLen = idxVtSCap + verifLons;
    int vnsLen = idxVnSouthPole + 1;

    PVector[] vs = new PVector[vsLen];
    PVector[] vts = new PVector[vtsLen];
    PVector[] vns = new PVector[vnsLen];

    // North pole.
    vs[0] = new PVector(0.0, summit, 0.0);
    vns[0] = new PVector(0.0, 1.0, 0.0);

    // South pole.
    vs[idxVSouthPole] = new PVector(0.0, -summit, 0.0);
    vns[idxVnSouthPole] = new PVector(0.0, -1.0, 0.0);

    // Calculate polar texture coordinates, equatorial coordinates.
    float[] sinThetaCache = new float[verifLons];
    float[] cosThetaCache = new float[verifLons];
    float toTheta = TAU / verifLons;
    float toPhi = PI / verifLats;
    float toTexHorizontal = 1.0 / verifLons;
    float toTexVertical = 1.0 / halfLats;

    for (int j = 0; j < verifLons; ++j) {

      // Coordinates.
      float theta = j * toTheta;
      float sinTheta = sin(theta);
      float cosTheta = cos(theta);
      sinThetaCache[j] = sinTheta;
      cosThetaCache[j] = cosTheta;

      // Texture coordinates at North and South pole.
      float sTex = ( j + 0.5 ) * toTexHorizontal;
      vts[j] = new PVector(sTex, 1.0);
      vts[idxVtSCap + j] = new PVector(sTex, 0.0);

      // Multiply by radius to get equatorial x and y.
      float x = verifRad * cosTheta;
      float z = verifRad * sinTheta;

      // Set equatorial coordinates. Offset by cylinder depth.
      vs[idxVNEquator + j] = new PVector(x, halfDepth, -z);
      vs[idxVSEquator + j] = new PVector(x, -halfDepth, -z);

      // Set equatorial normals.
      vns[idxVNEquator + j] = new PVector(cosTheta, 0.0, -sinTheta);
    }

    // Determine UV aspect ratio from the profile.
    float vtAspectRatio = 1.0 / 3.0;
    if (profile == CapsuleUvProfile.ASPECT) {
      vtAspectRatio = verifRad / (verifDepth + verifRad + verifRad);
    } else if (profile == CapsuleUvProfile.UNIFORM) {
      vtAspectRatio = (float)halfLats / (verifRingsp1 + verifLats);
    }
    float vtAspectSouth = vtAspectRatio;
    float vtAspectNorth = 1.0 - vtAspectRatio;

    // Cache horizontal measure.
    float[] sTexCache = new float[verifLonsp1];

    // Calculate equatorial texture coordinates.
    for ( int j = 0; j < verifLonsp1; ++j ) {
      float sTex = j * toTexHorizontal;
      sTexCache[j] = sTex;
      vts[idxVtNEquator + j] = new PVector(sTex, vtAspectNorth);
      vts[idxVtSEquator + j] = new PVector(sTex, vtAspectSouth);
    }

    // Divide latitudes into hemispheres. Start at i = 1 due to the poles.
    int vHemiOffsetNorth = 1;
    int vHemiOffsetSouth = idxVSouth;
    int vtHemiOffsetNorth = verifLons;
    int vtHemiOffsetSouth = idxVtSHemi;
    int vnHemiOffsetSouth = idxVnSouth;

    for (int i = 1; i < halfLats; ++i) {
      float phi = i * toPhi;
      float sinPhiSouth = sin(phi);
      float cosPhiSouth = cos(phi);

      // Use trigonometric symmetries to avoid calculating another
      // sine and cosine for phi North.
      float cosPhiNorth = sinPhiSouth;
      float sinPhiNorth = -cosPhiSouth;

      // For North coordinates, multiply by radius and offset.
      float rhoCosPhiNorth = verifRad * cosPhiNorth;
      float rhoSinPhiNorth = verifRad * sinPhiNorth;
      float yOffsetNorth = halfDepth - rhoSinPhiNorth;

      // For South coordinates, multiply by radius and offset.
      float rhoCosPhiSouth = verifRad * cosPhiSouth;
      float rhoSinPhiSouth = verifRad * sinPhiSouth;
      float yOffsetSouth = -halfDepth - rhoSinPhiSouth;

      // Coordinates.
      for ( int j = 0; j < verifLons; ++j ) {
        float sinTheta = sinThetaCache[j];
        float cosTheta = cosThetaCache[j];

        // North coordinate.
        vs[vHemiOffsetNorth] = new PVector(
          rhoCosPhiNorth * cosTheta,
          yOffsetNorth,
          -rhoCosPhiNorth * sinTheta);

        // North normal.
        vns[vHemiOffsetNorth] = new PVector(
          cosPhiNorth * cosTheta,
          -sinPhiNorth,
          -cosPhiNorth * sinTheta);

        // South coordinate.
        vs[vHemiOffsetSouth] = new PVector(
          rhoCosPhiSouth * cosTheta,
          yOffsetSouth,
          -rhoCosPhiSouth * sinTheta);

        // South normal.
        vns[vnHemiOffsetSouth] = new PVector(
          cosPhiSouth * cosTheta,
          -sinPhiSouth,
          -cosPhiSouth * sinTheta);

        ++vHemiOffsetNorth;
        ++vHemiOffsetSouth;
        ++vnHemiOffsetSouth;
      }

      // For UVs, linear interpolation from North pole to
      // North aspect ratio; and from South pole to South
      // aspect ratio.
      float tTexFac = i * toTexVertical;
      float tTexNorth = 1.0 - tTexFac + tTexFac * vtAspectNorth;
      float tTexSouth = vtAspectSouth * (1.0 - tTexFac);

      // Texture coordinates.
      for ( int j = 0; j < verifLonsp1; ++j ) {
        float sTex = sTexCache[j];

        vts[vtHemiOffsetNorth] = new PVector(sTex, tTexNorth);
        vts[vtHemiOffsetSouth] = new PVector(sTex, tTexSouth);

        ++vtHemiOffsetNorth;
        ++vtHemiOffsetSouth;
      }
    }

    // Calculate sections of cylinder in middle.
    if (calcMiddle) {

      // Linear interpolation must exclude the origin (North equator)
      // and the destination (South equator), so step must never equal
      // 0.0 or 1.0 .
      float toFac = 1.0 / verifRingsp1;
      int vCylOffset = idxVCyl;
      int vtCylOffset = idxVtCyl;
      for (int m = 1; m < verifRingsp1; ++m) {
        float fac = m * toFac;
        float cmplFac = 1.0 - fac;

        // Coordinates.
        for (int j = 0; j < verifLons; ++j) {
          PVector vEquatorNorth = vs[idxVNEquator + j];
          PVector vEquatorSouth = vs[idxVSEquator + j];

          // xy should be the same for both North and South.
          // North z should equal half_depth while South z
          // should equal -half_depth. However this is kept as
          // a linear interpolation for clarity.
          vs[vCylOffset] = new PVector(
            cmplFac * vEquatorNorth.x + fac * vEquatorSouth.x,
            cmplFac * vEquatorNorth.y + fac * vEquatorSouth.y,
            cmplFac * vEquatorNorth.z + fac * vEquatorSouth.z);

          ++vCylOffset;
        }

        // Texture coordinates.
        float tTex = cmplFac * vtAspectNorth + fac * vtAspectSouth;
        for (int j = 0; j < verifLonsp1; ++j) {
          float sTex = sTexCache[j];
          vts[vtCylOffset] = new PVector(sTex, tTex);
          ++vtCylOffset;
        }
      }
    }

    // Find index offsets for face indices.
    int idxFsCyl = verifLons + lonsHalfLatN1 * 2;
    int idxFsSouthEquat = idxFsCyl + lonsRingsP1 * 2;
    int idxFsSouthHemi = idxFsSouthEquat + lonsHalfLatN1 * 2;

    int lenIndices = idxFsSouthHemi + verifLons;
    Index3[][] fs = new Index3[lenIndices][3];

    // North & South cap indices (always triangles).
    for (int j = 0; j < verifLons; ++j) {
      int jNextVt = j + 1;
      int jNextV = jNextVt % verifLons;

      // North triangle.
      fs[j] = new Index3[] {
        new Index3(0, j, 0),
        new Index3(jNextVt, verifLons + j, jNextVt),
        new Index3(1 + jNextV, verifLons + jNextVt, 1 + jNextV) };

      // South triangle.
      fs[idxFsSouthHemi + j] = new Index3[] {
        new Index3(
        idxVSouthPole,
        idxVtSCap + j,
        idxVnSouthPole),

        new Index3(
        idxVSouthCap + jNextV,
        idxVtSPolar + jNextVt,
        idxVnSouthCap + jNextV),

        new Index3(
        idxVSouthCap + j,
        idxVtSPolar + j,
        idxVnSouthCap + j) };
    }

    // Hemisphere indices.
    int fHemiOffsetNorth = verifLons;
    int fHemiOffsetSouth = idxFsSouthEquat;
    for ( int i = 0; i < halfLatsN1; ++i ) {
      int iLonsCurr = i * verifLons;

      // North coordinate index offset.
      int vCurrLatN = 1 + iLonsCurr;
      int vNextLatN = vCurrLatN + verifLons;

      // South coordinate index offset.
      int vCurrLatS = idxVSEquator + iLonsCurr;
      int vNextLatS = vCurrLatS + verifLons;

      // North texture coordinate index offset.
      int vtCurrLatN = verifLons + i * verifLonsp1;
      int vtNextLatN = vtCurrLatN + verifLonsp1;

      // South texture coordinate index offset.
      int vtCurrLatS = idxVtSEquator + i * verifLonsp1;
      int vtNextLatS = vtCurrLatS + verifLonsp1;

      // North normal index offset.
      int vnCurrLatN = 1 + iLonsCurr;
      int vnNextLatN = vnCurrLatN + verifLons;

      // South normal index offset.
      int vnCurrLatS = idxVNEquator + iLonsCurr;
      int vnNextLatS = vnCurrLatS + verifLons;

      for ( int j = 0; j < verifLons; ++j ) {
        int jNextVt = j + 1;
        int jNextV = jNextVt % verifLons;

        // North coordinate indices.
        int vn00 = vCurrLatN + j;
        int vn01 = vNextLatN + j;
        int vn11 = vNextLatN + jNextV;
        int vn10 = vCurrLatN + jNextV;

        // South coordinate indices.
        int vs00 = vCurrLatS + j;
        int vs01 = vNextLatS + j;
        int vs11 = vNextLatS + jNextV;
        int vs10 = vCurrLatS + jNextV;

        // North texture coordinate indices.
        int vtn00 = vtCurrLatN + j;
        int vtn01 = vtNextLatN + j;
        int vtn11 = vtNextLatN + jNextVt;
        int vtn10 = vtCurrLatN + jNextVt;

        // South texture coordinate indices.
        int vts00 = vtCurrLatS + j;
        int vts01 = vtNextLatS + j;
        int vts11 = vtNextLatS + jNextVt;
        int vts10 = vtCurrLatS + jNextVt;

        // North normal indices.
        int vnn00 = vnCurrLatN + j;
        int vnn01 = vnNextLatN + j;
        int vnn11 = vnNextLatN + jNextV;
        int vnn10 = vnCurrLatN + jNextV;

        // South normal indices.
        int vns00 = vnCurrLatS + j;
        int vns01 = vnNextLatS + j;
        int vns11 = vnNextLatS + jNextV;
        int vns10 = vnCurrLatS + jNextV;

        // North triangles.
        fs[fHemiOffsetNorth] = new Index3[] {
          new Index3(vn00, vtn00, vnn00),
          new Index3(vn11, vtn11, vnn11),
          new Index3(vn10, vtn10, vnn10) };

        fs[fHemiOffsetNorth + 1] = new Index3[] {
          new Index3(vn00, vtn00, vnn00),
          new Index3(vn01, vtn01, vnn01),
          new Index3(vn11, vtn11, vnn11) };

        // South triangles.
        fs[fHemiOffsetSouth] = new Index3[] {
          new Index3(vs00, vts00, vns00),
          new Index3(vs11, vts11, vns11),
          new Index3(vs10, vts10, vns10) };

        fs[fHemiOffsetSouth + 1] = new Index3[] {
          new Index3(vs00, vts00, vns00),
          new Index3(vs01, vts01, vns01),
          new Index3(vs11, vts11, vns11) };

        fHemiOffsetNorth += 2;
        fHemiOffsetSouth += 2;
      }
    }

    // Cylinder face indices.
    int fCylOffset = idxFsCyl;
    for (int m = 0; m < verifRingsp1; ++m) {
      int vCurrRing = idxVNEquator + m * verifLons;
      int vNextRing = vCurrRing + verifLons;

      int vtCurrRing = idxVtNEquator + m * verifLonsp1;
      int vtNextRing = vtCurrRing + verifLonsp1;

      for (int j = 0; j < verifLons; ++j) {
        int jNextVt = j + 1;
        int jNextV = jNextVt % verifLons;

        // Coordinate corners.
        int v00 = vCurrRing + j;
        int v01 = vNextRing + j;
        int v11 = vNextRing + jNextV;
        int v10 = vCurrRing + jNextV;

        // Texture coordinate corners.
        int vt00 = vtCurrRing + j;
        int vt01 = vtNextRing + j;
        int vt11 = vtNextRing + jNextVt;
        int vt10 = vtCurrRing + jNextVt;

        // Normal corners.
        int vn0 = idxVNEquator + j;
        int vn1 = idxVNEquator + jNextV;

        fs[fCylOffset] = new Index3[] {
          new Index3(v00, vt00, vn0),
          new Index3(v11, vt11, vn1),
          new Index3(v10, vt10, vn1) };

        fs[fCylOffset + 1] = new Index3[] {
          new Index3(v00, vt00, vn0),
          new Index3(v01, vt01, vn0),
          new Index3(v11, vt11, vn1) };

        fCylOffset += 2;
      }
    }

    return new Mesh3(fs, vs, vts, vns);
  }
}
