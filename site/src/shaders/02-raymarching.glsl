#define SHADOW_BIAS 1.e-4
#define MAX_MARCHING_STEPS 150
#define MAX_MARCHING_DISTANCE 40.

#define SURFACE_DISTANCE .0001

#define INF 3.402823466e+38
#define PI  3.1415926535898

#define NULL_MATERIAL Material(vec3(0.),0.,0.,false)
#define NULL_CANDIDATE HitCandidate(INF,NULL_MATERIAL);
#define RAYHIT_INFINITY Hit(vec3(INF),vec3(0.),INF,NULL_MATERIAL,false)
#define LIGHT_SPHERE Sphere(light.pos,0.1,Material(light.color,0.,0.,false))

struct Ray{
    vec3 origin;
    vec3 direction;
};

struct Material{
    vec3 albedo;
    float specularPower;
    float specularIntensity;
    bool isLit;
};

struct Hit{
    vec3 point;
    vec3 normal;
    float dist;
    Material material;
    bool isHit;
};


struct Sphere{
    vec3 pos;
    float radius;
    Material material;
};

struct Light{
    vec3 pos;
    vec3 color;
    float intensity;
};

struct Scene{
    Sphere[2] spheres;
    Light light;
};

struct HitCandidate{
    float dist;
    Material material;
};

Scene createScene(){
    Material groundMaterial = Material(
        vec3(1.), // albedo
        150., // specular power
        0., // specular intensity
        true // is lit
    );


    Material sphereMaterial = Material(
        vec3(1.0, 0.0, 0.0), // albedo
        150., // specular power
        0.5, // specular intensity
        true // is lit
    );

    Sphere s1 = Sphere(
        vec3(0., 0., -5.),
        1.,
        sphereMaterial
    );
    
    Sphere ground = Sphere(
        vec3(2., -1001., -5.),
        1000.,
        groundMaterial
    );
    
    Sphere[2] spheres = Sphere[](s1, ground);
    
    Light light = Light(
        vec3(0. + cos(iTime)*2., 0.5, -5. + sin(iTime)*2.), // position
        vec3(1.), // color
        15. // intensity
    );
     
    
    Scene scene = Scene(spheres, light);
    return scene;
}

float sphereDistance(vec3 point, Sphere sphere){
    return length(point- sphere.pos) - sphere.radius;
}

HitCandidate getDist(vec3 point, Scene scene){
    HitCandidate minDist = NULL_CANDIDATE;

    for(int i = 0; i < 2; i++){
        float dist = sphereDistance(point, scene.spheres[i]);
        
        if(dist < minDist.dist){
            minDist.dist = dist;
            minDist.material = scene.spheres[i].material;
        }
    }
    // render sphere in point light's location
    return minDist;
}

vec3 getNormal(vec3 point,float d, Scene scene){
    vec2 e = vec2(.01, 0);
    HitCandidate n1 = getDist(point - e.xyy, scene);
    HitCandidate n2 = getDist(point - e.yxy, scene);
    HitCandidate n3 = getDist(point - e.yyx, scene);
    
    vec3 stretchedNormal = d-vec3(
        n1.dist,
        n2.dist,
        n3.dist
    );
    return normalize(stretchedNormal);
}

Hit marchRay(Ray ray, Scene scene){
    float distToCamera = 0.;
    bool isHit = false;
    vec3 marchPos = ray.origin;
    HitCandidate nextStepHit = NULL_CANDIDATE;
    for(int stp=0; stp<MAX_MARCHING_STEPS; stp++){
        marchPos = ray.origin + (distToCamera * ray.direction);
        nextStepHit = getDist(marchPos, scene);
        distToCamera += nextStepHit.dist;
        if(nextStepHit.dist < SURFACE_DISTANCE){
            isHit = true;
            break;
        }
        if(distToCamera > MAX_MARCHING_DISTANCE){
            isHit = false;
            break;
        }
    }
    // generate Hit
    Hit hit = Hit(
        marchPos,
        getNormal(marchPos,nextStepHit.dist, scene),
        distToCamera,
        nextStepHit.material,
        isHit); 
    return hit;
}

vec3 getLight(Hit hit, Ray ray, Scene scene)
{
    // Unlit material
    return hit.material.albedo;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    Scene scene = createScene();

    vec2 uv = (fragCoord - .5*iResolution.xy) / iResolution.y;
    vec3 color = vec3(0.);
    
    // Creating Ray
    vec3 rayOrigin = vec3(0., 0., 1.);
    vec3 rayDirection = normalize(vec3(uv.xy, 0.) - rayOrigin);
    Ray ray = Ray(rayOrigin, rayDirection);
    
    // Marching Ray
    Hit hit = marchRay(ray, scene);
    
    if (hit.isHit) color = getLight(hit, ray, scene);
    
    // Output to screen
    fragColor = vec4(color,1.0);
}
