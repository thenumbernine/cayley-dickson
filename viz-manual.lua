#!/usr/bin/env luajit
local ffi = require 'ffi'
local bit = require 'bit'
local gl = require 'gl'
local template = require 'template'
local vec3f = require 'vec-ffi.vec3f'
local vec3d = require 'vec-ffi.vec3d'
local quatd = require 'vec-ffi.quatd'
local vector = require 'ffi.cpp.vector'
local GLProgram = require 'gl.program'
local GLGeometry = require 'gl.geometry'
local GLSceneObject = require 'gl.sceneobject'
local GLAttribute = require 'gl.attribute'
local GLArrayBuffer = require 'gl.arraybuffer'

local vector_vec3f = vector'vec3f_t'

require 'glapp.view'.useBuiltinMatrixMath = true

local App = require 'imguiapp.withorbit'()
App.viewDist = 3

function App:initGL()
	App.super.initGL(self)
	self.glslVersion = '300 es'

	self.shaderHeader =
'#version '..self.glslVersion..'\n'
..'precision highp float;\n'

	self.program = GLProgram{
		vertexCode = self.shaderHeader..template[[
in vec3 vertex;
out vec3 mvposv;
uniform mat4 mvMat;
uniform mat4 projMat;

const float M_PI = <?=('%.49f'):format(math.pi)?>;

vec4 quatFromAngleAxis(vec4 aa) {
	return vec4(sin(.5 * aa.w) * normalize(aa.xyz), cos(.5 * aa.w));
}

vec3 rotate(vec4 q, vec3 v) {
	return v + 2. * cross(q.xyz, cross(q.xyz, v) + q.w * v); 
}

void main() {
	// TODO inv mat to get eyepos?
	
	vec4 qy = quatFromAngleAxis(vec4(0., 1., 0., M_PI * vertex.x * 2.));
	vec4 qz = quatFromAngleAxis(vec4(0., 0., 1., M_PI * vertex.x));
	
	const float radius = 1.;
	const float width = .5;
	vec3 worldpos = rotate(qy,
		rotate(qz, vec3(0., .5 * width * (2. * vertex.y - 1.), 0.))
		+ vec3(radius, 0., 0.)
	);

	vec4 mvpos = mvMat * vec4(worldpos, 1.);
	mvposv = mvpos.xyz;
	gl_Position = projMat * mvpos;
}
]],
		fragmentCode = self.shaderHeader..[[
const vec4 color = vec4(1., 0., 0., 1.);
in vec3 eyeposv;
in vec3 mvposv;
out vec4 fragColor;
void main() {
	vec3 n = normalize(cross(dFdx(mvposv), dFdy(mvposv)));
	fragColor = abs(n.z) * color;
}
]],
	}:useNone()

	self.vertexCPU = vector_vec3f()

	local n = 360
	-- TODO why does emplace_back()[0] crash?
	self.vertexCPU:resize(2 * (n+1))
	for i=0,n do
		for z=0,1 do
			self.vertexCPU.v[z + 2 * i]:set(i/n, z, 0)
		end
	end

	local vertexCount = #self.vertexCPU
	self.vertexGPU = GLArrayBuffer{
		size = vertexCount * ffi.sizeof'vec3f_t',
		data = self.vertexCPU.v,
	}:unbind()

	self.geometry = GLGeometry{
		mode = gl.GL_TRIANGLE_STRIP,
		vertexes = self.vertexGPU,
		count = vertexCount,
	}

	self.globj = GLSceneObject{
		geometry = self.geometry,
		program = self.program,
		attrs = {
			vertex = self.vertexGPU,
		},
	}

	gl.glEnable(gl.GL_DEPTH_TEST)
end

function App:update()
	gl.glClear(bit.bor(gl.GL_COLOR_BUFFER_BIT, gl.GL_DEPTH_BUFFER_BIT))

	self.globj:draw{
		uniforms = {
			mvMat = self.view.mvMat.ptr,
			projMat = self.view.projMat.ptr,
		},
	}

	App.super.update(self)
end

App():run()
