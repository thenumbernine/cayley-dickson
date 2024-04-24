#!/usr/bin/env luajit
local ffi = require 'ffi'
local bit = require 'bit'
local gl = require 'gl'
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
		vertexCode = self.shaderHeader..[[
in vec3 vertex;
out vec3 eyeposv;
out vec3 normalv;
uniform mat4 mvMat;
uniform mat4 projMat;
void main() {
	// TODO inv mat to get eyepos?
	vec4 mvpos = mvMat * vec4(vertex, 1.);
	normalv = cross(dFdx(mvpos), dFdy(mvpos));
	eyeposv = normalize((mvMat * vec4(0., 0., 1., 1.)).xyz);
	gl_Position = projMat * mvpos;
}
]],
		fragmentCode = self.shaderHeader..[[
const vec4 color = vec4(1., 0., 0., 1.);
in vec3 eyeposv;
in vec3 normalv;
out vec4 fragColor;
void main() {
	fragColor = abs(normalv.z) * color;
}
]],
	}:useNone()

	self.vertexCPU = vector_vec3f()

	local radius = 1
	local width = .5
	local n = 360
	-- TODO why does emplace_back()[0] crash?
	self.vertexCPU:resize(2 * (n+1))
	for i=0,n do
		for z=0,1 do
			local s = i/n
			local qy = quatd():fromAngleAxis(0,1,0, s*360)
			local qz = quatd():fromAngleAxis(0,0,1, s*180)
--print('size', self.vertexCPU:size())
			self.vertexCPU.v[z + 2 * i]:set(
				qy:rotate(
					qz:rotate(vec3d(0, .5*width*(2*z-1), 0))
					+ vec3d(radius, 0, 0)
				):unpack()
			)
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
