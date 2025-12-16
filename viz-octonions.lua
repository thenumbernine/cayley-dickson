#!/usr/bin/env rua
require 'vec-ffi'
local gl = require 'gl'
local GLSceneObject = require 'gl.sceneobject'
local GLGeometry = require 'gl.geometry'
local App = require 'imgui.appwithorbit'()
App.title = 'Octonion Multiplication Table'
App.initGL = |:|do
	App.super.initGL(self)

	local GLHSVTex2D = require 'gl.hsvtex2d'
	self.textTex = GLHSVTex2D(256, nil, true)

	self.mobiusObj = GLSceneObject{
		program = {
			version = 'latest',
			precision = 'best',
			vertexCode = [[
in vec2 vertex;
out vec2 texcoord;
uniform mat4 mvProjMat;

vec3 quatRotate(vec4 q, vec3 v){
	return v + 2. * cross(cross(v, q.xyz) - q.w * v, q.xyz);
}

//assumes axis is normalized
vec4 angleAxisToQuat(vec3 axis, float theta) {
	float vlen = length(axis);
	float costh = cos(.5 * theta);
	float sinth = sin(.5 * theta);
	float vscale = sinth / vlen;
	return vec4(axis * vscale, costh);
}

vec3 vecRotate(vec3 v, float x, float y, float z, float theta) {
	return quatRotate(angleAxisToQuat(vec3(x,y,z), theta), v);
}

void main() {
	texcoord = vertex;
	float u = vertex.x;
	float v = vertex.y;
	vec3 r = vec3(0., 0., v - .5);
	r = vecRotate(r, 0., 1., 0., radians(180. * u));
	r += vec3(1., 0., 0.);
	r = vecRotate(r, 0., 0., 1., radians(360. * u));
	gl_Position = mvProjMat * vec4(r, 1.);
}

]],
			fragmentCode = [[
in vec2 texcoord;

//https://www.opengl.org/discussion_boards/showthread.php/164734-Deferred-shading?p=1164077#post1164077

const vec2 bufferSize = vec2(800., 600.);
const vec2 cameraRange = vec2(.1, 100.);

float depthToZPosition(in float depth) {
	return cameraRange.x / (cameraRange.y - depth *
		(cameraRange.y - cameraRange.x)) * cameraRange.y;
}

vec3 fragToScreen(vec3 fragCoord) {
	vec3 screenCoord = vec3(
		((fragCoord.x / bufferSize.x) - .5) * 2.,
		((-fragCoord.y / bufferSize.y) + .5) * 2. / (bufferSize.x / bufferSize.y),
		depthToZPosition(fragCoord.z));
	screenCoord.x *= screenCoord.z;
	screenCoord.y *= -screenCoord.z;
	return screenCoord;
}

#if 0
//  (0,1)
//       +---+---+
//       |\_               <- upper 1: y-1 = (0-1)/(3/2-0)(x-0) <=> y = 1 - 2*x/3
//       |\ \_     
//       | |  \            <- lower line: y-1 = (0-1)/(1/2-0)(x-0) <=> y = 1 - 2*x
//       +-+---+---+
//  (0,0)  ^   ^
//     (1/2,0) |
//           (3/2,0)
#endif

uniform float offset;

uniform sampler2D textTex;

float mod1(float x) { return x - floor(x); }

out vec4 fragColor;
void main() {
	float u = texcoord.x;
	float v = texcoord.y;

	// determine septant here
	
	u *= .5;
	if (gl_FrontFacing) {
		u += .5;
		v = 1. - v;
	}
	u = mod1(u - offset);
	u = u * 7.;

	{
		vec2 tc;
		float len;
		float letter;
		vec2 letterOffset;
		
		letter = floor(mod1((u-.5)/7.)*7.);
		letterOffset = vec2(mod(letter, 4.) * .25, floor(letter / 4.) * .5);
		tc = 5. * vec2(3./2. * mod1(u + .5 / 5. * 2. / 3.), v);
		len = length(tc-.5)/.5;
		if (len <= 1.) {
			if (len <= .95) {
				tc.x = 1. - tc.x;
				fragColor = texture(textTex, tc * vec2(.25, .5) + letterOffset);
			} else { 
				fragColor = vec4(0.);
			}
			return;
		}
		
		letter = floor(mod1((u+3.)/7.)*7.);
		letterOffset = vec2(mod(letter, 4.) * .25, floor(letter / 4.) * .5);
		tc = 5. * vec2(3./2. * mod1(u - .5 + .5 / 5. * 2. / 3.), v - .8);
		len = length(tc-.5)/.5;
		if (len <= 1.) {
			if (len <= .95) {
				tc.x = 1. - tc.x;
				fragColor = texture(textTex, tc * vec2(.25, .5) + letterOffset);
			} else {
				fragColor = vec4(0.);
			}
			return;
		}
	}

	float ix = floor(3./2.*v + u);
	float iy = floor(.5 * v + u);
	float ic = mod1(.5 * (ix + iy));

	if (ic == 0.) {
		fragColor = vec4(1., 0., 0., 1.);
	} else {
		discard;
	}

	//apply diffuse lighting
	vec3 screenCoord = fragToScreen(gl_FragCoord.xyz);
	vec3 s = dFdx(screenCoord);
	vec3 t = dFdy(screenCoord);
	vec3 n = normalize(cross(s, t));
	float l = max(n.z, .3);
	fragColor *= l;
}
]],
			uniforms = {
				offset = 0,
				textTex = 0,
			},
		},
		geometries = table(),
		vertexes = {
			useVec = true,
			dim = 2,
		},
		texs = {self.textTex},
	}

	local xRes = 200
	local yRes = 10
	local vertexGPU = self.mobiusObj.attrs.vertex.buffer
	local vertexCPU = vertexGPU:beginUpdate()
	for j=0,yRes-1 do
		for i=0,xRes-1 do
			vertexCPU:emplace_back():set( i / (xRes-1), j / (yRes-1) )
		end
	end
	vertexGPU:endUpdate()

	for j=0,yRes-2 do
		local indexes = table()
		for i=0,xRes-1 do
			for jofs=0,1 do
				indexes:insert(i + xRes * (j+jofs))
			end
		end
		local GLElementArrayBuffer = require 'gl.elementarraybuffer'
		self.mobiusObj.geometries:insert(GLGeometry{
			mode = gl.GL_TRIANGLE_STRIP,
			-- why doesn't it automatically convert?
			indexes = GLElementArrayBuffer{
				data = indexes,
				-- why doesnt this auto select as well? it's the class .type field default...
				type = gl.GL_UNSIGNED_INT,
			}:unbind(),
			-- why doesn't it automatically use indexes.count ?
			count = #indexes,
		})
	end
end

App.update = |:|do
	gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT)

	self.mobiusObj.uniforms.mvProjMat = self.view.mvProjMat.ptr
	self.mobiusObj:draw()

	App.super.update(self)
end

return App():run()
