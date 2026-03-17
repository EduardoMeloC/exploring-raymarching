// Created by genis sole - 2016
// License Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International.

#include "Core.frag"

#iChannel0 "CameraBuffer.frag"
#iKeyboard

#define store(P, V) if (all(equal(ivec2(fragCoord), P))) fragColor = V
#define key(K) (isKeyDown(K) ? 1. : 0.)

const ivec2 MEMORY_BOUNDARY = ivec2(4, 3);

const ivec2 POSITION = ivec2(1, 0);

const ivec2 VMOUSE = ivec2(1, 1);
const ivec2 PMOUSE = ivec2(2, 1);

const ivec2 TARGET = ivec2(0, 2);

const ivec2 RESOLUTION = ivec2(3, 1);

#define KEY_BINDINGS(FORWARD, BACKWARD, RIGHT, LEFT) const int KEY_BIND_FORWARD = FORWARD; const int KEY_BIND_BACKWARD = BACKWARD; const int KEY_BIND_RIGHT = RIGHT; const int KEY_BIND_LEFT = LEFT;

#define ARROWS  KEY_BINDINGS(Key_UpArrow, Key_DownArrow, Key_RightArrow, Key_LeftArrow)
#define WASD  KEY_BINDINGS(Key_W, Key_S, Key_D, Key_A)
#define ESDF  KEY_BINDINGS(Key_E, Key_D, Key_F, Key_S)

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