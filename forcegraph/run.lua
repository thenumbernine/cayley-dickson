#!/usr/bin/env luajit
require 'ext'
local ffi = require 'ffi'
local bit = require 'bit'
local vec3 = require 'vec.vec3'
local sdl = require 'ffi.sdl'
local gl = require 'ffi.OpenGL'
local quat = require 'vec.quat'
local Mouse = require 'gui.mouse'
local CayleyDickson = require 'cayley-dickson'
local GLTex2D = require 'gl.tex2d'
local GLProgram = require 'gl.program'

local mouse = Mouse()
local viewAngle = quat()

local App = class(require 'glapp')

App.title = 'Cayley-Dickson Mobius Renderer'

function App:initGL()
	gl.glEnable(gl.GL_DEPTH_TEST)
	gl.glDisable(gl.GL_CULL_FACE)

	self.c = CayleyDickson(3)

	local angleForIndex = table{
		1, 2, 5, 3, 7, 6, 4
	}:map(function(v,k) return k,v end)

	self.vtxs = table()
	for i=1,#self.c-1 do
		-- [[ mobius strip
		local angle = (angleForIndex[i]-1) / (#self.c - 1) * 360
		self.vtxs[i] = {
			pos = quat():fromAngleAxis(0,0,1,angle):rotate(
				quat():fromAngleAxis(0,1,0,angle/2):rotate{0,0,.5} 
					+ {1,0,0}
			),
			vel = vec3(),
		}
		--]]
		--[[ ring
		local angle = (i-1) / #self.c * 360
		self.vtxs[i] = {
			pos = quat():fromAngleAxis(0,0,1,angle):rotate(
				{1,0, .1 * ((i%2)*2-1)} 
			),		
			vel = vec3(),
		}
		--]]
		--[[ line
		local angle = (i-1) / #self.c * 360
		self.vtxs[i] = {
			pos = vec3(angle,0, .1 * ((i%2)*2-1)),
			vel = vec3(),
		}	
		--]]
	end

	self.triplets = self.c:getTriplets()

	self.mobiusTex = GLTex2D{
		width = 8,
		height = 1,
		format = gl.GL_RGB,
		internalFormat = gl.GL_RGB,
		type = gl.GL_UNSIGNED_BYTE,
		data = ffi.new('unsigned char[24]', {
			255,0,0,
			255,127,0,
			255,255,0,
			0,255,0,
			0,255,255,
			0,0,255,
			255,0,255,
			255,0,0
		}),
		minFilter = gl.GL_NEAREST,
		magFilter = gl.GL_NEAREST,
	}

	self.mobiusShader = GLProgram{
		vertexCode = [[
varying vec2 tc;
varying vec3 n;
void main() {
	gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex; 
	n = (gl_ModelViewMatrix * vec4(gl_Normal, 0.)).xyz;
	tc = gl_MultiTexCoord0.st;
}
]],
		fragmentCode = [[
#version 130
varying vec2 tc;
varying vec3 n;
uniform sampler2D tex;
void main() {
	float u = tc.s;
	float v = tc.t * .5;
	float v7 = v * 7. - u * .5 + 1.;
	if (mod(v7, 1.) + u > 1.) {
		v += .5;
		u = 1. - u;
		v7 = v * 7. - u * .5 + 1.;
	}
	float l = abs(n.z);
	gl_FragColor = l * texture2D(tex, vec2( (floor(v7) + .5) / 8., .5));
}
]],
		uniforms = {tex = 0},
	}
end

local function barylerp(vs, u,v,w)
--[[ linear
	return vs[1] * u + vs[2] * v + vs[3] * w
--]]
--[[ normalize
	return vs[1] * u + vs[2] * v + vs[3] * w
--]]
-- [[ spherical 
	return (vs[1] * u + vs[2] * v + vs[3] * w):normalize() * (
		vs[1]:length() * u + vs[2]:length() * v + vs[3]:length() * w
	)
--]]
end

function App:update()
	mouse:update()
	if mouse.leftDragging then
		if leftShiftDown or rightShiftDown then
			viewDist = viewDist * math.exp(10 * mouse.deltaPos[2])
		else
			local magn = mouse.deltaPos:length() * 1000
			if magn > 0 then
				local normDelta = mouse.deltaPos / magn
				local r = quat():fromAngleAxis(-normDelta[2], normDelta[1], 0, -magn)
				viewAngle = (viewAngle * r):normalize()
			end
		end
	end
	
	gl.glClear(bit.bor(gl.GL_COLOR_BUFFER_BIT, gl.GL_DEPTH_BUFFER_BIT))

	gl.glMatrixMode(gl.GL_PROJECTION)
	gl.glLoadIdentity()
	local znear = .1
	local zfar = 100
	local ar = self.width / self.height
	gl.glFrustum(-ar * znear, ar * znear, -znear, znear, znear, zfar) 

	gl.glMatrixMode(gl.GL_MODELVIEW)
	gl.glLoadIdentity()
	gl.glTranslatef(0,0,-2)
	local aa = viewAngle:conjugate():toAngleAxis()
	gl.glRotatef(aa[4], aa[1], aa[2], aa[3])

-- [[ draw mobius strip
	local radius = 1
	local width = .2

	if not self.f_fn then
		local symmath = require 'symmath'
		local x,y,z = symmath.vars('x', 'y', 'z')
		local xs = {x,y,z}
		local u = symmath.var('u', xs)
		local v = symmath.var('v', xs)

		local symvec = function(...) return symmath.Matrix{...}:transpose() end
		local function R(x,y,z,theta)
			local N = symmath.Matrix(
				{0, -z, y},
				{z, 0, -x},
				{-y, x, 0})
			return symmath.Matrix.identity(3) + (symmath.sin(theta) + (1 - symmath.cos(theta)) * N) * N
		end
		local function symVecToLua(p)
			local n = #p
			local fns = range(#p):map(function(i)
				return (p[i][1]:compile{u,v})
			end)
			return function(u,v)
				return range(n):map(function(i)
					return (fns[i](u,v))
				end):unpack()
			end
		end
		
		local f = R(0,0,1,v*2*math.pi) * (R(0,1,0,v*math.pi) * symvec(0,0,width*(2*u-1)) + symvec(radius,0,0))
		f = f()
		self.f_fn = symVecToLua(f)
		
		local df_du = f:diff(u)()
		local df_dv = f:diff(v)()
		local n = symvec( range(3):map(function(i)
			local j = i%3+1
			local k = j%3+1
			return df_du[j][1] * df_dv[k][1] - df_du[k][1] * df_dv[j][1]
		end):unpack() )
		n = n()
		local nlen = symmath.sqrt(n[1][1]^2 + n[2][1]^2 + n[3][1]^2)
		n = (n / nlen)()
		self.n_fn = symVecToLua(n)
	end

	local idiv = 10
	local jdiv = 100
	self.mobiusShader:use()
	self.mobiusTex:bind()
	for j=1,jdiv do
		gl.glBegin(gl.GL_TRIANGLE_STRIP)
		for i=0,idiv do
			for jofs=0,1 do
				local u = i/idiv
				local v = (j+jofs)/jdiv
				gl.glTexCoord2d(u,v)
				gl.glNormal3d(self.n_fn(u,v))
				gl.glVertex3d(self.f_fn(u,v))
			end
		end
		gl.glEnd()
	end
	self.mobiusTex:unbind()
	self.mobiusShader:useNone()

	-- draw points at vertexes
	gl.glPointSize(5)
	gl.glDisable(gl.GL_DEPTH_TEST)
	gl.glColor3d(1,1,1)
	gl.glBegin(gl.GL_POINTS)
	for i=1,7 do
		gl.glVertex3d(self.f_fn(0, 2*i/7))
	end
	gl.glEnd()
	gl.glEnable(gl.GL_DEPTH_TEST)
	gl.glPointSize(1)

	-- draw normal lines
	gl.glColor3d(0,1,1)
	gl.glBegin(gl.GL_LINES)
	for i=1,7 do
		local u = 2*i/7
		local v = vec3(self.f_fn(.5, u))
		local n = vec3(self.n_fn(.5, u))
		gl.glVertex3d(v:unpack())
		gl.glVertex3d((v+n*.5):unpack())
	end
	gl.glEnd()
--]]
--[==[
	local colors = {
		vec3(1,0,0),
		vec3(0,1,0),
		vec3(0,0,1),
	}

	gl.glBegin(gl.GL_TRIANGLES)
--	for _,triplet in ipairs(self.triplets) do
	for _,triplet in ipairs{{{index=1},{index=2},{index=3}}} do
--[[ draw flat triangles	
		for j=1,3 do
			gl.glColor3d(colors[j]:unpack())
			gl.glVertex3d(self.vtxs[triplet[j].index].pos:unpack())
		end
--]]
-- [=[ draw tesselated triangles
		local vs = range(3):map(function(i) return self.vtxs[triplet[i].index].pos end)
		local div = 5
		local d = 1/div
		for i=0,div-1 do
			local u = i/div
			for j=0,div-1-i do
				local v = j/div
				local k=div-1-i-j
				local w = k/div
				-- barycentric coordinates, so i+j+k = div-1
				gl.glColor3d(barylerp(colors,u+d,v,w):unpack())
				gl.glVertex3d(barylerp(vs,u+d,v,w):unpack())
				gl.glColor3d(barylerp(colors,u,v+d,w):unpack())
				gl.glVertex3d(barylerp(vs,u,v+d,w):unpack())
				gl.glColor3d(barylerp(colors,u,v,w+d):unpack())
				gl.glVertex3d(barylerp(vs,u,v,w+d):unpack())
				--[[
				if i>0 then
					gl.glColor3d(barylerp(colors,u-d,v,w):unpack())
					gl.glVertex3d(barylerp(vs,u-d,v,w):unpack())
					gl.glColor3d(barylerp(colors,u,v+d,w):unpack())
					gl.glVertex3d(barylerp(vs,u,v+d,w):unpack())
					gl.glColor3d(barylerp(colors,u,v,w+d):unpack())
					gl.glVertex3d(barylerp(vs,u,v,w+d):unpack())
				end
				--]]
				--[[
				if j<div-1 and k<div-1 then
					gl.glColor3d(barylerp(colors,u-2*d,v+d,w+d):unpack())
					gl.glVertex3d(barylerp(vs,u-2*d,v+d,w+d):unpack())
				end
				if i<div-1 and k<div-1 then
					gl.glColor3d(barylerp(colors,u+d,v-2*d,w+d):unpack())
					gl.glVertex3d(barylerp(vs,u+d,v-2*d,w+d):unpack())
				end
				if i<div-1 and j<div-1 then
					gl.glColor3d(barylerp(colors,u+d,v+d,w-2*d):unpack())
					gl.glVertex3d(barylerp(vs,u+d,v+d,w-2*d):unpack())			
				end
				--]]
			end
		end
--]=]
	end
	gl.glEnd()
--]==]

	--[[ push vertices away from each other
	local coeff = .001
	for i=1,#self.vtxs-1 do
		local vi = self.vtxs[i]
		for j=i+1,#self.vtxs do
			local vj = self.vtxs[j]
			local d = vi.pos - vj.pos
			local dLenSq = d:lenSq()
			d = d * coeff / dLenSq
			vi.vel = vi.vel + d
			vj.vel = vj.vel - d
		end
	end
	local dt = 1
	local damping = .99
	for i,vi in ipairs(self.vtxs) do
		vi.pos = (vi.pos + vi.vel * dt):normalize()
		vi.vel = vi.vel * damping
	end
	--]]
end

local leftShiftDown
local rightShiftDown 
function App:event(event)
	if event.type == sdl.SDL_MOUSEBUTTONDOWN then
		if event.button.button == sdl.SDL_BUTTON_WHEELUP then
			orbitTargetDistance = orbitTargetDistance * orbitZoomFactor
		elseif event.button.button == sdl.SDL_BUTTON_WHEELDOWN then
			orbitTargetDistance = orbitTargetDistance / orbitZoomFactor
		end
	elseif event.type == sdl.SDL_KEYDOWN or event.type == sdl.SDL_KEYUP then
		if event.key.keysym.sym == sdl.SDLK_LSHIFT then
			leftShiftDown = event.type == sdl.SDL_KEYDOWN
		elseif event.key.keysym.sym == sdl.SDLK_RSHIFT then
			rightShiftDown = event.type == sdl.SDL_KEYDOWN
		end
	end
end

App():run()
