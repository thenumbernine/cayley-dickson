#!/usr/bin/env luajit
require 'ext'
local bit = require 'bit'
local vec3 = require 'vec.vec3'
local sdl = require 'ffi.sdl'
local gl = require 'ffi.OpenGL'
local quat = require 'vec.quat'
local Mouse = require 'gui.mouse'
local CayleyDickson = require 'cayley-dickson'

local mouse = Mouse()
local viewAngle = quat()

local App = class(require 'glapp')

App.title = 'Force Directed Graph'

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
-- [[ draw tesselated triangles
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
--]]
	end
	gl.glEnd()

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
