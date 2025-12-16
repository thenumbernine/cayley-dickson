#!/usr/bin/env rua
require 'vec-ffi'
local gl = require 'gl'
local GLSceneObject = require 'gl.sceneobject'
local GLGeometry = require 'gl.geometry'
local GLArrayBuffer = require 'gl.arraybuffer'
local App = require 'imgui.appwithorbit'()
App.title = 'Octonion Multiplication Table'
App.initGL = |:|do
	App.super.initGL(self)

	local xRes = 200
	local yRes = 10

	local vertexGPU = GLArrayBuffer{useVec=true, dim=3}:unbind()
	local texcoordGPU = GLArrayBuffer{useVec=true, dim=2}:unbind()
	local normalGPU = GLArrayBuffer{useVec=true, dim=3}:unbind()
	local vertexCPU = vertexGPU:beginUpdate()
	local texcoordCPU = texcoordGPU:beginUpdate()
	local normalCPU = normalGPU:beginUpdate()
	for j=0,yRes-1 do
		local v = j / (yRes-1)
		for i=0,xRes-1 do
			local u = i / (xRes-1)
			local r = vec3f(0, 0, v - .5)
			r = quatf():fromAngleAxis(0,1,0,180*u):rotate(r)
			r += vec3f(1,0,0)
			r = quatf():fromAngleAxis(0,0,1,360*u):rotate(r)
			vertexCPU:emplace_back()[0] = r --:set( i / (xRes-1), j / (yRes-1) )
			texcoordCPU:emplace_back():set( i / (xRes-1), j / (yRes-1) )
		end
	end
	for j=0,yRes-1 do
		for i=0,xRes-1 do
			local iR = math.min(i+1,xRes-1) + xRes * j
			local iL = math.max(i-1,0)      + xRes * j
			local jR = i + xRes * math.min(j+1,yRes-1)
			local jL = i + xRes * math.max(j-1,0)
			local u = vertexCPU.v[iR] - vertexCPU.v[iL]
			local v = vertexCPU.v[jR] - vertexCPU.v[jL]
			normalCPU:emplace_back()[0] = u:cross(v):normalize()
		end
	end
	vertexGPU:endUpdate()
	texcoordGPU:endUpdate()
	normalGPU:endUpdate()

	local geometries = table()
	for j=0,yRes-2 do
		local indexes = table()
		for i=0,xRes-1 do
			for jofs=0,1 do
				indexes:insert(i + xRes * (j+jofs))
			end
		end
		geometries:insert{
			mode = gl.GL_TRIANGLE_STRIP,
			indexes = {
				data = indexes,
			},
		}
	end

	self.mobiusObj = GLSceneObject{
		program = {
			version = 'latest',
			precision = 'best',
			vertexCode = [[
layout(location=0) in vec3 vertex;
layout(location=1) in vec2 texcoord;
layout(location=2) in vec3 normal;
out vec2 texcoordv;
out vec3 normalv;
uniform mat4 mvProjMat;

void main() {
	texcoordv = texcoord;
	normalv = normalize((mvProjMat * vec4(normal, 0.)).xyz);
	gl_Position = mvProjMat * vec4(vertex, 1.);
}

]],
			fragmentCode = [[
in vec2 texcoordv;
in vec3 normalv;

out vec4 fragColor;

uniform sampler2D tex;

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

float mod1(float x) { return x - floor(x); }

void main() {
	float u = texcoordv.x;
	float v = texcoordv.y;

	// determine septant here
	
	u *= .5;
	if (gl_FrontFacing) {
		u += .5;
		v = 1. - v;
	}
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
				fragColor = texture(tex, tc * vec2(.25, .5) + letterOffset);
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
				fragColor = texture(tex, tc * vec2(.25, .5) + letterOffset);
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
	fragColor *= max(abs(normalv.z), .3);
}
]],
			uniforms = {
				tex = 0,
			},
		},
		geometries = geometries,
		vertexes = vertexGPU,
		attrs = {
			texcoord = {
				buffer = texcoordGPU,
			},
			normal = {
				buffer = normalGPU,
			},
		},
		texs = {
			--[[
			require 'gl.hsvtex2d'(256, nil, true):unbind(),
			--]]
			-- [[
			require 'gl.tex2d'{
				filename = 'viz-octonion-labels.png',
				minFilter = gl.GL_NEAREST,
				magFilter = gl.GL_LINEAR,
			}:unbind(),
			--]]
		},
	}

	gl.glEnable(gl.GL_DEPTH_TEST)
	gl.glClearColor(.1, .1, .1, 1)
end

App.update = |:|do
	gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT)

	self.mobiusObj.uniforms.mvProjMat = self.view.mvProjMat.ptr
	self.mobiusObj:draw()

	App.super.update(self)
end

return App():run()
