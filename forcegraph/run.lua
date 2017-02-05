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

	self.c = CayleyDickson(3)

	local angleForIndex = table{
		1, 2, 5, 3, 7, 6, 4
	}:map(function(v,k) return k,v end)

	self.vtxs = table()
	for i=1,#self.c-1 do
		local angle = (angleForIndex[i]-1) / (#self.c - 1) * 360
		self.vtxs[i] = {
			pos = quat():fromAngleAxis(0,0,1,angle):rotate(
				quat():fromAngleAxis(0,1,0,angle/2):rotate{0,0,.1} 
					+ {1,0,0}
			),
			vel = vec3(),
		}
	end

	self.triplets = self.c:getTriplets()
--[[
	 e0	 e1	 e2	 e3	 e4	 e5	 e6	 e7
e0	+e0	+e1	+e2	+e3	+e4	+e5	+e6	+e7
e1	+e1	-e0	+e3	-e2	+e5	-e4	-e7	+e6
e2	+e2	-e3	-e0	+e1	+e6	+e7	-e4	-e5
e3	+e3	+e2	-e1	-e0	+e7	-e6	+e5	-e4
e4	+e4	-e5	-e6	-e7	-e0	+e1	+e2	+e3
e5	+e5	+e4	-e7	+e6	-e1	-e0	-e3	+e2
e6	+e6	+e7	+e4	-e5	-e2	+e3	-e0	-e1
e7	+e7	-e6	+e5	+e4	-e3	-e2	+e1	-e0

triplets:
1 2 3
2 5 7
3 6 5
3 4 7
1 7 6
2 4 6
1 4 5

mobius strip:
1 2 . 3 . .  .
. 2 5 . 7 .  .
. . 5 3 . 6  .
. . . 3 7 . -4
1 . . . 7 6  .
. 2 . . . 6 -4
1 . 5 . . . -4


	 e0	 e1	 e2	 e3	 e4	 e5	 e6	 e7	 e8	 e9	 eA	 eB	 eC	 eD	 eE	 eF
e0	+e0	+e1	+e2	+e3	+e4	+e5	+e6	+e7	+e8	+e9	+eA	+eB	+eC	+eD	+eE	+eF
e1	+e1	-e0	+e3	-e2	+e5	-e4	-e7	+e6	+e9	-e8	-eB	+eA	-eD	+eC	+eF	-eE
e2	+e2	-e3	-e0	+e1	+e6	+e7	-e4	-e5	+eA	+eB	-e8	-e9	-eE	-eF	+eC	+eD
e3	+e3	+e2	-e1	-e0	+e7	-e6	+e5	-e4	+eB	-eA	+e9	-e8	-eF	+eE	-eD	+eC
e4	+e4	-e5	-e6	-e7	-e0	+e1	+e2	+e3	+eC	+eD	+eE	+eF	-e8	-e9	-eA	-eB
e5	+e5	+e4	-e7	+e6	-e1	-e0	-e3	+e2	+eD	-eC	+eF	-eE	+e9	-e8	+eB	-eA
e6	+e6	+e7	+e4	-e5	-e2	+e3	-e0	-e1	+eE	-eF	-eC	+eD	+eA	-eB	-e8	+e9
e7	+e7	-e6	+e5	+e4	-e3	-e2	+e1	-e0	+eF	+eE	-eD	-eC	+eB	+eA	-e9	-e8
e8	+e8	-e9	-eA	-eB	-eC	-eD	-eE	-eF	-e0	+e1	+e2	+e3	+e4	+e5	+e6	+e7
e9	+e9	+e8	-eB	+eA	-eD	+eC	+eF	-eE	-e1	-e0	-e3	+e2	-e5	+e4	+e7	-e6
eA	+eA	+eB	+e8	-e9	-eE	-eF	+eC	+eD	-e2	+e3	-e0	-e1	-e6	-e7	+e4	+e5
eB	+eB	-eA	+e9	+e8	-eF	+eE	-eD	+eC	-e3	-e2	+e1	-e0	-e7	+e6	-e5	+e4
eC	+eC	+eD	+eE	+eF	+e8	-e9	-eA	-eB	-e4	+e5	+e6	+e7	-e0	-e1	-e2	-e3
eD	+eD	-eC	+eF	-eE	+e9	+e8	+eB	-eA	-e5	-e4	+e7	-e6	+e1	-e0	+e3	-e2
eE	+eE	-eF	-eC	+eD	+eA	-eB	+e8	+e9	-e6	-e7	-e4	+e5	+e2	-e3	-e0	+e1
eF	+eF	+eE	-eD	-eC	+eB	+eA	-e9	+e8	-e7	+e6	-e5	-e4	+e3	+e2	-e1	-e0

triplets:   in ring #s:
1 2 3       1 2 3
1 4 5       1     4 5
1 7 6       1         6 7
1 8 9             4   6
1 B A         2     5   7
1 D C           3 4     7
1 E F           3   5 6
2 4 6       1
2 5 7       1
2 8 A         2
2 9 B         2
2 E C           3
2 F D           3
3 4 7       1
3 6 5       1
3 8 B         2
3 A 9         2
3 D E           3
3 F C           3
4 8 C             4
4 9 D             4
4 A E               5
4 B F               5
5 8 D             4
5 A F               5
5 C 9             4
5 E B               5
6 8 E                 6
6 B D                   7
6 C A                   7
6 F 9                 6
7 8 F                 6
7 9 E                 6
7 C B                   7
7 D A                   7

mobius strips:
ring #1:
1 2 5 3 7 6 -4:
1 2 . 3 . .  .	<- repeat in ring #2b, #3b
. 2 5 . 7 .  .
. . 5 3 . 6  .
. . . 3 7 . -4
1 . . . 7 6  .
. 2 . . . 6 -4
1 . 5 . . . -4

ring #2:
1 2 8 3 A -B 9:
1 2 . 3 .  . .
. 2 8 . A  . .
. . 8 3 . -B .
. . . 3 A  . 9
1 . . . A -B .
. 2 . . . -B 9

ring #3:
 1 2 E 3 C D -F:
 1 2 . 3 . .  .
 . 2 E . C .  .
 . . E 3 . D  .
 . . . 3 C . -F
-1 . . . C D  .	<- flip signs, so this is a double ring
 . 2 . . . D -F
-1 . E . . . -F

ring #4:
1 4 8 5 C -D 9:
1 4 . 5 .  . .
. 4 8 . C  . .
. . 8 5 . -D .
. . . 5 C  . 9
1 . . . C -D .
. 4 . . . -D 9
1 . 8 . .  . 9

ring #5:
 1 4 A 5 E -F B:
 1 4 . 5 .  . .
 . 4 A . E  . .
 . . A 5 . -F .
 . . . 5 E  . B
-1 . . . E -F .	<- flip signs
 . 4 . . . -F B
-1 . A . .  . B

ring #6:
1 7 8 6 F -E 9:
1 7 . 6 .  . .
. 7 8 . F  . .
. . 8 6 . -E .
. . . 6 F  . 9
1 . . . F -E .
. 7 . . . -E 9
1 . 8 . .  . 9

ring #7
 1 7 C 6 B -A D:
 1 7 . 6 .  . .
 . 7 C . B  . .
 . . C 6 . -A .
 . . . 6 B  . D
-1 . . . B -A .	<- flip signs
 . 7 . . . -A D
-1 . C . .  . D


ring #2b:
1 8 A 9 2 3 -B:
1 8 . 9 . .  .
. 8 A . 2 .  .
. . A 9 . 3  .
. . . 9 2 . -B
1 . . . 2 3  .	<- repeat in ring #1
. 8 . . . 3 -B
1 . A . . . -B

ring #3b
 1 D . C .  .  .
 . D 2 . F  .  .
 . . 2 C . -E  .
 . . . C F  . -3 
 1 . . . F -E  .
 . D . . . -E -3
-1 . 2 . .  . -3 <- repeat in ring #1 ... sign is flipped, so this ring is doubled

all triplets together:
1 2   3
  2 5   7
    5 3    6
1     4 5
1         7 6
1             8 9
1                 B A
1                     -C D
1                           E F 
  2   4     6
  2           8     A
  2             9 B
  2                    -C   E
  2                 F D
    3 4   7
    3         8   B
    3               A 9
3 D E
3 F C
4 8 C
4 9 D
4 A E
4 B F
5 8 D
5 A F
5 C 9
5 E B
6 8 E
6 B D
6 C A
6 F 9
7 8 F
7 9 E
7 C B
7 D A


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
		table{1,0,0},
		table{0,1,0},
		table{0,0,1},
	}

	gl.glBegin(gl.GL_TRIANGLES)
	for _,triplet in ipairs(self.triplets) do
		for j=1,3 do
			gl.glColor3d(colors[j]:unpack())
			gl.glVertex3d(self.vtxs[triplet[j].index].pos:unpack())
		end
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
