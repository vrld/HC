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
if not (common and common.class and common.instance) then
	class_commons = true
	require(_NAME .. '.class')
end
local Shapes      = require(_NAME .. '.shapes')
local Spatialhash = require(_NAME .. '.spatialhash')

local newPolygonShape = Shapes.newPolygonShape
local newCircleShape  = Shapes.newCircleShape
local newPointShape   = Shapes.newPointShape

local function __NULL__() end

local HC = {}
function HC:init(cell_size, callback_collide, callback_stop)
	self._active_shapes  = {}
	self._passive_shapes = {}
	self._ghost_shapes   = {}
	self.groups          = {}
	self._colliding_only_last_frame = {}

	self.on_collide = callback_collide or __NULL__
	self.on_stop    = callback_stop    or __NULL__
	self._hash      = common.instance(Spatialhash, cell_size)
end

function HC:clear()
	self._active_shapes  = {}
	self._passive_shapes = {}
	self._ghost_shapes   = {}
	self.groups          = {}
	self._colliding_only_last_frame = {}
	self._hash           = common.instance(Spatialhash, self._hash.cell_size)
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

function HC:addShape(shape)
	assert(shape.bbox and shape.collidesWith,
		"Cannot add custom shape: Incompatible shape.")

	self._active_shapes[shape] = shape
	self._hash:insert(shape, shape:bbox())
	shape._groups = {}

	local hash = self._hash
	local move, rotate,scale = shape.move, shape.rotate, shape.scale
	for _, func in ipairs{'move', 'rotate', 'scale'} do
		local old_func = shape[func]
		shape[func] = function(self, ...)
			local x1,y1,x2,y2 = self:bbox()
			old_func(self, ...)
			local x3,y3,x4,y4 = self:bbox()
			hash:update(self, x1,y1, x2,y2, x3,y3, x4,y4)
		end
	end

	function shape:neighbors()
		local neighbors = hash:inRange(self:bbox())
		rawset(neighbors, self, nil)
		return neighbors
	end

	function shape:_removeFromHash()
		return hash:remove(shape, self:bbox())
	end

	function shape:inGroup(group)
		return self._groups[group]
	end

	return shape
end

function HC:activeShapes()
	return pairs(self._active_shapes)
end

function HC:shapesInRange(x1,y1, x2,y2)
	return self._hash:inRange(x1,y1, x2,y2)
end

function HC:addPolygon(...)
	return self:addShape(newPolygonShape(...))
end

function HC:addRectangle(x,y,w,h)
	return self:addPolygon(x,y, x+w,y, x+w,y+h, x,y+h)
end

function HC:addCircle(cx, cy, radius)
	return self:addShape(newCircleShape(cx,cy, radius))
end

function HC:addPoint(x,y)
	return self:addShape(newPointShape(x,y))
end

function HC:share_group(shape, other)
	for name,group in pairs(shape._groups) do
		if group[other] then return true end
	end
	return false
end

-- check for collisions
function HC:update(dt)
	-- cache for tested/colliding shapes
	local tested, colliding = {}, {}
	local function may_skip_test(shape, other)
		return (shape == other)
		    or (tested[other] and tested[other][shape])
		    or self._ghost_shapes[other]
		    or self:share_group(shape, other)
	end

	-- collect active shapes. necessary, because a callback might add shapes to
	-- _active_shapes, which will lead to undefined behavior (=random crashes) in
	-- next()
	local active = {}
	for shape in self:activeShapes() do
		active[shape] = shape
	end

	local only_last_frame = self._colliding_only_last_frame
	for shape in pairs(active) do
		tested[shape] = {}
		for other in self._hash:rangeIter(shape:bbox()) do
			if not self._active_shapes[shape] then
				-- break out of this loop is shape was removed in a callback
				break
			end

			if not may_skip_test(shape, other) then
				local collide, sx,sy = shape:collidesWith(other)
				if collide then
					if not colliding[shape] then colliding[shape] = {} end
					colliding[shape][other] = {sx, sy}

					-- flag shape colliding this frame and call collision callback
					if only_last_frame[shape] then
						only_last_frame[shape][other] = nil
					end
					self.on_collide(dt, shape, other, sx, sy)
				end
				tested[shape][other] = true
			end
		end
	end

	-- call stop callback on shapes that do not collide anymore
	for a,reg in pairs(only_last_frame) do
		for b, info in pairs(reg) do
			self.on_stop(dt, a, b, info[1], info[2])
		end
	end

	self._colliding_only_last_frame = colliding
end

-- get list of shapes at point (x,y)
function HC:shapesAt(x, y)
	local shapes = {}
	for s in pairs(self._hash:cellAt(x,y)) do
		if s:contains(x,y) then
			shapes[#shapes+1] = s
		end
	end
	return shapes
end

-- remove shape from internal tables and the hash
function HC:remove(shape, ...)
	if not shape then return end
	self._active_shapes[shape]  = nil
	self._passive_shapes[shape] = nil
	self._ghost_shapes[shape]   = nil
	shape:_removeFromHash()

	return self:remove(...)
end

-- group support
function HC:addToGroup(group, shape, ...)
	if not shape then return end
	assert(self._active_shapes[shape] or self._passive_shapes[shape],
		"Shape is not registered with HC")
	if not self.groups[group] then self.groups[group] = {} end
	self.groups[group][shape] = true
	shape._groups[group]      = self.groups[group]
	return self:addToGroup(group, ...)
end

function HC:removeFromGroup(group, shape, ...)
	if not shape or not self.groups[group] then return end
	assert(self._active_shapes[shape] or self._passive_shapes[shape],
		"Shape is not registered with HC")
	self.groups[group][shape] = nil
	shape._groups[group]      = nil
	return self:removeFromGroup(group, ...)
end

function HC:setPassive(shape, ...)
	if not shape then return end
	if not self._ghost_shapes[shape] then
		assert(self._active_shapes[shape], "Shape is not active")
		self._active_shapes[shape] = nil
		self._passive_shapes[shape] = shape
	end
	return self:setPassive(...)
end

function HC:setActive(shape, ...)
	if not shape then return end
	if not self._ghost_shapes[shape] then
		assert(self._passive_shapes[shape], "Shape is not passive")
		self._active_shapes[shape]  = shape
		self._passive_shapes[shape] = nil
	end

	return self:setActive(...)
end

function HC:setGhost(shape, ...)
	if not shape then return end
	assert(self._active_shapes[shape] or self._passive_shapes[shape],
		"Shape is not registered with HC")

	self._active_shapes[shape] = nil
	-- dont remove from passive shapes, see below
	self._ghost_shapes[shape] = shape
	return self:setGhost(...)
end

function HC:setSolid(shape, ...)
	if not shape then return end
	assert(self._ghost_shapes[shape], "Shape not a ghost")

	-- re-register shape. passive shapes were not unregistered above, so if a shape
	-- is not passive, it must be registered as active again.
	if not self._passive_shapes[shape] then
		self._active_shapes[shape] = shape
	end
	self._ghost_shapes[shape] = nil
	return self:setSolid(...)
end

-- the module
HC = common.class("HardonCollider", HC)
local function new(...)
	return common.instance(HC, ...)
end

return setmetatable({HardonCollider = HC, new = new},
	{__call = function(_,...) return new(...) end})
