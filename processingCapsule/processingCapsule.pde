import processing.opengl.PShapeOpenGL;

PShape composite;
PShape tessellated;

int longitudes = 32;
int latitudes = 16;
int rings = 1;
float depth = 175.0;
float radius = 75.0;
CapsuleUvProfile profile = CapsuleUvProfile.ASPECT;

void settings() {
  size(720, 405, P3D);
}

void setup() {
  textureWrap(REPEAT);

  Mesh3 mesh = Mesh3.capsule(
    longitudes, latitudes, rings,
    depth, radius, profile);
  // mesh.shadeFlat();

  composite = toPShape((PGraphics3D)getGraphics(), mesh);
  composite.disableStyle();

  PImage texture = loadImage("diagnostic.png");
  tessellated = composite.getTessellation();
  tessellated.setTextureMode(NORMAL);
  tessellated.setTexture(texture);
}

void draw() {
  surface.setTitle(nfs(frameRate, 0, 1));
  background(#ffffff);
  directionalLight(
    255.0, 245.0, 215.0,
    0.0, 0.6, -0.8);
  camera(
    0.0, 0.0, height * 0.86602,
    0.0, 0.0, 0.0,
    0.0, 1.0, 0.0);

  pushMatrix();
  rotate(frameCount * 0.01, 0.8, 0.6, 0.0);
  if (mousePressed) {
    strokeWeight(1.0);
    stroke(#fff7d5);
    fill(#202020);
    shape(composite);
  } else {
    shape(tessellated);
  }
  popMatrix();
}

PShapeOpenGL toPShape(
  final PGraphics3D rndr,
  final Mesh3 source) {

  PVector[] vs = source.coords;
  PVector[] vts = source.texCoords;
  PVector[] vns = source.normals;
  Index3[][] indices = source.indices;

  PShapeOpenGL shape = new PShapeOpenGL(rndr, GROUP);
  shape.set3D(true);
  shape.setTextureMode(NORMAL);
  shape.setName("Capsule");

  int facesLen = indices.length;
  for (int i = 0; i < facesLen; ++i) {
    Index3[] loop = indices[i];
    int loopLen = loop.length;

    PShapeOpenGL face = new PShapeOpenGL(rndr, PShape.GEOMETRY);
    face.set3D(true);
    face.setTextureMode(NORMAL);
    face.setName("face." + nf(i, 3));

    face.beginShape(POLYGON);
    for ( int j = 0; j < loopLen; ++j ) {
      Index3 vert = loop[j];
      PVector v = vs[vert.v];
      PVector vt = vts[vert.vt];
      PVector vn = vns[vert.vn];
      face.normal(vn.x, vn.y, vn.z);
      face.vertex(v.x, v.y, v.z, vt.x, vt.y);
    }
    face.endShape(CLOSE);
    shape.addChild(face);
  }

  return shape;
}
