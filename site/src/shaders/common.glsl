#define INF 3.402823466e+38
#define PI  3.1415926535898

#define SHADOW_BIAS 1.e-3
#define MAX_MARCHING_STEPS 250
#define MAX_MARCHING_DISTANCE 80.

#define SURFACE_DISTANCE .001

#define NULL_CANDIDATE HitCandidate(INF,NULL_MATERIAL)
#define RAYHIT_INFINITY Hit(vec3(INF),vec3(0.),INF,NULL_MATERIAL,false)
#define LIGHT_SPHERE Sphere(scene.pointLights[i].pos,0.1,createUnlitMaterial(light.color))

#define load(P) texelFetch(iChannel1, ivec2(P), 0)

struct Ray{
    vec3 origin;
    vec3 direction;
};

struct Material{
    int type; // -1 - null ; 0 - unlit 1 - solid; 2 - gradient ; 3 - checkerboard
    vec3 albedo;
    float specularPower;
    float specularIntensity;
    vec3 albedo2;
};

#define M_UNLIT 0
#define M_SOLID 1
#define M_GRADIENT 2
#define M_CHECKERBOARD 3

#define NULL_MATERIAL Material(-1, vec3(0.),0.,0., vec3(0.))

Material createUnlitMaterial(vec3 albedo){
    return Material(M_UNLIT, albedo, 0., 0., vec3(0.));
}

Material createSolidMaterial(vec3 albedo, float specularPower, float specularIntensity){
    return Material(M_SOLID, albedo, specularPower, specularIntensity, vec3(0.));
}

Material createGradientMaterial(vec3 albedo1, vec3 albedo2, float specularPower, float specularIntensity){
    return Material(M_GRADIENT, albedo1, specularPower, specularIntensity, albedo2);
}

Material createCheckerboardMaterial(vec3 albedo1, vec3 albedo2, float specularPower, float specularIntensity){
    return Material(M_CHECKERBOARD, albedo1, specularPower, specularIntensity, albedo2);
}

struct Hit{
    vec3 point;
    vec3 normal;
    float dist;
    Material material;
    bool isHit;
};

struct HitCandidate{
    float dist;
    Material material;
};

struct PointLight{
    vec3 pos;
    vec3 color;
    float intensity;
};

struct DirectionalLight{
    vec3 direction;
    vec3 color;
    float intensity;
};

struct Fog{
    float startDistance;
    float intensity;
    vec3 color;
};

struct Sphere{
    vec3 pos;
    float radius;
    Material material;
};

struct Capsule{
    vec3 pos1;
    vec3 pos2;
    float radius;
    Material material;
};

struct Torus{
    vec3 pos;
    float radius1;
    float radius2;
    Material material;
};

struct Box{
    vec3 pos;
    vec3 size;
    Material material;
};

struct Ground{
    float height;
    Material material;
};

float sphereDistance(vec3 point, Sphere sphere){
    return length(point) - sphere.radius;
}

vec2 sphereUV(vec3 p, vec3 center) {
    vec3 dir = normalize(p - center);
    float u = 0.5 + atan(dir.z, dir.x) / (2.0 * 3.1415926);
    float v = 0.5 - asin(dir.y) / 3.1415926;
    return vec2(u, v);
}

float capsuleDistance(vec3 point, Capsule capsule){
    vec3 p1 = capsule.pos1 - (capsule.pos1 + capsule.pos2)*0.5;
    vec3 p2 = capsule.pos2 - (capsule.pos1 + capsule.pos2)*0.5;

    vec3 p1ToP2 = p2 - p1;
    vec3 p1ToP = point - p1;

    float closestDist = dot(p1ToP2,p1ToP) / dot(p1ToP2,p1ToP2);
    closestDist = clamp(closestDist, 0., 1.);

    vec3 closest = p1 + p1ToP2 * closestDist;

    return length(point - closest) - capsule.radius;
}

float torusDistance(vec3 point, Torus torus){
    vec3 p = point;
    vec2 distToInnerCircle = vec2(length(p.xz)-torus.radius1, p.y);
    return length(distToInnerCircle) - torus.radius2;
}

float boxDistance(vec3 point, Box box){
    vec3 p = point; 
    vec3 q = abs(p) - box.size;
    return length(max(q,0.)) + min(max(q.x,max(q.y,q.z)),0.);
}

float opSmoothUnion( float d1, float d2, float k ) {
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h);
}

float opSmoothSubtraction( float d1, float d2, float k ) {
    float h = clamp( 0.5 - 0.5*(d2+d1)/k, 0.0, 1.0 );
    return mix( d2, -d1, h ) + k*h*(1.0-h);
}

float opSmoothIntersection( float d1, float d2, float k )
{
    float h = clamp( 0.5 - 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) + k*h*(1.0-h);
}

vec3 opRepetition( in vec3 p, in float s) {
    return p - s*round(p/s);
}

vec3 opLimitedRepetition( in vec3 p, in float s, in vec3 l) {
    return p - s*clamp(round(p/s),-l,l);
}

float opDisplace( in float d1, in vec3 p, in float i ) {
    float d2 = 0.5*sin(i*p.x)*sin(i*p.y)*sin(i*p.z);
    return d1+d2;
}

vec3 opTwist( in float k, in vec3 p ) {
    float c = cos(k*p.y);
    float s = sin(k*p.y);
    mat2  m = mat2(c,-s,s,c);
    return vec3(m*p.xz,p.y);
}

mat3 CameraRotation( vec2 m )
{
    vec2 s = sin(m);
    vec2 c = cos(m);
    mat3 rotX = mat3(
        1.0, 0.0, 0.0, 
        0.0, c.y, s.y, 
        0.0, -s.y, c.y
    );
    mat3 rotY = mat3(
        -c.x, 0.0, -s.x, 
        0.0, 1.0, 0.0, 
        s.x, 0.0, -c.x
    );
    
    return rotY * rotX;
}

/* 
    Quaternion Rotation by Dirk Storckton 
    https://www.shadertoy.com/view/dttGWj 
*/

vec4 quanternionMul(vec4 q1, vec4 q2) {
    vec3 crossProduct = cross(q1.xyz, q2.xyz);
    float dotProduct = dot(q1.xyz, q2.xyz);
    return vec4(crossProduct + q1.w*q2.xyz + q2.w*q1.xyz, q1.w*q2.w - dotProduct);
}
    
vec4 quanternionRot(vec3 axis, float angle) {
    float halfAngle = angle * 0.5;
    float s = sin(halfAngle);
    return vec4(axis * s, cos(halfAngle));
}
    
vec3 rotate3D(vec3 p, vec3 axis, float angle) {
    vec4 quat = quanternionRot(normalize(axis), angle);
    return quanternionMul(quanternionMul(quat, vec4(p, 0.0)), vec4(-quat.xyz, quat.w)).xyz;
}

/*
    Simplex Noise by Ian McEwan, Ashima Arts
    https://thebookofshaders.com/edit.php?log=180302095423
*/
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec2 mod289(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 permute(vec3 x) { return mod289(((x*34.0)+1.0)*x); }
float simplexNoise(vec2 uv){
    // Precompute values for skewed triangular grid
    const vec4 C = vec4(0.211324865405187,
                        // (3.0-sqrt(3.0))/6.0
                        0.366025403784439,
                        // 0.5*(sqrt(3.0)-1.0)
                        -0.577350269189626,
                        // -1.0 + 2.0 * C.x
                        0.024390243902439);
                        // 1.0 / 41.0

    // First corner (x0)
    vec2 i  = floor(uv + dot(uv, C.yy));
    vec2 x0 = uv - i + dot(i, C.xx);

    // Other two corners (x1, x2)
    vec2 i1 = vec2(0.0);
    i1 = (x0.x > x0.y)? vec2(1.0, 0.0):vec2(0.0, 1.0);
    vec2 x1 = x0.xy + C.xx - i1;
    vec2 x2 = x0.xy + C.zz;

    // Do some permutations to avoid
    // truncation effects in permutation
    i = mod289(i);
    vec3 p = permute(
            permute( i.y + vec3(0.0, i1.y, 1.0))
                + i.x + vec3(0.0, i1.x, 1.0 ));

    vec3 m = max(0.5 - vec3(
                        dot(x0,x0),
                        dot(x1,x1),
                        dot(x2,x2)
                        ), 0.0);

    m = m*m ;
    m = m*m ;

    // Gradients:
    //  41 pts uniformly over a line, mapped onto a diamond
    //  The ring size 17*17 = 289 is close to a multiple
    //      of 41 (41*7 = 287)

    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;

    // Normalise gradients implicitly by scaling m
    // Approximation of: m *= inversesqrt(a0*a0 + h*h);
    m *= 1.79284291400159 - 0.85373472095314 * (a0*a0+h*h);

    // Compute final noise value at P
    vec3 g = vec3(0.0);
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * vec2(x1.x,x2.x) + h.yz * vec2(x1.y,x2.y);
    return 130.0 * dot(m, g) *.5 + .5;
}

float simplexNoiseFBM(vec2 uv, float layers){
  float c = 0.;
  
  for(float i=0.0; i<layers; i+=1.0){
      float t = pow(2., i);
      c += simplexNoise(uv*t)/t;
  }

  return c*0.5;
}

/* Stanford Bunny SDF taken from https://www.shadertoy.com/view/WlVyDc */
float stanfordBunnyDist(vec3 p){
    //sdf is undefined outside the unit sphere, uncomment to witness the abominations
    if (length(p) > 1.) {
        return length(p)-.8;
    }
    
    p = vec3(p.x, -p.z, p.y);
    p = vec3(p.y, -p.x, p.z);
    
    //neural networks can be really compact... when they want to be
    vec4 f00=sin(p.y*vec4(-3.02,1.95,-3.42,-.60)+p.z*vec4(3.08,.85,-2.25,-.24)-p.x*vec4(-.29,1.16,-3.74,2.89)+vec4(-.71,4.50,-3.24,-3.50));
    vec4 f01=sin(p.y*vec4(-.40,-3.61,3.23,-.14)+p.z*vec4(-.36,3.64,-3.91,2.66)-p.x*vec4(2.90,-.54,-2.75,2.71)+vec4(7.02,-5.41,-1.12,-7.41));
    vec4 f02=sin(p.y*vec4(-1.77,-1.28,-4.29,-3.20)+p.z*vec4(-3.49,-2.81,-.64,2.79)-p.x*vec4(3.15,2.14,-3.85,1.83)+vec4(-2.07,4.49,5.33,-2.17));
    vec4 f03=sin(p.y*vec4(-.49,.68,3.05,.42)+p.z*vec4(-2.87,.78,3.78,-3.41)-p.x*vec4(-2.65,.33,.07,-.64)+vec4(-3.24,-5.90,1.14,-4.71));
    vec4 f10=sin(mat4(-.34,.06,-.59,-.76,.10,-.19,-.12,.44,.64,-.02,-.26,.15,-.16,.21,.91,.15)*f00+
        mat4(.01,.54,-.77,.11,.06,-.14,.43,.51,-.18,.08,.39,.20,.33,-.49,-.10,.19)*f01+
        mat4(.27,.22,.43,.53,.18,-.17,.23,-.64,-.14,.02,-.10,.16,-.13,-.06,-.04,-.36)*f02+
        mat4(-.13,.29,-.29,.08,1.13,.02,-.83,.32,-.32,.04,-.31,-.16,.14,-.03,-.20,.39)*f03+
        vec4(.73,-4.28,-1.56,-1.80))/1.0+f00;
    vec4 f11=sin(mat4(-1.11,.55,-.12,-1.00,.16,.15,-.30,.31,-.01,.01,.31,-.42,-.29,.38,-.04,.71)*f00+
        mat4(.96,-.02,.86,.52,-.14,.60,.44,.43,.02,-.15,-.49,-.05,-.06,-.25,-.03,-.22)*f01+
        mat4(.52,.44,-.05,-.11,-.56,-.10,-.61,-.40,-.04,.55,.32,-.07,-.02,.28,.26,-.49)*f02+
        mat4(.02,-.32,.06,-.17,-.59,.00,-.24,.60,-.06,.13,-.21,-.27,-.12,-.14,.58,-.55)*f03+
        vec4(-2.24,-3.48,-.80,1.41))/1.0+f01;
    vec4 f12=sin(mat4(.44,-.06,-.79,-.46,.05,-.60,.30,.36,.35,.12,.02,.12,.40,-.26,.63,-.21)*f00+
        mat4(-.48,.43,-.73,-.40,.11,-.01,.71,.05,-.25,.25,-.28,-.20,.32,-.02,-.84,.16)*f01+
        mat4(.39,-.07,.90,.36,-.38,-.27,-1.86,-.39,.48,-.20,-.05,.10,-.00,-.21,.29,.63)*f02+
        mat4(.46,-.32,.06,.09,.72,-.47,.81,.78,.90,.02,-.21,.08,-.16,.22,.32,-.13)*f03+
        vec4(3.38,1.20,.84,1.41))/1.0+f02;
    vec4 f13=sin(mat4(-.41,-.24,-.71,-.25,-.24,-.75,-.09,.02,-.27,-.42,.02,.03,-.01,.51,-.12,-1.24)*f00+
        mat4(.64,.31,-1.36,.61,-.34,.11,.14,.79,.22,-.16,-.29,-.70,.02,-.37,.49,.39)*f01+
        mat4(.79,.47,.54,-.47,-1.13,-.35,-1.03,-.22,-.67,-.26,.10,.21,-.07,-.73,-.11,.72)*f02+
        mat4(.43,-.23,.13,.09,1.38,-.63,1.57,-.20,.39,-.14,.42,.13,-.57,-.08,-.21,.21)*f03+
        vec4(-.34,-3.28,.43,-.52))/1.0+f03;
    f00=sin(mat4(-.72,.23,-.89,.52,.38,.19,-.16,-.88,.26,-.37,.09,.63,.29,-.72,.30,-.95)*f10+
        mat4(-.22,-.51,-.42,-.73,-.32,.00,-1.03,1.17,-.20,-.03,-.13,-.16,-.41,.09,.36,-.84)*f11+
        mat4(-.21,.01,.33,.47,.05,.20,-.44,-1.04,.13,.12,-.13,.31,.01,-.34,.41,-.34)*f12+
        mat4(-.13,-.06,-.39,-.22,.48,.25,.24,-.97,-.34,.14,.42,-.00,-.44,.05,.09,-.95)*f13+
        vec4(.48,.87,-.87,-2.06))/1.4+f10;
    f01=sin(mat4(-.27,.29,-.21,.15,.34,-.23,.85,-.09,-1.15,-.24,-.05,-.25,-.12,-.73,-.17,-.37)*f10+
        mat4(-1.11,.35,-.93,-.06,-.79,-.03,-.46,-.37,.60,-.37,-.14,.45,-.03,-.21,.02,.59)*f11+
        mat4(-.92,-.17,-.58,-.18,.58,.60,.83,-1.04,-.80,-.16,.23,-.11,.08,.16,.76,.61)*f12+
        mat4(.29,.45,.30,.39,-.91,.66,-.35,-.35,.21,.16,-.54,-.63,1.10,-.38,.20,.15)*f13+
        vec4(-1.72,-.14,1.92,2.08))/1.4+f11;
    f02=sin(mat4(1.00,.66,1.30,-.51,.88,.25,-.67,.03,-.68,-.08,-.12,-.14,.46,1.15,.38,-.10)*f10+
        mat4(.51,-.57,.41,-.09,.68,-.50,-.04,-1.01,.20,.44,-.60,.46,-.09,-.37,-1.30,.04)*f11+
        mat4(.14,.29,-.45,-.06,-.65,.33,-.37,-.95,.71,-.07,1.00,-.60,-1.68,-.20,-.00,-.70)*f12+
        mat4(-.31,.69,.56,.13,.95,.36,.56,.59,-.63,.52,-.30,.17,1.23,.72,.95,.75)*f13+
        vec4(-.90,-3.26,-.44,-3.11))/1.4+f12;
    f03=sin(mat4(.51,-.98,-.28,.16,-.22,-.17,-1.03,.22,.70,-.15,.12,.43,.78,.67,-.85,-.25)*f10+
        mat4(.81,.60,-.89,.61,-1.03,-.33,.60,-.11,-.06,.01,-.02,-.44,.73,.69,1.02,.62)*f11+
        mat4(-.10,.52,.80,-.65,.40,-.75,.47,1.56,.03,.05,.08,.31,-.03,.22,-1.63,.07)*f12+
        mat4(-.18,-.07,-1.22,.48,-.01,.56,.07,.15,.24,.25,-.09,-.54,.23,-.08,.20,.36)*f13+
        vec4(-1.11,-4.28,1.02,-.23))/1.4+f13;
    return dot(f00,vec4(.09,.12,-.07,-.03))+dot(f01,vec4(-.04,.07,-.08,.05))+
        dot(f02,vec4(-.01,.06,-.02,.07))+dot(f03,vec4(-.05,.07,.03,.04))-0.16;
}
