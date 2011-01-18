--[[
Copyright (c) 2011 Matthias Richter

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

Except as contained in this notice, the name(s) of the above copyright holders
shall not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]--

module(..., package.seeall)
require(_NAME .. '.shape')
require(_NAME .. '.polygon')
require(_NAME .. '.spatialhash')
require(_NAME .. '.vector')

local PolygonShape = shape.PolygonShape
local CircleShape  = shape.CircleShape

local is_initialized = false
hash = nil

local shapes, ghosts = {}, {}
local shape_ids = {}
local groups = {}

local function __NOT_INIT() error("Not yet initialized") end
local function __NULL() end
local cb_start, cb_persist, cb_stop = __NOT_INIT, __NOT_INIT, __NOT_INIT

function init(cell_size, callback_start, callback_persist, callback_stop)
	cb_start   = callback_start   or __NULL
	cb_persist = callback_persist or __NULL
	cb_stop    = callback_stop    or __NULL
	hash = spatialhash(cell_size)
	is_initialized = true
end

function setCallbacks(start,persist,stop)
	local tbl = start
	if type(start) == "function" then
		tbl = {start = start, persist = persist, stop = stop}
	end
	if tbl.start   then cb_start   = tbl.start   end
	if tbl.persist then cb_persist = tbl.persist end
	if tbl.stop    then cb_stop    = tbl.stop    end
end

local function new_shape(shape, ul,lr)
	shapes[#shapes+1] = shape
	shape_ids[shape] = #shapes
	hash:insert(shape, ul,lr)
	shape._groups = {}
	return shape
end

-- create polygon shape and add it to internal structures
function addPolygon(...)
	assert(is_initialized, "Not properly initialized!")
	local shape = PolygonShape(...)

	-- replace shape member function with a function that updates
	-- the hash
	local function hash_aware_member(oldfunc)
		return function(self, ...)
			local x1,y1, x2,y2 = self._polygon:getBBox()
			oldfunc(self, ...)
			local x3,y3, x4,y4 = self._polygon:getBBox()
			hash:update(self, vector(x1,y1), vector(x2,y2), vector(x3,y3), vector(x4,y4))
		end
	end
	shape.move = hash_aware_member(shape.move)
	shape.rotate = hash_aware_member(shape.rotate)

	function shape:_getNeighbors()
		local x1,y1, x2,y2 = self._polygon:getBBox()
		return hash:getNeighbors(self, vector(x1,y1), vector(x2,y2))
	end
	function shape:_removeFromHash()
		local x1,y1, x2,y2 = self._polygon:getBBox()
		hash:remove(shape, vector(x1,y1), vector(x2,y2))
	end

	local x1,y1, x2,y2 = shape._polygon:getBBox()
	return new_shape(shape, vector(x1,y1), vector(x2,y2))
end

function addRectangle(x,y,w,h)
	return addPolygon(x,y, x+w,y, x+w,y+h, x,y+h)
end

-- create new polygon approximation of a circle
function addCircle(cx, cy, radius)
	assert(is_initialized, "Not properly initialized!")
	local shape = CircleShape(cx,cy, radius)
	local function hash_aware_member(oldfunc)
		return function(self, ...)
			local r = vector(self._radius, self._radius)
			local c1 = self._center
			oldfunc(self, ...)
			local c2 = self._center
			hash:update(self, c1-r, c1+r, c2-r, c2+r)
		end
	end
	shape.move = hash_aware_member(shape.move)
	shape.rotate = hash_aware_member(shape.rotate)
	function shape:_getNeighbors()
		local c,r = self._center, vector(self._radius, self._radius)
		return hash:getNeighbors(self, c-r, c+r)
	end
	function shape:_removeFromHash()
		local c,r = self._center, vector(self._radius, self._radius)
		hash:remove(self, c-r, c+r)
	end

	local c,r = shape._center, vector(radius,radius)
	return new_shape(shape, c-r, c+r)
end

-- get unique indentifier for an unordered pair of shapes, i.e.:
-- collision_id(s,t) = collision_id(t,s)
local function collision_id(s,t)
	local i,k = shape_ids[s], shape_ids[t]
	if i < k then i,k = k,i end
	return string.format("%d,%d", i,k)
end

local function share_group(shape, other)
	for name,group in pairs(shape._groups) do
		if group[other] then return true end
	end
	return false
end

-- update with a minimum time step
local function update_min_step(dt, min_step)
	-- step fixed to framerate of ~33
	local min_step = min_step or 0.03
	while dt > min_step do
		update(min_step)
		dt = dt - min_step
	end
	update(dt)
end

-- check for collisions
local colliding_last_frame = {}
function update(dt, min_step)
	if min_step then
		update_min_step(dt, min_step)
		return
	end
	-- collect colliding shapes
	local tested, colliding = {}, {}
	for _,shape in pairs(shapes) do
		local neighbors = shape:_getNeighbors()
		for _,other in ipairs(neighbors) do
			local id = collision_id(shape,other)
			if not tested[id] then
				if not (other._ghost or share_group(shape, other)) then
					local collide, sep = shape:collidesWith(other)
					if collide then
						colliding[id] = {shape, other, sep.x, sep.y}
					end
					tested[id] = true
				end
			end
		end
	end

	-- call colliding callbacks on colliding shapes
	for id,info in pairs(colliding) do
		if colliding_last_frame[id] then
			colliding_last_frame[id] = nil
			cb_persist( dt, unpack(info) )
		else
			cb_start( dt, unpack(info) )
		end
	end

	-- call stop callback on shapes that do not collide
	-- anymore
	for _,info in pairs(colliding_last_frame) do
		cb_stop( dt, unpack(info) )
	end

	colliding_last_frame = colliding
end

-- remove shape from internal tables and the hash
function remove(shape)
	local id = shape_ids[shape]
	shapes[id] = nil
	ghosts[id] = nil
	shape_ids[shape] = nil
	shape:_removeFromHash()
end

-- group support
function addToGroup(group, shape, ...)
	if not shape then return end
	if not groups[group] then groups[group] = {} end
	groups[group][shape] = true
	shape._groups[group] = groups[group]
	return addToGroup(group, ...)
end

function removeFromGroup(group, shape, ...)
	if not shape or not groups[group] then return end
	groups[group][shape] = nil
	shape._groups[group] = nil
	return removeFromGroup(group, ...)
end

function setGhost(shape, ...)
	if not shape then return end
	local id = shape_ids[shape]
	shapes[id] = nil
	ghosts[id] = shape
	shape._ghost = true
	return setGhost(...)
end

function setSolid(shape, ...)
	if not shape then return end
	local id = shape_ids[shape]
	ghosts[id] = nil
	shapes[id] = shape
	shape._ghost = nil
	return setSolid(...)
end
