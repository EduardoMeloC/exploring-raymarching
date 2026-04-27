// Created by genis sole - 2016
// License Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International.

#define store(P, V) if (all(equal(ivec2(fragCoord), P))) fragColor = V
#define load(P) texelFetch(iChannel1, ivec2(P), 0)
#define key(K)  step(0.5, texelFetch(iChannel0, ivec2(K, 0), 0).x)

const ivec2 MEMORY_BOUNDARY = ivec2(4, 3);

const ivec2 POSITION = ivec2(1, 0);

const ivec2 VMOUSE = ivec2(1, 1);
const ivec2 PMOUSE = ivec2(2, 1);

const ivec2 TARGET = ivec2(0, 2);

const ivec2 RESOLUTION = ivec2(3, 1);

// Keyboard constants definition
const int KEY_BSP   = 8;
const int KEY_SP    = 32;
const int KEY_LEFT  = 37;
const int KEY_UP    = 38;
const int KEY_RIGHT = 39;
const int KEY_DOWN  = 40;
const int KEY_A     = 65;
const int KEY_B     = 66;
const int KEY_C     = 67;
const int KEY_D     = 68;
const int KEY_E     = 69;
const int KEY_F     = 70;
const int KEY_G     = 71;
const int KEY_H     = 72;
const int KEY_I     = 73;
const int KEY_J     = 74;
const int KEY_K     = 75;
const int KEY_L     = 76;
const int KEY_M     = 77;
const int KEY_N     = 78;
const int KEY_O     = 79;
const int KEY_P     = 80;
const int KEY_Q     = 81;
const int KEY_R     = 82;
const int KEY_S     = 83;
const int KEY_T     = 84;
const int KEY_U     = 85;
const int KEY_V     = 86;
const int KEY_W     = 87;
const int KEY_X     = 88;
const int KEY_Y     = 89;
const int KEY_Z     = 90;
const int KEY_COMMA = 188;
const int KEY_PER   = 190;

#define KEY_BINDINGS(FORWARD, BACKWARD, RIGHT, LEFT) const int KEY_BIND_FORWARD = FORWARD; const int KEY_BIND_BACKWARD = BACKWARD; const int KEY_BIND_RIGHT = RIGHT; const int KEY_BIND_LEFT = LEFT;

#define ARROWS  KEY_BINDINGS(KEY_UP, KEY_DOWN, KEY_RIGHT, KEY_LEFT)
#define WASD  KEY_BINDINGS(KEY_W, KEY_S, KEY_D, KEY_A)
#define ESDF  KEY_BINDINGS(KEY_E, KEY_D, KEY_F, KEY_S)

#define INPUT_METHOD  WASD
vec2 KeyboardInput() {
    INPUT_METHOD
    
	vec2 i = vec2(key(KEY_BIND_RIGHT)   - key(KEY_BIND_LEFT), 
                  key(KEY_BIND_FORWARD) - key(KEY_BIND_BACKWARD));
    
    float n = abs(abs(i.x) - abs(i.y));
    return i * (n + (1.0 - n)*inversesqrt(2.0));
}

vec3 CameraDirInput(vec2 vm) {
    vec2 m = vm/iResolution.x;
    
    return CameraRotation(m) * vec3(KeyboardInput(), 0.0).xzy;
}


void Collision(vec3 prev, inout vec3 p) {
    if (p.y < 1.0) p = vec3(prev.xz, min(1.0, prev.y)).xzy;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{   
    if (any(greaterThan(ivec2(fragCoord), MEMORY_BOUNDARY))) return;
    
    fragColor = load(fragCoord);
    
    vec2 resolution = load(RESOLUTION).xy;
    store(RESOLUTION, vec4(iResolution.xy, 0.0, 0.0));
    
    if (iTime == 0.0 || iFrame == 0 || any(notEqual(iResolution.xy, resolution))) {
        store(POSITION, vec4(0.0, 2.0, 0.0, 0.0));
        store(TARGET, vec4(0.0, 2.0, 0.0, 0.0));
        store(VMOUSE, vec4(0.0));
        store(PMOUSE, vec4(0.0));
        
        return;
    }

    vec3 target      = load(TARGET).xyz;   
    vec3 position    = load(POSITION).xyz;
    vec2 pm          = load(PMOUSE).xy;
    vec3 vm          = load(VMOUSE).xyz;
    
    vec3 ptarget = target;
    target += CameraDirInput(vm.xy) * iTimeDelta * 5.0;
    
    Collision(ptarget, target);
    
    position += (target - position) * iTimeDelta * 5.0;
    
    store(TARGET, vec4(target, 0.0));
    store(POSITION, vec4(position, 0.0));
    
	if (iMouse.z > 0.0) {
    	store(VMOUSE, vec4(pm + (abs(iMouse.zw) - iMouse.xy), 1.0, 0.0));
	}
    else if (vm.z != 0.0) {
    	store(PMOUSE, vec4(vm.xy, 0.0, 0.0));
    }

}