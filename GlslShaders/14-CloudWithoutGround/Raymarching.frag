#include "Core.frag"

#iChannel0 "CameraBuffer.frag"
#iChannel1 "file://noise2.png"

const ivec2 POSITION = ivec2(1, 0);
const ivec2 VMOUSE = ivec2(1, 1);

#define NLIGHTS 1
// #define RENDER_LIGHT_SPHERE
#define ENABLE_DIRECTIONAL_LIGHT

#define SPHERE_MATERIAL createSolidMaterial(vec3(1.0, 0.0, 0.0), 130., 0.7)
#define BOX_MATERIAL createSolidMaterial(vec3(1.0, 0.0, 0.0), 10., 0.3)

struct Scene{
    Ground ground;
    DirectionalLight dirLight;
    PointLight[NLIGHTS] pointLights;
    vec3 ambientLight;
    Fog fog;
};

Scene createScene(){
    Material groundMaterial = createCheckerboardMaterial(
        vec3(0.94, 0.91, 0.86) * 0.7, // albedo1
        vec3(0.58, 0.66, 0.57) * 0.7, // albedo2
        1., // specular power
        0. // specular intensity
    );

    Ground ground = Ground(
        0.,
        groundMaterial
    );

    DirectionalLight dirLight = DirectionalLight(
        // normalize(vec3(cos(iTime), -1., -sin(iTime))),
        normalize(vec3(-2., -4., -3.)),
        vec3(0.788235294117647, 0.8862745098039215, 1.0),
        10.
    );
    
    PointLight[NLIGHTS] pointLights; 

    vec3 pointLightPos = vec3(0., 2., -5.);
    float radiusDistance = 5.;
    pointLightPos.x += cos(iTime) * radiusDistance;
    pointLightPos.z += sin(iTime) * radiusDistance;
    // pointLights[0] = PointLight(
    //     pointLightPos,
    //     vec3(0.988235294117647, 0., 0.9),
    //     100.
    // );

    vec3 ambientLight = dirLight.color * 0.05;

    Fog fog = Fog(
        10., // dist
        0.03, // intensity
        vec3(0.) // color
    );
    
    Scene scene = Scene(ground, dirLight, pointLights, ambientLight, fog);
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


vec4 getLight(Hit hit, Ray ray, in Scene scene)
{
    // Unlit material
    if (hit.material.type == M_UNLIT)
        return vec4(hit.material.albedo, hit.material.transparency);
        
    if (hit.material.type == M_CLOUD)
        return vec4(hit.material.albedo, hit.material.transparency);
    
    vec3 outputColor = vec3(0.);
    
    #ifdef ENABLE_DIRECTIONAL_LIGHT
        DirectionalLight light = scene.dirLight;
        vec3 ldir = -normalize(light.direction);
        vec3 li = light.color * (light.intensity / (4. * PI));
        // lambert
        float lv = clamp(dot(ldir, hit.normal), 0., 1.);
        
        // specular (Phong)
        vec3 R = reflect(ldir, hit.normal);
        vec3 specular = li * pow(max(0.f, dot(R, ray.direction)), hit.material.specularPower);
        
        vec3 albedo = getAlbedo(hit);
        vec3 diffuse = albedo * li * lv;

        outputColor += (diffuse + specular * hit.material.specularIntensity); 
    #endif
    
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

        vec3 li = light.color * (light.intensity / (4. * PI * r2));
        // lambert
        float lv = clamp(dot(ldir, hit.normal), 0., 1.);

        // specular (Phong)
        vec3 R = reflect(ldir, hit.normal);
        vec3 specular = li * pow(max(0.f, dot(R, ray.direction)), hit.material.specularPower);

        vec3 albedo = getAlbedo(hit);
        vec3 diffuse = albedo * li * lv;

        outputColor += (diffuse + specular * hit.material.specularIntensity) * shadowValue;
    }

    return vec4(outputColor + scene.ambientLight, hit.material.transparency);
}

HitCandidate getDist(vec3 point, Scene scene){
    HitCandidate minDist = NULL_CANDIDATE;

    vec3 cloudBoundCenter = vec3(0., 2., -5.);
    float cloudBoundRadius = 2.8;
    
    float cloudBoundDist = length(point - cloudBoundCenter) - cloudBoundRadius;
    
    minDist.material = createCloudMaterial();
    minDist.dist = cloudBoundDist;

    // float groundDist = point.y - scene.ground.height;
    // if(groundDist < minDist.dist){
    //     minDist.dist = groundDist;
    //     minDist.material = scene.ground.material;
    // }

    // if(groundDist < FIXED_STEP_SIZE && minDist.material.type == M_CLOUD){
    //     minDist.dist = groundDist;
    //     minDist.material = scene.ground.material;
    // }
    
    return minDist;
}

float hash(vec3 p) {
    p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float getDensity(vec3 point, Scene scene){
    // float noise = 0.;
    // float noise = hash(point * 8.);
    float noise = noise(point*16.);
    // float noise = noise(point);
    // float noise = noise(point) + noise(point*2.)*0.5;
    // float noise = noise(point) + noise(point*2.)*0.5 + noise(point*4.)*0.25;
    // float noise = noise(point) + noise(point*2.)*0.5 + noise(point*4.)*0.25 + noise(point*8.)*0.125;
    // float noise = noise(point) + noise(point*2.)*0.5 + noise(point*4.)*0.25 + noise(point*8.)*0.125 + noise(point*16.)*0.0625;
    // float noise = fbm(point);

    vec3 cloudCenter = vec3(0., 2., -5.);
    float cloudRadius = 2.0;
    float cloudDist = length(point - cloudCenter) - cloudRadius;

    return -cloudDist + noise * 0.5;
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

vec4 marchRay(Ray ray, Scene scene){
    float distToCamera = 0.;
    bool isHit = false;
    vec3 marchPos = ray.origin;
    HitCandidate nextStepHit = NULL_CANDIDATE;
    vec4 accumulatedColor = vec4(0.0);
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
            if(lightHit.dist < nextStepHit.dist){
                nextStepHit = lightHit;
            }
            
        #endif
        distToCamera += nextStepHit.dist;

        // hit a surface -> return immediately
        if(nextStepHit.dist < SURFACE_DISTANCE && nextStepHit.material.type != M_CLOUD){
            isHit = true;
            Hit hit = Hit(
                marchPos,
                getNormal(marchPos, nextStepHit.dist, scene),
                distToCamera,
                nextStepHit.material,
                isHit
            );
            vec4 hitColor = getLight(hit, ray, scene);

            vec3 skyBoxColor = mix(vec3(0.4, 0.6, 0.8), vec3(0.7, 0.9, 1.), dot(ray.direction, vec3(0., 1., 0.)));
            float sunDot = dot(scene.dirLight.direction * 1.224744871391589, ray.direction);
            skyBoxColor += skyBoxColor * exp(exp(exp(-sunDot-0.2))) * scene.dirLight.color * 0.0000001;
            float dist = length(ray.origin - hit.point);
            float fogDistance = max(0.0, dist - scene.fog.startDistance);
            float fogAmount = 1.-exp(-fogDistance * scene.fog.intensity);
            vec4 fogLayer = vec4(skyBoxColor, fogAmount);
            hitColor = fogLayer * (fogAmount) + hitColor * (1.0 - fogAmount);

            accumulatedColor += hitColor * (1.0-accumulatedColor.a);
        }

        // if it's a cloud volume -> break and switch to volumetric march
        if(nextStepHit.dist < SURFACE_DISTANCE && nextStepHit.material.type == M_CLOUD){
            // ----------- VOLUMETRIC CLOUD MARCHING -----------

            // Entry point is current marchPos
            for(int stp=0; stp<FIXED_MAX_MARCHING_STEPS; stp++){
                distToCamera += FIXED_STEP_SIZE;
                marchPos = ray.origin + (distToCamera * ray.direction);
                
                // check if we left the cloud bounding volume
                HitCandidate nextStepHit = getDist(marchPos, scene); 
                if (nextStepHit.dist > 0. && nextStepHit.material.type != M_CLOUD) {
                    // outside the cloud SDF, stop volumetric march
                    break;
                }

                float density = getDensity(marchPos, scene);

                if(density > 0.0){
                    vec3 skyBoxColor = mix(vec3(0.4, 0.6, 0.8), vec3(0.7, 0.9, 1.), dot(ray.direction, vec3(0., 1., 0.)));
                    // Directional derivative
                    // For fast diffuse lighting
                    float diffuse = 0.0;
                    vec3 accumulatedDiffuseColor = vec3(0.);
                    #ifdef ENABLE_DIRECTIONAL_LIGHT
                    DirectionalLight light = scene.dirLight;
                    vec3 ldir = -normalize(light.direction);
                    vec3 li = light.color * (light.intensity / (4. * PI));
                    diffuse = clamp((getDensity(marchPos, scene) - getDensity(marchPos + 0.3 * ldir, scene)) / 0.3, 0.0, 1.0 );
                    accumulatedDiffuseColor += mix(vec3(0.), li, diffuse);
                    #endif
                    for(int i=0; i < NLIGHTS; i++) {
                        PointLight light = scene.pointLights[i];
                        vec3 ldir = (light.pos - marchPos);
                        float r = length(ldir);
                        float r2 = r*r;
                        ldir = normalize(ldir);

                        float shadowValue = 1.;
                        vec3 li = light.color * (light.intensity / (4. * PI * r2));
                        // lambert
                        diffuse = clamp((getDensity(marchPos, scene) - getDensity(marchPos + 0.3 * ldir, scene)) / 0.3, 0.0, 1.0 );
                        // accumulatedDiffuseColor += mix(vec3(0.), li, diffuse);
                        accumulatedDiffuseColor = vec3(getDensity(marchPos, scene));
                    }
                    accumulatedDiffuseColor.rgb += skyBoxColor * 0.85;

                    vec4 color = vec4(accumulatedDiffuseColor,density);
                    color.rgb *= color.a;
                    accumulatedColor += color * (1.0-accumulatedColor.a);
                    
                    // early exit if opaque
                    if(accumulatedColor.a >= 1.) break;
                }
            }

        }

        // exceeded max range -> nothing hit
        if(distToCamera > MAX_MARCHING_DISTANCE || accumulatedColor.a >= 1.){
            isHit = false;
            break;
        }
    }
    return accumulatedColor;
}

void Camera(in vec2 fragCoord, out vec3 ro, out vec3 rd) 
{
    ro = load(POSITION).xyz;
    vec2 m = load(VMOUSE).xy/iResolution.x;
    
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
    vec4 sceneColor = marchRay(ray, scene);

    // Skybox Color
    vec3 skyBoxColor = mix(vec3(0.4, 0.6, 0.8), vec3(0.7, 0.9, 1.), dot(rayDirection, vec3(0., 1., 0.)));
    float sunDot = dot(scene.dirLight.direction * 1.224744871391589, rayDirection);
    skyBoxColor += skyBoxColor * exp(exp(exp(-sunDot-0.2))) * scene.dirLight.color * 0.0000001;

    color = sceneColor.rgb + (1.0 - sceneColor.a) * skyBoxColor;
    
    // Output to screen
    fragColor = vec4(color,1.0);
}
