const ivec2 POSITION = ivec2(1, 0);
const ivec2 VMOUSE = ivec2(1, 1);

/* 
   SCENE_SPHERE, 
   SCENE_BOX, 
   SCENE_TRANSFORMATIONS, 
   SCENE_OPERATIONS, 
   SCENE_SMOOTH, 
   SCENE_DOMAIN_REPETITION, 
   SCENE_WAVE_DISTORTION,
   SCENE_DOMAIN_WARP,
   SCENE_STANFORD_BUNNY,
   SCENE_METABALLS
*/
#define SCENE_METABALLS

#define NLIGHTS 1
#define RENDER_LIGHT_SPHERE

#define SPHERE_MATERIAL createSolidMaterial(vec3(1.0, 0.0, 0.0), 130., 0.7)
#define BOX_MATERIAL createSolidMaterial(vec3(1.0, 0.0, 0.0), 10., 0.3)

struct Scene{
    DirectionalLight dirLight;
    PointLight[NLIGHTS] pointLights;
    vec3 ambientLight;
    Fog fog;
};

Scene createScene(){
    DirectionalLight dirLight = DirectionalLight(
        // normalize(vec3(cos(iTime), -1., -sin(iTime))),
        normalize(vec3(-2., -3., -5.)),
        vec3(0.788235294117647, 0.8862745098039215, 1.0),
        20.
    );
    
    PointLight[NLIGHTS] pointLights; 
    pointLights[0] = PointLight(
        vec3(2., 2., 2.),
        vec3(0.988235294117647, 0.9862745098039215, 0.9),
        14.
    );

    vec3 ambientLight = dirLight.color * 0.05 + iBackground * 0.15;

    Fog fog = Fog(
        10., // dist
        0.02, // intensity
        iBackground // color
    );
    
    Scene scene = Scene(dirLight, pointLights, ambientLight, fog);
    return scene;
}

vec3 getAlbedo(Hit hit){
    switch(hit.material.type){
        case M_SOLID:
            return hit.material.albedo;
            break;
        case M_GRADIENT:
            return hit.material.albedo; // TODO
            break;
        case M_CHECKERBOARD:
            float Size = 2.0;
            vec3 OffsetCoord = hit.point - vec3(Size / 2.0);
            vec3 Pos = floor(OffsetCoord / Size);
            float PatternMask = mod(Pos.x + mod(Pos.z, 2.0), 2.0);
            vec3 albedo = PatternMask * hit.material.albedo + (1.-PatternMask) * hit.material.albedo2;
            return albedo;
            break;
    }
}

#ifdef SCENE_SPHERE
HitCandidate getDist(vec3 point, Scene scene){
    HitCandidate minDist = NULL_CANDIDATE;

    float sphereDist = sphereDistance(point - vec3(0., 2., -5.), Sphere(vec3(0.), 1., NULL_MATERIAL));

    if(sphereDist < minDist.dist){
        minDist.dist = sphereDist;
        minDist.material = SPHERE_MATERIAL;
    }

    return minDist;
}
#endif

#ifdef SCENE_BOX
HitCandidate getDist(vec3 point, Scene scene){
    HitCandidate minDist = NULL_CANDIDATE;

    vec3 boxPosition = vec3(0.0, 2., -5.0);
    vec3 rotAxis = normalize(vec3(1.0, -1.0, 0.0));
    float rotAngle = iTime;

    vec3 pLocal = point - boxPosition; // Step 1: move point into local space
    pLocal = rotate3D(pLocal, rotAxis, -rotAngle); // Step 2: undo box rotation

    float boxDist = boxDistance(pLocal, Box(vec3(0.0), vec3(1.0), NULL_MATERIAL));

    if(boxDist < minDist.dist){
        minDist.dist = boxDist;
        minDist.material = BOX_MATERIAL;
    }

    return minDist;
}
#endif

#ifdef SCENE_TRANSFORMATIONS
HitCandidate getDist(vec3 point, Scene scene){
    HitCandidate minDist = NULL_CANDIDATE;
    
    // Scale 2X along Y
    mat4 S = mat4(
        vec4(1., 0., 0., 0.),
        vec4(0., 2., 0., 0.),
        vec4(0., 0., 1., 0.),
        vec4(0., 0., 0., 1.)
    );
    
    // Rotation in XY
    float t = PI/4.;
    mat4 R = mat4(
        vec4(cos(t), sin(t), 0., 0.),
        vec4(-sin(t), cos(t), 0., 0.),
        vec4(0., 0., 1., 0.),
        vec4(0., 0., 0., 1.)
    );
    
    // Translate to (-2., -1., -1.) (relative to 0., 2., -5.)
    mat4 T = mat4(
        vec4(1., 0., 0., -2.),
        vec4(0., 1., 0., -1.),
        vec4(0., 0., 1., -1.),
        vec4(0., 0., 0., 1.)
    );
    
    
    mat4 matrices[4];
    matrices[0] = mat4(1.0);
    matrices[1] = S;
    matrices[2] = S * R;
    matrices[3] = S * R * T;
    
    float animationSpeed = 1. / PI;
    float animationTime = iTime * animationSpeed;
    float fractT = fract(animationTime);
    int index = int(mod(floor(animationTime), 4.));
    int nextIndex = (index + 1) % 4;
    float hold = 0.5;
    float interpolator = clamp((fractT - hold) / (1.0 - hold), 0.0, 1.0);
    
    mat4 m1 = matrices[index];
    mat4 m2 = matrices[nextIndex];
    mat4 transformationMatrix = (m1 * (1.-interpolator) + m2 * interpolator);
    
    vec3 transformedPoint = (vec4(point - vec3(0., 2., -5.), 1.) * inverse(transformationMatrix)).xyz;

    float sphereDist = sphereDistance(transformedPoint, Sphere(vec3(0.), 1., NULL_MATERIAL));

    if(sphereDist < minDist.dist){
        minDist.dist = sphereDist;
        minDist.material = SPHERE_MATERIAL;
    }

    return minDist;
}
#endif

#ifdef SCENE_OPERATIONS
HitCandidate getDist(vec3 point, Scene scene){
    HitCandidate minDist = NULL_CANDIDATE;

    vec3 boxPosition = vec3(0.0, 2., -5.0);
    vec3 rotAxis = normalize(vec3(1.0, -1.0, 0.0));
    float rotAngle = iTime;

    vec3 pLocal = point - boxPosition;
    pLocal = rotate3D(pLocal, rotAxis, -rotAngle);
    
    Material boxMat = BOX_MATERIAL;
    Material sphereMat = SPHERE_MATERIAL;
    float boxDist = boxDistance(
        pLocal, 
        Box(
            boxPosition, // position
            vec3(1.0), // scale
            boxMat // material
        )
    );
    float sphereDist = sphereDistance(
        pLocal, 
        Sphere(
            boxPosition, // position 
            1.25, // radius
            sphereMat // material
        )
    );
    
    float unionDist = min(boxDist, sphereDist);
    float intersectionDist = max(boxDist, sphereDist);
    float subtractionDist1 = max(-sphereDist, boxDist);
    float subtractionDist2 = max(-boxDist, sphereDist);
    
    int distIndex = int(mod(floor(iTime * (1./PI)), 6.));
    float d;
    Material mat;
    switch(distIndex){
        case 0: d = boxDist;                                     mat = boxMat;                          break;
        case 1: d = sphereDist;                                  mat = sphereMat;                       break;
        case 2: d = unionDist;        if (boxDist < sphereDist)  mat = boxMat;    else mat = sphereMat; break;
        case 3: d = intersectionDist; if (boxDist > sphereDist)  mat = boxMat;    else mat = sphereMat; break;
        case 4: d = subtractionDist1; if (boxDist > -sphereDist) mat = boxMat;    else mat = sphereMat; break;
        case 5: d = subtractionDist2; if (sphereDist > -boxDist) mat = sphereMat; else mat = boxMat;    break;
    }
    if(d < minDist.dist){
        minDist.dist = d;
        minDist.material = mat;
    }

    return minDist;
}
#endif

#ifdef SCENE_SMOOTH
HitCandidate getDist(vec3 point, Scene scene){
    HitCandidate minDist = NULL_CANDIDATE;

    vec3 boxPosition = vec3(0.0, 2.5, -7.0);
    vec3 rotAxis = normalize(vec3(0.6, 0.0, 0.0));
    float rotAngle = PI/4.;

    // Compute forward direction in world space
    vec3 forward = rotate3D(vec3(0.0, -1.0, 0.0), rotAxis, rotAngle);

    // Move point into local space
    vec3 pLocal = point - (boxPosition + forward * 0.5);

    // Undo cube rotation
    pLocal = rotate3D(pLocal, rotAxis, -rotAngle);
    
    vec3 gap = vec3(4.0, 0., 0.);
    
    float[3] boxDist;
    float[3] sphereDist;
    
    for(int i=-1; i<2; i++){
        boxDist[i+1] = boxDistance(pLocal + gap * float(i), Box(vec3(0.0), vec3(1.5, 0.5, 1.5), NULL_MATERIAL));
        sphereDist[i+1] = sphereDistance(point - boxPosition + gap * float(i), Sphere(vec3(0.), 0.75, NULL_MATERIAL));
    }
    
    float t = sin(iTime)*0.5+0.5;
    float unionDist = opSmoothUnion(boxDist[0], sphereDist[0], t);
    float subtractionDist1 = opSmoothSubtraction(sphereDist[1], boxDist[1], t);
    float intersectionDist = opSmoothIntersection(boxDist[2], sphereDist[2], t);
    //float subtractionDist2 = opSmoothSubtraction(boxDist, sphereDist, t);
    
    float d = min(unionDist, min(intersectionDist, subtractionDist1));
    

    if(d < minDist.dist){
        minDist.dist = d;
        minDist.material = createSolidMaterial(
            vec3(1.0, 0.0, 0.0), // albedo
            5., // specular power
            0.3 // specular intensity
        );
    }

    return minDist;
}
#endif

#ifdef SCENE_DOMAIN_REPETITION
HitCandidate getDist(vec3 point, Scene scene){
    HitCandidate minDist = NULL_CANDIDATE;
    
    point = point - vec3(0., 2., -5.); // Translating origin
    
    float gap = 6.5;
    vec3 repeatedDomain = point - gap*round(point/gap);

    float sphereDist = sphereDistance(repeatedDomain, Sphere(vec3(0.), 1., NULL_MATERIAL));

    if(sphereDist < minDist.dist){
        minDist.dist = sphereDist;
        minDist.material = SPHERE_MATERIAL;
    }

    return minDist;
}
#endif


#ifdef SCENE_WAVE_DISTORTION
HitCandidate getDist(vec3 point, Scene scene){
    HitCandidate minDist = NULL_CANDIDATE;

    vec3 sphereCenter = vec3(0., 2., -5.);
    float sphereDist = sphereDistance(point - sphereCenter, Sphere(vec3(0.), 2., NULL_MATERIAL));

    vec2 uv = sphereUV(point, sphereCenter);
    float distortion = sin(uv.x * 64.) * cos(uv.y * 64.);
    sphereDist += distortion * (sin(iTime) * 0.5 + 0.5) * 0.1;

    if(sphereDist < minDist.dist){
        minDist.dist = sphereDist;
        minDist.material = SPHERE_MATERIAL;
    }

    return minDist;
}
#endif


#ifdef SCENE_DOMAIN_WARP
HitCandidate getDist(vec3 point, Scene scene){
    HitCandidate minDist = NULL_CANDIDATE;

    vec3 sphereCenter = vec3(0., 2., -5.);
    float sphereDist = sphereDistance(point - sphereCenter, Sphere(vec3(0.), 2., NULL_MATERIAL));

    vec2 uv = sphereUV(point, sphereCenter);
    
    vec2 q = vec2( simplexNoiseFBM( uv + vec2(0.0,0.0), 4. ),
                   simplexNoiseFBM( uv + vec2(2.2,1.3), 4. ) );
    float distortion = simplexNoiseFBM( uv + 4.*q, 3.);
    sphereDist += distortion * (sin(iTime) * 0.5 + 0.5) * 0.3;

    if(sphereDist < minDist.dist){
        minDist.dist = sphereDist;
        minDist.material = SPHERE_MATERIAL;
    }

    return minDist;
}
#endif

#ifdef SCENE_STANFORD_BUNNY
HitCandidate getDist(vec3 point, Scene scene){
    HitCandidate minDist = NULL_CANDIDATE;

    vec3 center = vec3(0., 2., -5.);
    vec3 bunnyP = rotate3D(point - center, vec3(0.,1.,0.), PI/12.);
    vec3 rbunnyP = rotate3D(point - center, vec3(0.,1.,0.), iTime);
    float bunnyDist = stanfordBunnyDist(bunnyP * 0.45);
    float sphereDist = length(point - center) - 1.5;
    
    
    float animationSpeed = 1. / PI;
    float animationTime = iTime * animationSpeed;
    float fractT = fract(animationTime);
    float interpolator = fractT < 0.5 ? smoothstep(0., 1., fractT*4.) : smoothstep(1., 0., fractT*4.-2.);
    
    float outDist = (sphereDist * (1.-interpolator) + bunnyDist * interpolator);

    if(outDist < minDist.dist){
        minDist.dist = outDist;
        minDist.material = SPHERE_MATERIAL;
    }

    return minDist;
}
#endif

#ifdef SCENE_METABALLS
float s(float t){ return sin(iTime*t); }
float c(float t){ return cos(iTime*t); }

HitCandidate getDist(vec3 point, Scene scene) {

    vec3 center = vec3(0., 2., -5.);

    vec3 offsets[6] = vec3[](
        vec3(  1.5*s(1.4),   1.0*c(1.0) - 2.0,  2.1*c(1.4) - 8.0 ),
        vec3( -1.0*s(0.2),   1.4*c(2.1) - 2.0,  1.0*s(3.1) - 8.0),
        vec3(  4.0*c(1.1),   1.3*s(0.7) - 2.0, -1.0*c(1.2) - 8.0),
        vec3( -3.2*s(0.4),  -1.0*c(1.2) - 2.0,  1.0*c(0.2) - 8.0 ),
        vec3(  1.0*s(1.2),  -1.0*c(0.4) - 2.0,  1.2*c(0.9) - 8.0 ),
        vec3(  2.6*s(0.3),   3.0*c(0.1) - 2.0,  1.9*c(0.4) - 8.0 )
    );

    Material materials[6] = Material[](
        createSolidMaterial(vec3(1,0,0),130.,0.7),
        createSolidMaterial(vec3(0,1,0),130.,0.7),
        createSolidMaterial(vec3(0,0,1),130.,0.7),
        createSolidMaterial(vec3(1,1,0),130.,0.7),
        createSolidMaterial(vec3(0,1,1),130.,0.7),
        createSolidMaterial(vec3(1,0,1),130.,0.7)
    );

    float k = 0.9;

    float d = 1e9;
    Material mat = materials[0];

    for (int i = 0; i < 6; i++) {

        float sphereD = length(point - center - offsets[i]) - 1.0;

        float h = clamp(0.5 + 0.5*(sphereD - d)/k, 0.0, 1.0);

        float newDist = mix(sphereD, d, h) - k*h*(1.0 - h);

        mat.albedo = mix(materials[i].albedo, mat.albedo, h);

        d = newDist;
    }

    HitCandidate result;
    result.dist = d;
    result.material = mat;

    return result;
}
#endif

vec3 getLight(Hit hit, Ray ray, in Scene scene)
{
    // Unlit material
    if (hit.material.type == M_UNLIT)
        return hit.material.albedo;
    
    vec3 outputColor = vec3(0.);
    
    for(int i=0; i < NLIGHTS; i++) {
    PointLight light = scene.pointLights[i];
    vec3 ldir = (light.pos - hit.point);
    float r = length(ldir);
    float r2 = r*r;
    ldir = normalize(ldir);

    // cast hard shadow
    float shadowValue = 1.;
    // vec3 shadowRayOrigin = hit.point + hit.normal * SHADOW_BIAS;
    // vec3 shadowRayDirection = ldir;
    // Ray shadowRay = Ray(shadowRayOrigin, shadowRayDirection);
    // Hit shadowHit = marchRay(shadowRay, scene);
    // if(shadowHit.isHit){
    //     if(shadowHit.material.type != M_UNLIT)
    //             shadowValue = 0.4;
    // }
    // shadowValue = min(shadowValue, 8.*shadowHit.dist/, )
    
    vec3 li = light.color * (light.intensity / (4. * PI));
    // lambert
    float lv = clamp(dot(ldir, hit.normal), 0., 1.);
    
    // specular (Phong)
    vec3 R = reflect(ldir, hit.normal);
    vec3 specular = li * pow(max(0.f, dot(R, ray.direction)), hit.material.specularPower);
    
    vec3 albedo = getAlbedo(hit);
    vec3 diffuse = albedo * li * lv;

    outputColor += (diffuse + specular * hit.material.specularIntensity) * shadowValue;
    }

    float dist = length(ray.origin - hit.point);        
    float fogDistance = max(0.0, dist - scene.fog.startDistance);
    float fogAmount = 1.0 - exp(-fogDistance * scene.fog.intensity);
   
    return (outputColor + scene.ambientLight)*(1.-fogAmount) + (scene.fog.color * fogAmount);
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
        #ifdef RENDER_LIGHT_SPHERE
        // render sphere in point light's location
        HitCandidate lightHit = NULL_CANDIDATE;
        for(int i = 0; i < NLIGHTS; i++){
            PointLight light = scene.pointLights[i];
            float lightDist = sphereDistance(marchPos - scene.pointLights[i].pos, LIGHT_SPHERE);
            if(lightDist < lightHit.dist){
                lightHit.dist = lightDist;
                lightHit.material = LIGHT_SPHERE.material;
            }
        }
        if(lightHit.dist < nextStepHit.dist) nextStepHit = lightHit;
        #endif
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
    Hit hit = Hit(
        marchPos,
        getNormal(marchPos,nextStepHit.dist, scene),
        distToCamera,
        nextStepHit.material,
        isHit); 
    return hit;
}

void Camera(in vec2 fragCoord, out vec3 ro, out vec3 rd) 
{
    // ro = load(POSITION).xyz;
    // vec2 m = load(VMOUSE).xy/iResolution.x;
    vec2 m = (fragCoord - iResolution.xy*0.5)/iResolution.x;
    
    float a = 1.0/max(iResolution.x, iResolution.y);
    rd = normalize(vec3((fragCoord - iResolution.xy*0.5)*a, 0.5));

    rd = CameraRotation(m) * rd;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    Scene scene = createScene();

    vec2 uv = (fragCoord - .5*iResolution.xy) / iResolution.y;
    vec3 color = vec3(0.);
  
    // Creating Ray
    vec3 rayOrigin = vec3(0.);
    vec3 rayDirection = vec3(0.);
    Camera(fragCoord, rayOrigin, rayDirection);


    Ray ray = Ray(rayOrigin, rayDirection);
    
    // Marching Ray
    Hit hit = marchRay(ray, scene);

    // Skybox Color
    vec3 skyBoxColor = mix(vec3(0.4, 0.6, 0.8), vec3(0.7, 0.9, 1.), dot(rayDirection, vec3(0., 1., 0.)));
    float sunDot = dot(scene.dirLight.direction * 1.224744871391589, rayDirection);
    skyBoxColor += skyBoxColor * exp(exp(exp(-sunDot-0.2))) * scene.dirLight.color * 0.0000001;
    skyBoxColor *= iBackground;
    
    if (hit.isHit){
        vec3 sceneColor = getLight(hit, ray, scene);
        float dist = length(ray.origin - hit.point);        
        float fogDistance = max(0.0, dist - scene.fog.startDistance);
        float fogAmount = 1.0 - exp(-fogDistance * scene.fog.intensity);
        color += mix(sceneColor, skyBoxColor, fogAmount);
    }
    else color = skyBoxColor;
    
    // Output to screen
    fragColor = vec4(color,1.0);
}
