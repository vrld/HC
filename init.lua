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

local _NAME = (...)
local Class       = require(_NAME .. '.class')
local Shapes      = require(_NAME .. '.shapes')
local Spatialhash = require(_NAME .. '.spatialhash')
local vector      = require(_NAME .. '.vector')

local PolygonShape = Shapes.PolygonShape
local CircleShape  = Shapes.CircleShape
local PointShape   = Shapes.PointShape

local function __NULL__() end

local HC = Class{name = "HardonCollider", function(self, cell_size, callback_collide, callback_stop)
	self._active_shapes  = {}
	self._passive_shapes = {}
	self._ghost_shapes   = {}
	self._current_shape_id = 0
	self._shape_ids      = setmetatable({}, {__mode = "k"}) -- reverse lookup
	self.groups          = {}
	self._colliding_last_frame = {}

	self.on_collide = callback_collide or __NULL__
	self.on_stop    = callback_stop    or __NULL__
	self._hash      = Spatialhash(cell_size)
end}

function HC:clear()
	self._active_shapes  = {}
	self._passive_shapes = {}
	self._ghost_shapes   = {}
	self._current_shape_id = 0
	self._shape_ids      = setmetatable({}, {__mode = "k"}) -- reverse lookup
	self.groups          = {}
	self._colliding_last_frame = {}
	self._hash           = Spatialhash(self.hash.cell_size)
	return self
end

function HC:setCallbacks(collide, stop)
	if type(collide) == "table" and not (getmetatable(collide) or {}).__call then
		stop = collide.stop
		collide = collide.collide
	end

	if collide then
		assert(type(collide) == "function" or (getmetatable(collide) or {}).__call,
			"collision callback must be a function or callable table")
		self.on_collide = collide
	end

	if stop then
		assert(type(stop) == "function" or (getmetatable(stop) or {}).__call,
			"stop callback must be a function or callable table")
		self.on_stop = stop
	end

	return self
end

local function new_shape(self, shape, ul,lr)
	self._current_shape_id = self._current_shape_id + 1
	self._active_shapes[self._current_shape_id] = shape
	self._shape_ids[shape] = self._current_shape_id
	self._hash:insert(shape, ul,lr)
	shape._groups = {}
	return shape
end

-- create polygon shape and add it to internal structures
function HC:addPolygon(...)
	local shape = PolygonShape(...)
	local hash = self._hash

	-- replace shape member function with a function that updates
	-- the hash
	local function hash_aware_member(oldfunc)
		return function(self, ...)
			local x1,y1, x2,y2 = self._polygon:getBBox()
			oldfunc(self, ...)
			local x3,y3, x4,y4 = self._polygon:getBBox()
			hash:update(shape, vector(x1,y1), vector(x2,y2), vector(x3,y3), vector(x4,y4))
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
		hash:remove(shape) --, vector(x1,y1), vector(x2,y2))
	end

	local x1,y1, x2,y2 = shape._polygon:getBBox()
	return new_shape(self, shape, vector(x1,y1), vector(x2,y2))
end

function HC:addRectangle(x,y,w,h)
	return self:addPolygon(x,y, x+w,y, x+w,y+h, x,y+h)
end

-- create new polygon approximation of a circle
function HC:addCircle(cx, cy, radius)
	local shape = CircleShape(cx,cy, radius)
	local hash = self._hash

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
	return new_shape(self, shape, c-r, c+r)
end

function HC:addPoint(x,y)
	local shape = PointShape(x,y)
	local hash = self._hash

	local function hash_aware_member(oldfunc)
		return function(self, ...)
			rawset(hash:cell(self._pos), self, nil)
			oldfunc(self, ...)
			rawset(hash:cell(self._pos), self, self)
		end
	end

	shape.move = hash_aware_member(shape.move)
	shape.rotate = hash_aware_member(shape.rotate)

	function shape:_getNeighbors()
		local set = {}
		for _,other in pairs(hash:cell(self._pos)) do
			rawset(set, other, other)
		end
		rawset(set, self, nil)
		return set
	end

	function shape:_removeFromHash()
		hash:remove(self, self._pos, self._pos)
	end

	return new_shape(self, shape, shape._pos, shape._pos)
end

function HC:share_group(shape, other)
	for name,group in pairs(shape._groups) do
		if group[other] then return true end
	end
	return false
end


-- get unique indentifier for an unordered pair of shapes, i.e.:
-- collision_id(s,t) = collision_id(t,s)
local function collision_id(self,s,t)
	local i,k = self._shape_ids[s], self._shape_ids[t]
	if i < k then i,k = k,i end
	return string.format("%d,%d", i,k)
end

-- check for collisions
function HC:update(dt)
	-- collect colliding shapes
	local tested, colliding = {}, {}
	for _,shape in pairs(self._active_shapes) do
		local neighbors = shape:_getNeighbors()
		for _,other in pairs(neighbors) do
			local id = collision_id(self, shape,other)
			if not tested[id] then
				if not (self._ghost_shapes[other] or self:share_group(shape, other)) then
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
		self._colliding_last_frame[id] = nil
		self.on_collide( dt, unpack(info) )
	end

	-- call stop callback on shapes that do not collide anymore
	for _,info in pairs(self._colliding_last_frame) do
		self.on_stop( dt, unpack(info) )
	end

	self._colliding_last_frame = colliding
end

-- remove shape from internal tables and the hash
function HC:remove(shape)
	local id = self._shape_ids[shape]
	if id then
		self._active_shapes[id] = nil
		self._passive_shapes[id] = nil
	end
	self._ghost_shapes[shape] = nil
	self._shape_ids[shape] = nil
	shape:_removeFromHash()

	return shape
end

-- group support
function HC:addToGroup(group, shape, ...)
	if not shape then return end
	assert(self._shape_ids[shape], "Shape not registered!")

	if not self.groups[group] then self.groups[group] = {} end
	self.groups[group][shape] = true
	shape._groups[group] = self.groups[group]
	return self:addToGroup(group, ...)
end

function HC:removeFromGroup(group, shape, ...)
	if not shape or not self.groups[group] then return end
	assert(self._shape_ids[shape], "Shape not registered!")

	self.groups[group][shape] = nil
	shape._groups[group] = nil
	return self:removeFromGroup(group, ...)
end

function HC:setPassive(shape, ...)
	if not shape then return end
	assert(self._shape_ids[shape], "Shape not registered!")

	local id = self._shape_ids[shape]
	if not id or self._ghost_shapes[shape] then return end

	self._active_shapes[id] = nil
	self._passive_shapes[id] = shape

	return self:setPassive(...)
end

function HC:setActive(shape, ...)
	if not shape then return end
	assert(self._shape_ids[shape], "Shape not registered!")

	local id = self._shape_ids[shape]
	if not id or self._ghost_shapes[shape] then return end

	self._active_shapes[id] = shape
	self._passive_shapes[id] = nil

	return self:setActive(...)
end

function HC:setGhost(shape, ...)
	if not shape then return end
	local id = self._shape_ids[shape]
	assert(id, "Shape not registered!")

	self._active_shapes[id] = nil
	-- dont remove from passive shapes, see below
	self._ghost_shapes[shape] = shape
	return self:setGhost(...)
end

function HC:setSolid(shape, ...)
	if not shape then return end
	local id = self._shape_ids[shape]
	assert(id, "Shape not registered!")

	-- re-register shape. passive shapes were not unregistered above, so if a shape
	-- is not passive, it must be registered as active again.
	if not self._passive_shapes[id] then
		self._active_shapes[id] = shape
	end
	self._ghost_shapes[shape] = nil
	return self:setSolid(...)
end

return setmetatable({new = HC}, {__call = function(_,...) return HC(...) end})
