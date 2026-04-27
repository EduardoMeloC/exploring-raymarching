#define SHADOW_BIAS 1.e-4

#define INF 3.402823466e+38
#define PI  3.1415926535898

#define NULL_MATERIAL Material(vec3(0.),0.,0.,false)
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

Hit raySphereIntersection(Sphere sphere, Ray ray){
    Hit hit = RAYHIT_INFINITY;

    vec3 ro = ray.origin;
    vec3 rd = ray.direction;
    vec3 s = sphere.pos;
    float R = sphere.radius;

    float t = dot(s - ro, rd);
    if(t < 0.) return hit;
    vec3 p = ro + rd * t;
    
    float y = length(s - p);
    if(y > R) return hit;
    float x = sqrt(R*R - y*y);
    
    float temp1 = t - x;
    float temp2 = t + x;
    float t1 = min(temp1, temp2);
    if (t1 < 0.) return hit;
    float dist = t1;
    
    hit.point = ro + rd * dist;
    hit.normal = normalize(hit.point - sphere.pos);
    hit.dist = dist;
    hit.material = sphere.material;
    hit.isHit = true;
    
    return hit;
}

Hit castRay(Ray ray, Scene scene){
    Hit closestHit = RAYHIT_INFINITY;
    
    for(int i = 0; i < 2; i++){
        Hit hit = raySphereIntersection(scene.spheres[i], ray);
        
        if(hit.dist < closestHit.dist) closestHit = hit;
    }
    
    return closestHit;
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
    
    // Casting Ray
    Hit hit = castRay(ray, scene);
    
    if (hit.isHit) color = getLight(hit, ray, scene);
    
    // Output to screen
    fragColor = vec4(color,1.0);
}
