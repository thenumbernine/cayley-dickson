#!/usr/bin/env luajit
require 'ext'
local ffi = require 'ffi'
local bit = require 'bit'
local vec3 = require 'vec.vec3'
local sdl = require 'ffi.sdl'
local gl = require 'gl'
local quat = require 'vec.quat'
local GLApp = require 'glapp'
local Mouse = require 'glapp.mouse'
local CayleyDickson = require 'cayley-dickson'
local GLTex2D = require 'gl.tex2d'
local GLProgram = require 'gl.program'
local glCallOrRun = require 'gl.call'
local symmath = require 'symmath'

local mouse = Mouse()
local viewAngle = quat()

local app	-- running singleton
local App = class(GLApp)

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
		magFilter = gl.GL_LINEAR,
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
varying vec2 tc;
varying vec3 n;
uniform sampler2D tex;
uniform float texSize;
uniform float colorOffset;
void main() {
	float u = tc.s;
	float v = tc.t * .5;
#if 0	//if the spacing of the mobius was 0 1 2	
	float v7 = v * 7. - u * .5 + 1.;
	if (mod(v7, 1.) + u > 1.) {
		v += .5;
		u = 1. - u;
		v7 = v * 7. - u * .5 + 1.;
	}
#endif
#if 1	//with the 0 1 3 spacing 
	if (gl_FrontFacing) {
		v += .5;
		u = 1. - u;
	}
	float v7 = v * 7. + u * .5;
	if (mod(v7, 1.) + u > 1.) {
		
		//calculate the back:
		u = tc.s;
		v = tc.t * .5;
		if (!gl_FrontFacing) {
			v += .5;
			u = 1. - u;
		}
		v7 = v * 7. + u * .5;
		if (mod(v7, 1.) + u > 1.) {
			discard;
		}
	}
#endif
	float l = n.z;
	if (gl_FrontFacing) l = -l;
	l = max(.1, l);
l = 1.;

	l *= u;
	l *= 1. - u;
	l *= max(0., 1. - (mod(v7,1.) + u));
	l *= 6.;
	l = sqrt(l);

	gl_FragColor = l * texture2D(tex, vec2( (floor(v7) + .5) / texSize + colorOffset, .5));
}
]],
		uniforms = {
			tex = 0,
			texSize = 8,
			colorOffset = 0,
		},
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

local MobiusBand = class()

local useDeformSym = false
local useDeformNum = true
function MobiusBand:init(args)
	args = args or {}
	local deformations = args.deformations
	local width = args.width or .4
	local radius = args.radius or 1
	self.colorOffset = 0

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

	local function lenSq(p)
		p = p()
		assert(symmath.Matrix:isa(p))
		return range(#p):map(function(i)
			return p[i][1]^2
		end):sum()
	end

	-- deform symbolic-generation
	local function deformSym(p)
		p = p()
		local orig_p = p
		if deformations then
			for _,def in ipairs(deformations) do
				-- deformSym f from def.from to def.to
				local from = symvec(table.unpack(def.from))
				local to = symvec(table.unpack(def.to))
				p = p + (to - from) * symmath.exp(-def.infl * lenSq(orig_p - from))
				p = p()
			end
		end
		return p	
	end

	local f = R(0,0,1,v*2*math.pi) * (R(0,1,0,v*math.pi) * symvec(0,0,width*(2*u-1)) + symvec(radius,0,0))
	f = f()
	local orig_f = f
	if useDeformSym then f = deformSym(f) end
	local f_fn = symVecToLua(f)

	-- [[ normals computed:
	local df_du = orig_f:diff(u)()
	local df_dv = orig_f:diff(v)()
	local n = symvec( range(3):map(function(i)
		local j = i%3+1
		local k = j%3+1
		return df_du[j][1] * df_dv[k][1] - df_du[k][1] * df_dv[j][1]
	end):unpack() )
	n = n()
	if useDeformSym then n = deformSym(n) end
	local nlen = symmath.sqrt(lenSq(n))
	n = (n / nlen)()
	local n_fn = symVecToLua(n)
	--]]
	self.f_fn = f_fn
	self.n_fn = n_fn

	-- deform post-symbolic-generation
	-- also normalize weights of deformation . 
	-- NOTICE this means if you only pass one then *all* the shape will shift in that direction
	-- I would like a deformation where, at distance zero, the current weight gets 100% and all others get 0%, and it is gradual between
	local function deformNum(f)
		return function(u,v)
			local y = vec3(f(u,v))
			if deformations then
				local total = 0 
				local totalV = vec3(0,0,0)
				local weights = table()
				local deltas = table()
				for i,def in ipairs(deformations) do
					-- deformSym f from def.from to def.to
					local from = vec3(table.unpack(def.from))
					local to = vec3(table.unpack(def.to))
					local weight = math.exp(-def.infl * (y - from):lenSq())
					weights[i] = weight
					deltas[i] = to - from
				end
				local total = #deformations == 0 and 1 or weights:sum()
				for i=1,#deformations do
					y = y + deltas[i] * weights[i] / total
				end
			end
			return y:unpack()
		end
	end
	if useDeformNum then
		self.f_fn = deformNum(self.f_fn)
		self.n_fn = deformNum(self.n_fn)
	end
end
	
-- i is 1 through n
-- n is the # of vertexes in the mobius strip (an odd #)
local function vForMobiusVertex(i, n)
	local up = bit.band(i, 1)
	local j = bit.rshift(i, 1)
	return 2*(j-1 + up*.5)/n + up
end

function MobiusBand:draw()
	app.mobiusShader:use()
	gl.glUniform1f(app.mobiusShader.uniforms.colorOffset.loc, self.colorOffset)
	app.mobiusTex:bind()
	self.mobiusList = self.mobiusList or {}
	glCallOrRun(self.mobiusList, function()
		print('compiling draw list...')
		local idiv = 100
		local jdiv = 1000
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
		print('...done compiling draw list')
	end)
	app.mobiusTex:unbind()
	app.mobiusShader:useNone()

	--[[ draw points at vertexes
	gl.glPointSize(5)
	gl.glDisable(gl.GL_DEPTH_TEST)
	gl.glColor3d(1,1,1)
	gl.glBegin(gl.GL_POINTS)
	for i=1,7 do
		local v = vForMobiusVertex(i, 7)
		gl.glVertex3d(self.f_fn(0, v))
	end
	gl.glEnd()
	gl.glEnable(gl.GL_DEPTH_TEST)
	gl.glPointSize(1)
	--]]

	--[[ draw normal lines
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
end

function App:update()
	mouse:update()
	if mouse.leftDragging then
		if leftShiftDown or rightShiftDown then
			viewDist = viewDist * math.exp(10 * mouse.deltaPos.y)
		else
			local magn = mouse.deltaPos:length() * 1000
			if magn > 0 then
				local normDelta = mouse.deltaPos / magn
				local r = quat():fromAngleAxis(-normDelta.y, normDelta.x, 0, -magn)
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

	if not self.mobiusBands then
		--[[ typical mobius band:
		self.mobiusBands = table{MobiusBand()}
		--]]
		--[[ 7-vertex band with pts 6 and 7 exchanged
		local bigRing = MobiusBand()
		local pts = range(7):map(function(i)
			return vec3(bigRing.f_fn(0, vForMobiusVertex(i, 7)))
		end)

		local infl = 1
		self.mobiusBands = table{MobiusBand{
			deformations = range(7):map(function(j)
				local to = ({[6] = 7, [7] = 6})[j] or j
				return {
					from = pts[j],
					to = pts[to],
					infl = infl,
				}
			end),
		}}
		--]]
		-- [[ sedenions -- ring of bands
		local smallRing = MobiusBand()
		local smallPts = range(7):map(function(i)
			return vec3(smallRing.f_fn(0, vForMobiusVertex(i, 7)))
		end)
		
		local bigRing = MobiusBand()
		local bigPts = range(15):map(function(i)
			return vec3(bigRing.f_fn(0, vForMobiusVertex(i, 15)))
		end)
	
		local offsets = {0,1,2,4,5,8,10}
		self.mobiusBands = range(15):map(function(i)
			print('creating mobius band '..i..'...')
			return MobiusBand{
				deformations = range(7):map(function(j)
					return {
						from = smallPts[j],
						to = bigPts[(i-1+offsets[j])%15 + 1],
						infl = 1,
					}
				end),
			}
		end)
		--]]
	
		for i,band in ipairs(self.mobiusBands) do
			band.colorOffset = (i-1)/#self.mobiusBands/7
		end
	end

	for _,band in ipairs(self.mobiusBands) do band:draw() end

	-- now for making rings-of-rings ...
	-- I need a spatial deformation function ...
	-- so I can map points on the small ring to points on the big ring
	
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

app = App()
app:run()
