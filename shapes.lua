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
local Class   = require(_PACKAGE .. 'class')
local vector  = require(_PACKAGE .. 'vector')
local Polygon = require(_PACKAGE .. 'polygon')
_M.class = nil
_M.vector = nil
_M.polygon = nil

local function test_axes(axes, shape_one, shape_two, sep, min_overlap)
	for _,axis in ipairs(axes) do
		local l1,r1 = shape_one:projectOn(axis)
		local l2,r2 = shape_two:projectOn(axis)
		local overlap = math.min(r1,r2) - math.max(l1,l2)
		if overlap <= 0 then return false end

		if overlap < min_overlap then
			sep, min_overlap = -overlap * axis, overlap
		end
	end
	return true, sep, min_overlap
end

local function SAT(shape_one, axes_one, shape_two, axes_two)
	local collide, sep, overlap = false, vector(0,0), math.huge
	collide, sep, overlap = test_axes(axes_one, shape_one, shape_two, sep, overlap)
	if not collide then return false end
	collide, sep = test_axes(axes_two, shape_two, shape_one, sep, overlap)
	return collide, sep
end

local function outcircles_intersect(shape_one, shape_two)
	local x1,y1,r1 = shape_one:outcircle()
	local x2,y2,r2 = shape_two:outcircle()
	return (x1-x2)*(x1-x2) + (y1-y2)*(y1-y2) <= (r1+r2)*(r1+r2)
end

--
-- base class
--
local Shape = Class{name = 'Shape', function(self, t)
	self._type = t
end}

function Shape:moveTo(x,y)
	self:move(vector(x,y) - vector(self:center()))
end

-- supported shapes
Shape.POLYGON  = setmetatable({}, {__tostring = function() return 'POLYGON'  end})
Shape.COMPOUND = setmetatable({}, {__tostring = function() return 'COMPOUND' end})
Shape.CIRCLE   = setmetatable({}, {__tostring = function() return 'CIRCLE' end})

--
-- class definitions
--
local ConvexPolygonShape = Class{name = 'ConvexPolygonShape', function(self, polygon)
	Shape.construct(self, Shape.POLYGON)
	assert(polygon:isConvex(), "Polygon is not convex.")
	self._polygon = polygon
end}
ConvexPolygonShape:inherit(Shape)

local ConcavePolygonShape = Class{name = 'ConcavePolygonShape', function(self, poly)
	Shape.construct(self, Shape.COMPOUND)
	self._polygon = poly
	self._shapes = poly:splitConvex()
	for i,s in ipairs(self._shapes) do
		self._shapes[i] = ConvexPolygonShape(s)
	end
end}
ConcavePolygonShape:inherit(Shape)

function PolygonShape(polygon, ...)
	-- create from coordinates if needed
	if type(polygon) == "number" then
		polygon = Polygon(polygon, ...)
	else
		polygon = polygon:clone()
	end

	if polygon:isConvex() then
		return ConvexPolygonShape(polygon)
	end
	return ConcavePolygonShape(polygon)
end

CircleShape = Class{name = 'CircleShape', function(self, cx,cy, radius)
	Shape.construct(self, Shape.CIRCLE)
	self._center = vector(cx,cy)
	self._radius = radius
end}
CircleShape:inherit(Shape)

--
-- collision functions
--
function ConvexPolygonShape:getAxes()
	local axes = {}
	local vert = self._polygon.vertices
	for i = 1,#vert-1 do
		axes[#axes+1] = (vert[i+1]-vert[i]):perpendicular():normalize_inplace()
	end
	axes[#axes+1] = (vert[1]-vert[#vert]):perpendicular():normalize_inplace()
	return axes
end

function ConvexPolygonShape:projectOn(axis)
	local vertices = self._polygon.vertices
	local projection = {}
	for i = 1,#vertices do
		projection[i] = vertices[i] * axis -- same as vertices[i]:projectOn(axis) * axis
	end
	return math.min(unpack(projection)), math.max(unpack(projection))
end

function CircleShape:projectOn(axis)
	-- v:projectOn(a) * a = v * a (see ConvexPolygonShape)
	-- therefore: (c +- a*r) * a = c*a +- |a|^2 * r
	local center = self._center * axis
	local shift = self._radius * axis:len2()
	return center - shift, center + shift
end

-- collision dispatching:
-- let circle shape or compund shape handle the collision
function ConvexPolygonShape:collidesWith(other)
	if other._type ~= Shape.POLYGON then
		return other:collidesWith(self)
	end

	-- else: type is POLYGON, use the SAT
	if not outcircles_intersect(self, other) then return false end
	return SAT(self, self:getAxes(), other, other:getAxes())
end

function ConcavePolygonShape:collidesWith(other)
	if not outcircles_intersect(self, other) then return false end

	local sep, collide, collisions = vector(0,0), false, 0
	for _,s in ipairs(self._shapes) do
		local status, separating_vector = s:collidesWith(other)
		collide = collide or status
		if status then
			sep, collisions = sep + separating_vector, collisions + 1
		end
	end
	return collide, sep / collisions
end

function CircleShape:collidesWith(other)
	if other._type == Shape.CIRCLE then
		local d = self._center:dist(other._center)
		if d < self._radius + other._radius then
			return true, d * (self._center - other.center)
		end
		return false
	elseif other._type == Shape.COMPOUND then
		return other:collidesWith(self)
	end

	-- else: other._type == POLYGON
	if not outcircles_intersect(self, other) then return false end
	-- retrieve closest edge to center
	local points = other._polygon.vertices
	local closest, dist = points[1], (self._center - points[1]):len2()
	for i = 2,#points do
		local d = (self._center - points[i]):len2()
		if d < dist then
			closest, dist = points[i], d
		end
	end
	return SAT(self, {(closest-self._center):normalize_inplace()}, other, other:getAxes())
end

--
-- point location/ray intersection
--
function ConvexPolygonShape:contains(x,y)
	return self._polygon:contains(x,y)
end

function ConcavePolygonShape:contains(x,y)
	return self._polygon:contains(x,y)
end

function CircleShape:contains(x,y)
	return (vector(x,y) - self._center):len2() < self._radius * self._radius
end


function ConcavePolygonShape:intersectsRay(x,y, dx,dy)
	return self._polygon:intersectsRay(x,y, dx,dy)
end

function ConvexPolygonShape:intersectsRay(x,y, dx,dy)
	return self._polygon:intersectsRay(x,y, dx,dy)
end

-- circle intersection if distance of ray/center is smaller
-- than radius
function CircleShape:intersectsRay(x,y, dx,dy)
	local pc = vector(x,y) - self._center
	local d = vector(dx,dy)

	local a = d * d
	local b = 4 * d * pc
	local c = pc * pc - self._radius * self._radius
	local discriminant = b*b - 4*a*c
	if discriminant < 0 then return false end

	discriminant = math.sqrt(discriminant)
	return true, math.min(-b + discriminant, -b - discriminant) / (2*a)
end

--
-- auxiliary
--
function ConvexPolygonShape:center()
	return self._polygon.centroid:unpack()
end

function ConcavePolygonShape:center()
	return self._polygon.centroid:unpack()
end

function CircleShape:center()
	return self._center:unpack()
end


function ConvexPolygonShape:outcircle()
	local cx,cy = self:center()
	return cx,cy, self._polygon._radius
end

function ConcavePolygonShape:outcircle()
	local cx,cy = self:center()
	return cx,cy, self._polygon._radius
end

function CircleShape:outcircle()
	local cx,cy = self:center()
	return cx,cy, self._radius
end


function ConvexPolygonShape:move(x,y)
	self._polygon:move(x,y)
end

function ConcavePolygonShape:move(x,y)
	self._polygon:move(x,y)
	for _,p in ipairs(self._shapes) do
		p:move(x,y)
	end
end

function CircleShape:move(x,y)
	self._center = self._center + vector(x,y)
end


function ConcavePolygonShape:rotate(angle,cx,cy)
	self._polygon:rotate(angle,cx)
	for _,p in ipairs(self._shapes) do
		p:rotate(angle, cx and vector(cx,cy) or self._polygon.centroid)
	end
end

function ConvexPolygonShape:rotate(angle, cx,cy)
	self._polygon:rotate(angle, cx, cy)
end

function CircleShape:rotate(angle, cx,cy)
	if not cx then return end
	local c = vector(cx,cy)
	self._center = (self._center - c):rotate_inplace(angle) + c
end


function ConvexPolygonShape:draw(mode)
	local mode = mode or 'line'
	love.graphics.polygon(mode, self._polygon:unpack())
end

function ConcavePolygonShape:draw(mode)
	local mode = mode or 'line'
	if mode == 'line' then
		love.graphics.polygon('line', self._polygon:unpack())
	else
		for _,p in ipairs(self._shapes) do
			love.graphics.polygon(mode, p._polygon:unpack())
		end
	end
end

function CircleShape:draw(mode, segments)
	local segments = segments or math.max(3, math.floor(math.pi * math.log(self._radius)))
	love.graphics.circle(mode, self._center.x, self._center.y, self._radius, segments)
end

