#!/usr/bin/env rua
local gl = require 'gl'
local GLSceneObject = require 'gl.sceneobject'

local App = require 'imgui.appwithorbit'()
App.title = 'Octonion Multiplication Table'
App.initGL = |:|do
	App.super.initGL(self)

	self.lineObj = GLSceneObject{
		program = {
			version = 'latest',
			precision = 'best',
			vertexCode = [[
in vec3 vertex;
uniform mat4 mvProjMat;
void main() {
	gl_Position = mvProjMat * vec4(vertex, 1.);
}
]],
			fragmentCode = [[
out vec4 fragColor;
void main() {
	fragColor = vec4(1., 1., 1., 1.);
}
]],
		},
		geometry = {
			mode = gl.GL_LINES,
		},
		vertexes = {
			data = {
				0,0,0,
				1,0,0,
				0,0,0,
				0,1,0,
				0,0,0,
				0,0,1,
			},
			dim = 3,
		},
	}
end

App.update = |:|do
	gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT)

	self.lineObj.uniforms.mvProjMat = self.view.mvProjMat.ptr
	self.lineObj:draw()

	App.super.update(self)
end

return App():run()
