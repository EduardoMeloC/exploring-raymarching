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

float x1;
float y1;
float z1;

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

float fractalDistance(vec3 point, int it, float scale){
	float sc=50.;
    vec3 a1 = sc*vec3(1,1,1);
	vec3 a2 = sc*vec3(-1,-1,1);
	vec3 a3 = sc*vec3(1,-1,-1);
	vec3 a4 = sc*vec3(-1,1,-1);
    vec3 z = point;
	vec3 c;
	int n = 0;
	float dist, d;
	while (n < it) {
	    c = a1; dist = length(z-a1);
	    d = length(z-a2); if (d < dist) { c = a2; dist=d; }
		d = length(z-a3); if (d < dist) { c = a3; dist=d; }
		d = length(z-a4); if (d < dist) { c = a4; dist=d; }
		z = scale*z-c*(scale-1.0);
		n++;
	}
    //return length(point-c)-0.1;
	return length(z) * pow(scale, float(-n))-0.02;
}

float fractalFoldingDistance(vec3 point, int it, float scale)
{
    vec3 z = point;
    float r;
    int n = 0;
    vec3 c;
    while (n < it) {
        if(z.x + z.y < 0.){ z.xy = vec2(-z.y,-z.x);} // fold 1
        if(z.x + z.z < 0.){ z.xz = vec2(-z.z,-z.x);} // fold 2
        if(z.y + z.z < 0.){ z.zy = vec2(-z.y,-z.z);} // fold 3	
        z = scale*z - c*(scale-1.0);
        n++;
    }
    return length(z)  * pow(scale, float(-n))-0.015;
}

//scale=2
//bailout=1000
float sierpinski3(vec3 p,float sc){
    float scale = 2.;
    float bailout=1000.;
    vec3 z = p;
    float r=z.x*z.x+z.y*z.y+z.z*z.z;
    int i = 0;
    while(i<10 && r<bailout){
        //Folding... These are some of the symmetry planes of the tetrahedron
        if(z.x + z.y < 0.){ z.xy = vec2(-z.y,-z.x);} // fold 1
        if(z.x + z.z < 0.){ z.xz = vec2(-z.z,-z.x);} // fold 2
        if(z.y + z.z < 0.){ z.zy = vec2(-z.y,-z.z);} // fold 3	

        //Stretche about the point [1,1,1]*(scale-1)/scale; The "(scale-1)/scale" is here in order to keep the size of the fractal constant wrt scale
        z = scale*z - (scale-1.0);//equivalent to: x=scale*(x-cx); where cx=(scale-1)/scale;
        
        r=z.x*z.x+z.y*z.y+z.z*z.z;
        
        i++;
    }
    return (sqrt(r)-2.)*pow(scale,float(-i))-0.015;//the estimated distance
}

float sierpinski3_2(vec3 p,float sc){
    vec3 C = vec3(1.,1.,1.);
    float scale = 2.;
    float bailout=100000000.;
    vec3 z = p;
    float r=z.x*z.x+z.y*z.y+z.z*z.z;
    int i = 0;
    while(i<1000 && r<bailout){

        //z = rotate_x(2.*PI/10.) * z;
        z = rotate_x(PI*iTime*0.1/10.) * z;
        //z = rotate_y(3.*PI/3.) * z;
        //z = rotate_z(1.*PI/10.) * z;
        
        //z = rotate_x(1.57) * z;

        //Folding... These are some of the symmetry planes of the tetrahedron
        //if((z.x + z.y) < 0.){ z.xy = vec2(-z.y,-z.x);} // fold 1
        //if((z.x + z.z) < 0.){ z.xz = vec2(-z.z,-z.x);} // fold 2
        //if((z.y + z.z) < 0.){ z.zy = vec2(-z.y,-z.z);} // fold 3	

        z.x=abs(z.x);z.y=abs(z.y);z.z=abs(z.z);
        if(z.x-z.y<0.){x1=z.y;z.y=z.x;z.x=x1;}
        if(z.x-z.z<0.){x1=z.z;z.z=z.x;z.x=x1;}
        if(z.y-z.z<0.){y1=z.z;z.z=z.y;z.y=y1;}

        //z = rotate_x((iTime)*0.5) * z;
        //z = rotate_x(1.57/2.) * z;

        //Stretche about the point [1,1,1]*(scale-1)/scale; The "(scale-1)/scale" is here in order to keep the size of the fractal constant wrt scale
        //equivalent to: x=scale*(x-cx); where cx=(scale-1)/scale;
        
        z = scale*z - sc*C*(scale-1.0);

        //if(z.z>0.5*C.z*(scale-1.)) z.z=z.z-C.z*(scale-1.);
        r=z.x*z.x+z.y*z.y+z.z*z.z;
        
        i++;
    }
    return (sqrt(r)-2.)*pow(scale,float(-i))-0.015;//the estimated distance
}

vec2 map( in vec3 p )
{
    
    vec4  kC = vec4(-2,6,15,-6)/22.0;
    //ifdef TRAPS
    //float kBSRad = 2.0;
    
    vec4 z = vec4( p, 0.0 );
    float dz2 = 1.0;
	float m2  = 0.0;
    float n   = 0.0;
    //ifdef TRAPS
    float o   = 1e10;
     
    for( int i=0; i<kNumIte; i++ ) 
	{
        // z' = 3z² -> |z'|² = 9|z²|²
		dz2 *= 9.0*qLength2(qSquare(z));
        
        // z = z³ + c		
		z = qCube( z ) + kC;
        
        // stop under divergence		
        m2 = qLength2(z);		

        // orbit trapping : https://iquilezles.org/articles/orbittraps3d
        //ifdef TRAPS
        o = min( o, length(z.xz-vec2(0.45,0.55))-0.1 );
        
        // exit condition
        if( m2>256.0 ) break;				 
		n += 1.0;
	}
   
	// sdf(z) = log|z|·|z|/|dz| : https://iquilezles.org/articles/distancefractals
	float d = 0.25*log(m2)*sqrt(m2/dz2);
    
    //ifdef TRAPS
    d = min(o,d);
    //ifdef CUT
    //d = max(d, p.y);
    
	return vec2(d,n);        
}

HitCandidate getDist(vec3 point, Scene scene){
    HitCandidate minDist = NULL_CANDIDATE;

    //vec3 cloudBoundCenter = vec3(0., 2., -5.);
    //float cloudBoundRadius = 2.8;
    
    //float cloudBoundDist = length(point - cloudBoundCenter) - cloudBoundRadius;
    
    //minDist.material = createCloudMaterial();
    //minDist.dist = cloudBoundDist;
    
    vec3 fracPos = vec3(0., 2., -40.);

    minDist.dist = fractalDistance((point-fracPos), 20, 2.);
    //minDist.dist = sierpinski3_2((point-fracPos),20.);
    //minDist.dist = map(point-fracPos).x;

    

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
/*
vec3 calcNormal( in vec3 pos )
{
    float kPrecis = 0.00025;
    vec2 e = vec2(1.0,-1.0)*0.5773*kPrecis;
    return -normalize( e.xyy*map( pos + e.xyy ).x + 
					  e.yyx*map( pos + e.yyx ).x + 
					  e.yxy*map( pos + e.yxy ).x + 
					  e.xxx*map( pos + e.xxx ).x );
}
*/
vec3 calcNormal( in vec3 p )
{
    vec4  kC = vec4(-2,6,15,-6)/22.0;
    //ifdef TRAPS
        
    vec4 z = vec4(p,0.0);

    // identity derivative
    mat4x4 J = mat4x4(1,0,0,0,  
                      0,1,0,0,  
                      0,0,1,0,  
                      0,0,0,1 );

  	for(int i=0; i<kNumIte; i++)
    {
        // f(q) = q³ + c = 
        //   x =  x²x - 3y²x - 3z²x - 3w²x + c.x
        //   y = 3x²y -  y²y -  z²y -  w²y + c.y
        //   z = 3x²z -  y²z -  z²z -  w²z + c.z
        //   w = 3x²w -  y²w -  z²w -  w²w + c.w
		//
        // Jacobian, J(f(q)) =
        //   3(x²-y²-z²-w²)  6xy            6xz            6xw
        //    -6xy           3x²-3y²-z²-w² -2yz           -2yw
        //    -6xz          -2yz            3x2-y²-3z²-w² -2zw
        //    -6xw          -2yw           -2zw            3x²-y²-z²-3w²
        
        float k1 = 6.0*z.x*z.y, k2 = 6.0*z.x*z.z;
        float k3 = 6.0*z.x*z.w, k4 = 2.0*z.y*z.z;
        float k5 = 2.0*z.y*z.w, k6 = 2.0*z.z*z.w;
        float sx = z.x*z.x, sy = z.y*z.y;
        float sz = z.z*z.z, sw = z.w*z.w;
        float mx = 3.0*sx-3.0*sy-3.0*sz-3.0*sw;
        float my = 3.0*sx-3.0*sy-    sz-    sw;
        float mz = 3.0*sx-    sy-3.0*sz-    sw;
        float mw = 3.0*sx-    sy-    sz-3.0*sw;
        
        // chain rule of jacobians
        J = J*mat4x4( mx, -k1, -k2, -k3,
                      k1,  my, -k4, -k5,
                      k2, -k4,  mz, -k6,
                      k3, -k5, -k6,  mw );
        // q = q³ + c
        z = qCube(z) + kC; 
        
        // exit condition
        if(dot(z,z)>256.0) break;
    }

    return (p.y>0.0 ) ? vec3(0.0,1.0,0.0) : normalize( (J*z).xyz );
}

vec3 getNormal(vec3 point,float d, Scene scene){
    vec2 e = vec2(.0001, 0);
    HitCandidate n1 = getDist(point - e.xyy, scene);
    HitCandidate n2 = getDist(point - e.yxy, scene);
    HitCandidate n3 = getDist(point - e.yyx, scene);
    
    vec3 stretchedNormal = d-vec3(
        n1.dist,
        n2.dist,
        n3.dist
    );
    return normalize(stretchedNormal);
    //return calcNormal(point);
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
            vec3 newColor = abs(getNormal(marchPos, nextStepHit.dist, scene)); //vec3(0.4,0.9,0.4)
            //newColor = vec3(newColor.x+1., newColor.y, 1.);
            newColor = rotate_x(7.*PI/4.)*newColor;
            newColor = rotate_z(7.*PI/4.)*newColor;
            newColor = rotate_y(3.*PI/4.)*newColor;

            Hit hit = Hit(
                marchPos,
                getNormal(marchPos, nextStepHit.dist, scene),
                distToCamera,
                createSolidMaterial(newColor, 0., 0.),
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
