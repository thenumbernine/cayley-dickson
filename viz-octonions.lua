#!/usr/bin/env rua
require 'vec-ffi'
local Image = require 'image'
local gl = require 'gl'
local GLSceneObject = require 'gl.sceneobject'
local GLGeometry = require 'gl.geometry'
local GLArrayBuffer = require 'gl.arraybuffer'
local GLTex2D = require 'gl.tex2d'

local App = require 'imgui.appwithorbit'()
App.title = 'Octonion Multiplication Table'
App.viewDist = 2

local createIndexMapTex = |indexes|
	GLTex2D{
		image = Image(8, 1, 1, 'float', indexes),
		internalFormat = gl.GL_R32F,
		minFilter = gl.GL_NEAREST,
		magFilter = gl.GL_NEAREST,
		wrap = {
			s = gl.GL_REPEAT,
			t = gl.GL_REPEAT,
		},
	}:unbind()

App.createMobius = |:,indexes| do
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

	local mobiusObj = GLSceneObject{
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
uniform sampler2D indexMapTex;

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

float mapLetter(float u) {
	return texture(indexMapTex, vec2(mod1(u / 7.) * 7. / 8., .5)).r;
}

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
		
		letter = mapLetter(u - .5);

		tc = 5. * vec2(3. / 2. * mod1(u + .5 / 5. * 2. / 3.), v);
		len = length(tc - .5) / .5;
		if (len <= 1.) {
			if (len <= .95) {
				tc.x = 1. - tc.x;
				fragColor = texture(tex, vec2((tc.x + letter) / 8., tc.y));
			} else { 
				fragColor = vec4(0.);
			}
			return;
		}
		
		letter = mapLetter(u + 3.);
		tc = 5. * vec2(3. / 2. * mod1(u - .5 + .5 / 5. * 2. / 3.), v - .8);
		len = length(tc - .5) / .5;
		if (len <= 1.) {
			if (len <= .95) {
				tc.x = 1. - tc.x;
				fragColor = texture(tex, vec2((tc.x + letter) / 8., tc.y));
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
				indexMapTex = 1,
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
			self.textTex,
			-- index-remapping
			createIndexMapTex(indexes),
		},
	}

	return mobiusObj
end


App.initGL = |:|do
	App.super.initGL(self)

	-- generated ... from font.png (TODO generate font.png from a system font)
	local fontImg = Image'font.png'
	local textImg = Image(64 * 8, 64, fontImg.channels, 'uint8_t'):clear()
	-- TODO additive-paste / alpha-paste
	for i=0,7 do
		textImg:pasteInto{x=64*i - 8, y=8, image=fontImg:copy{x=80, y=64, width=16, height=16}:resize(48, 48)} -- "e"
		textImg:pasteInto{x=64*i + 24, y=24, image=fontImg:copy{x=16*i, y=16, width=16, height=16}:resize(32, 32)} -- `i`
	end	
	self.textTex = GLTex2D{
		image = textImg,
		minFilter = gl.GL_NEAREST,
		magFilter = gl.GL_LINEAR,
		wrap = {
			s = gl.GL_REPEAT,
			t = gl.GL_REPEAT,
		},
	}:unbind()

	-- one possible mobius representation of quaternions-within-octonions
	self.mobiusObj = self:createMobius{1,5,7,4,2,3,6,0}

--[[ we need 16 indexes for this, currenly only 8 ...
	local sed = table{1, 2, 5, 8, 3, 7, 13, 11, 4, 10, 6, 15, 14, 12, 9}
	local octInSedOffsets = table{0, 1, 2, 4, 5, 8, 10} -- technicaly teh last two are reversed ... should I do that here?
	local octTexs = range(0,14):mapi(|i|
		octInSedOffsets:mapi(|j| sed[(i + j) % #sed + 1])
	):mapi(|indexes| createIndexMapTex(indexes))
--]]

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
