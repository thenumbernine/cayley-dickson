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
uniform mat4 mvMat;
uniform mat4 projMat;
void main() {
	// TODO inv mat to get eyepos?
	vec4 worldpos = mvMat * vec4(vertex, 1.);
	eyeposv = normalize((mvMat * vec4(0., 0., 1., 1.)).xyz);
	gl_Position = projMat * worldpos;
}
]],
		fragmentCode = self.shaderHeader..[[
const vec4 color = vec4(1., 0., 0., 1.);
in vec3 eyeposv;
out vec4 fragColor;
void main() {
	fragColor = abs(eyeposv.z) * color;
}
]],
	}:useNone()

	self.vertexCpu = vector_vec3f()

	local radius = 1
	local width = .5
	local n = 360
	-- TODO why does emplace_back()[0] crash?
	self.vertexCpu:resize(2 * (n+1))
	for i=0,n do
		for z=0,1 do
			local s = i/n
			local qy = quatd():fromAngleAxis(0,1,0, s*360)
			local qz = quatd():fromAngleAxis(0,0,1, s*180)
--print('size', self.vertexCpu:size())
			self.vertexCpu.v[z + 2 * i]:set(
				qy:rotate(
					qz:rotate(vec3d(0, .5*width*(2*z-1), 0))
					+ vec3d(radius, 0, 0)
				):unpack()
			)
		end
	end

	local vertexCount = #self.vertexCpu
	self.vertexGpu = GLArrayBuffer{
		size = vertexCount * ffi.sizeof'vec3f_t',
		data = self.vertexCpu.v,
	}:unbind()

	self.geometry = GLGeometry{
		mode = gl.GL_TRIANGLE_STRIP,
		vertexes = self.vertexGpu,
		count = vertexCount,
	}

	self.globj = GLSceneObject{
		geometry = self.geometry,
		program = self.program,
		attrs = {
			vertex = self.vertexGpu,
		},
	}
end

function App:update()
	gl.glClear(bit.bor(gl.GL_COLOR_BUFFER_BIT, gl.GL_DEPTH_BUFFER_BIT))

	-- [[ not working
	self.globj:draw{
		uniforms = {
			mvMat = self.view.mvMat.ptr,
			projMat = self.view.projMat.ptr,
		},
	}
	--]]
	--[[ not working
	self.globj.geometry:draw()
	--]]
	--[[ not working
	self.vertexGpu:bind()
	gl.glDrawArrays(gl.GL_TRIANGLE_STRIP, 0, 722)
	self.vertexGpu:unbind()
	--]]
	--[[ working, but view is messed up since setting useBuiltinMatrixMath 
	gl.glBegin(gl.GL_TRIANGLE_STRIP)
	for _,v in ipairs(self.vertexCpu) do
		gl.glVertex3f(v:unpack())
	end
	gl.glEnd()
	--]]
	--[[ WORKING
	self.globj.program:use()
	--[=[ working
	gl.glUniformMatrix4fv(self.program.uniforms.mvMat.loc, 1, gl.GL_FALSE, self.view.mvMat.ptr)
	gl.glUniformMatrix4fv(self.program.uniforms.projMat.loc, 1, gl.GL_FALSE, self.view.projMat.ptr)
	--]=]
	-- [=[ working
	self.globj.program:setUniforms{
		mvMat = self.view.mvMat.ptr,
		projMat = self.view.projMat.ptr,
	}
	--]=]
	
	--[=[ cpu per-vertex working
	gl.glBegin(gl.GL_TRIANGLE_STRIP)
	for _,v in ipairs(self.vertexCpu) do
		gl.glVertex3f(v:unpack())
	end
	gl.glEnd()
	--]=]
	--[=[ cpu vertex attrib array working
	gl.glEnableVertexAttribArray(self.program.attrs.vertex.loc)
	gl.glVertexAttribPointer(self.program.attrs.vertex.loc, 3, gl.GL_FLOAT, false, 0, self.vertexCpu.v)
	gl.glDrawArrays(gl.GL_TRIANGLE_STRIP, 0, 722)
	gl.glDisableVertexAttribArray(self.program.attrs.vertex.loc)
	--]=]
	--[=[ gpu buffer - working
	self.vertexGpu:bind()
	gl.glEnableVertexAttribArray(self.program.attrs.vertex.loc)
	gl.glVertexAttribPointer(self.program.attrs.vertex.loc, 3, gl.GL_FLOAT, false, 0, nil)
	gl.glDrawArrays(gl.GL_TRIANGLE_STRIP, 0, 722)
	gl.glDisableVertexAttribArray(self.program.attrs.vertex.loc)
	self.vertexGpu:unbind()
	--]=]
	--[=[ gpu vao - working
	self.globj:enableAndSetAttrs()
	gl.glDrawArrays(gl.GL_TRIANGLE_STRIP, 0, 722)
	self.globj:disableAttrs()
	--]=]
	-- [=[ geometry - working
	self.globj:enableAndSetAttrs()
	self.globj.geometry:draw()
	self.globj:disableAttrs()
	--]=]
	self.globj.program:useNone()
	--]]

	App.super.update(self)
end

App():run()
