// Demonstrates SDF boolean operations and smooth union.
// Three shapes blend together over time.

float sdSphere(vec3 p, float r) { return length(p) - r; }

float sdBox(vec3 p, vec3 b) {
  vec3 q = abs(p) - b;
  return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float opSmoothUnion(float a, float b, float k) {
  float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}

float scene(vec3 p) {
  float k = 0.6 + 0.5 * sin(iTime * 0.7);
  float s1 = sdSphere(p - vec3( sin(iTime * 0.8) * 1.1, 0.0,  0.0), 0.7);
  float s2 = sdSphere(p - vec3(-sin(iTime * 0.8) * 1.1, 0.0,  0.0), 0.7);
  float b  = sdBox(p - vec3(0.0, sin(iTime * 0.6) * 0.8, 0.0), vec3(0.35));
  return opSmoothUnion(opSmoothUnion(s1, s2, k), b, k * 0.5);
}

float march(vec3 ro, vec3 rd) {
  float t = 0.0;
  for (int i = 0; i < 80; i++) {
    float d = scene(ro + rd * t);
    if (d < 0.001) return t;
    if (t > 20.0)  return -1.0;
    t += d;
  }
  return -1.0;
}

vec3 normal(vec3 p) {
  vec2 e = vec2(0.001, 0.0);
  return normalize(vec3(
    scene(p + e.xyy) - scene(p - e.xyy),
    scene(p + e.yxy) - scene(p - e.yxy),
    scene(p + e.yyx) - scene(p - e.yyx)
  ));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

  vec3 ro = vec3(0.0, 0.0, 4.0);
  vec3 rd = normalize(vec3(uv, -1.0));

  vec3 col = vec3(0.05, 0.05, 0.08);

  float t = march(ro, rd);
  if (t > 0.0) {
    vec3 p = ro + rd * t;
    vec3 n = normal(p);
    vec3 l = normalize(vec3(1.5, 2.0, 2.0));
    float diff = max(dot(n, l), 0.0);
    float spec = pow(max(dot(reflect(-l, n), -rd), 0.0), 32.0);
    col = vec3(0.5, 0.4, 1.0) * (0.08 + 0.85 * diff) + vec3(0.6) * spec * 0.4;
  }

  fragColor = vec4(col, 1.0);
}
