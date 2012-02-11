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

local math_abs, math_floor, math_min, math_max = math.abs, math.floor, math.min, math.max
local math_sqrt, math_log, math_pi, math_huge = math.sqrt, math.log, math.pi, math.huge

local _PACKAGE = (...):match("^(.+)%.[^%.]+")
if not common and common.class then
	class_commons = true
	require(_PACKAGE .. '.class')
end
local vector  = require(_PACKAGE .. '.vector')
local Polygon = require(_PACKAGE .. '.polygon')

local function math_absmin(a,b) return math_abs(a) < math_abs(b) and a or b end
local function test_axes(axes, shape_one, shape_two, sep, min_overlap)
	for _,axis in ipairs(axes) do
		local l1,r1 = shape_one:projectOn(axis)
		local l2,r2 = shape_two:projectOn(axis)
		-- do the intervals overlap?
		if r1 < l2 or r2 < l1 then return false end

		-- get the smallest absolute overlap
		local overlap = math_absmin(l2-r1, r2-l1)
		if math_abs(overlap) < min_overlap then
			sep, min_overlap = overlap * axis, math_abs(overlap)
		end
	end
	return true, sep, min_overlap
end

local function SAT(shape_one, axes_one, shape_two, axes_two)
	local collide, sep, overlap = false, vector(0,0), math_huge
	collide, sep, overlap = test_axes(axes_one, shape_one, shape_two, sep, overlap)
	if not collide then return false end
	collide, sep = test_axes(axes_two, shape_one, shape_two, sep, overlap)
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
local Shape = {}
function Shape:init(t)
	self._type = t
	self._rotation = 0
end

function Shape:moveTo(x,y)
	local cx,cy = self:center()
	self:move(x - cx, y - cy)
end

function Shape:rotation()
	return self._rotation
end

function Shape:rotate(angle)
	self._rotation = self._rotation + angle
end

function Shape:setRotation(angle, x,y)
	return self:rotate(angle - self._rotation, x,y)
end

-- supported shapes
Shape.POLYGON  = setmetatable({}, {__tostring = function() return 'POLYGON'  end})
Shape.COMPOUND = setmetatable({}, {__tostring = function() return 'COMPOUND' end})
Shape.CIRCLE   = setmetatable({}, {__tostring = function() return 'CIRCLE' end})
Shape.POINT    = setmetatable({}, {__tostring = function() return 'POINT' end})

--
-- class definitions
--
local ConvexPolygonShape = {}
function ConvexPolygonShape:init(polygon)
	Shape.init(self, Shape.POLYGON)
	assert(polygon:isConvex(), "Polygon is not convex.")
	self._polygon = polygon
end

local ConcavePolygonShape = {}
function ConcavePolygonShape:init(poly)
	Shape.init(self, Shape.COMPOUND)
	self._polygon = poly
	self._shapes = poly:splitConvex()
	for i,s in ipairs(self._shapes) do
		self._shapes[i] = common.instance(ConvexPolygonShape, s)
	end
end

local CircleShape = {}
function CircleShape:init(cx,cy, radius)
	Shape.init(self, Shape.CIRCLE)
	self._center = vector(cx,cy)
	self._radius = radius
end

local PointShape = {}
function PointShape:init(x,y)
	Shape.init(self, Shape.POINT)
	self._pos = vector(x,y)
end

--
-- collision functions
--
function ConvexPolygonShape:getAxes()
	local axes = {}
	local vert = self._polygon.vertices
	for i = 1,#vert do
		axes[#axes+1] = (vert[i]-vert[(i%#vert)+1]):perpendicular():normalize_inplace()
	end
	return axes
end

function ConvexPolygonShape:projectOn(axis)
	local vertices = self._polygon.vertices
	local projection = {}
	for i = 1,#vertices do
		projection[i] = vertices[i] * axis -- same as vertices[i]:projectOn(axis) * axis
	end
	return math_min(unpack(projection)), math_max(unpack(projection))
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
		local collide, sep = other:collidesWith(self)
		return collide, sep and -sep
	end

	-- else: type is POLYGON, use the SAT
	if not outcircles_intersect(self, other) then return false end
	return SAT(self, self:getAxes(), other, other:getAxes())
end

function ConcavePolygonShape:collidesWith(other)
	if other._type == Shape.POINT then
		return other:collidesWith(self)
	end

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
		local radii = self._radius + other._radius
		if d < radii then
			-- if circles overlap, push it out upwards
			if d == 0 then return true, radii * vector(0,1) end
			-- otherwise push out in best direction
			return true, (radii - d) * (self._center - other._center):normalize_inplace()
		end
		return false
	elseif other._type == Shape.COMPOUND then
		local collide, sep = other:collidesWith(self)
		return collide, sep and -sep
	elseif other._type == Shape.POINT then
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
	local axis = vector(0,1)
	if dist ~= 0 then axis = (closest - self._center):normalize_inplace() end
	return SAT(self, {axis}, other, other:getAxes())
end

function PointShape:collidesWith(other)
	if other._type == Shape.POINT then
		return (self._pos == other._pos), vector(0,0)
	end
	return other:contains(self._pos.x, self._pos.y), vector(0,0)
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

function PointShape:contains(x,y)
	return x == self._pos.x and y == self._pos.y
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

	discriminant = math_sqrt(discriminant)
	return true, math_min(-b + discriminant, -b - discriminant) / (2*a)
end

-- point shape intersects ray if it lies on the ray
function PointShape:intersectsRay(x,y,dx,dy)
	local p = self._pos - vector(x,y)
	local d = vector(dx,dy)
	local t = p * d / d:len2()
	return t >= 0, t
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

function PointShape:center()
	return self._pos:unpack()
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

function PointShape:outcircle()
	return self._pos.x, self._pos.y, 0
end

function ConvexPolygonShape:bbox()
	return self._polygon:getBBox()
end

function ConcavePolygonShape:bbox()
	return self._polygon:getBBox()
end

function CircleShape:bbox()
	local cx,cy = self._center:unpack()
	local r = self._radius
	return cx-r,cy-r, cx+r,cy+r
end

function PointShape:bbox()
	local x,y = self._pos:unpack()
	return x,y,x,y
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

function PointShape:move(x,y)
	self._pos.x = self._pos.x + x
	self._pos.y = self._pos.y + y
end


function ConcavePolygonShape:rotate(angle,cx,cy)
	Shape.rotate(self, angle)
	self._polygon:rotate(angle,cx)
	for _,p in ipairs(self._shapes) do
		p:rotate(angle, cx and vector(cx,cy) or self._polygon.centroid)
	end
end

function ConvexPolygonShape:rotate(angle, cx,cy)
	Shape.rotate(self, angle)
	self._polygon:rotate(angle, cx, cy)
end

function CircleShape:rotate(angle, cx,cy)
	Shape.rotate(self, angle)
	if not cx then return end
	local c = vector(cx,cy)
	self._center = (self._center - c):rotate_inplace(angle) + c
end

function PointShape:rotate(angle, cx,cy)
	Shape.rotate(self, angle)
	if not cx then return end
	local c = vector(cx,cy)
	self._pos = (self._pos - c):rotate_inplace(angle) + c
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
	local segments = segments or math_max(3, math_floor(math_pi * math_log(self._radius)))
	love.graphics.circle(mode, self._center.x, self._center.y, self._radius, segments)
end

function PointShape:draw()
	love.graphics.point(self._pos.x, self._pos.y)
end


Shape = common.class('Shape', Shape)
ConvexPolygonShape  = common.class('ConvexPolygonShape',  ConvexPolygonShape,  Shape)
ConcavePolygonShape = common.class('ConcavePolygonShape', ConcavePolygonShape, Shape)
CircleShape         = common.class('CircleShape',         CircleShape,         Shape)
PointShape          = common.class('PointShape',          PointShape,          Shape)

local function newPolygonShape(polygon, ...)
	-- create from coordinates if needed
	if type(polygon) == "number" then
		polygon = common.instance(Polygon, polygon, ...)
	else
		polygon = polygon:clone()
	end

	if polygon:isConvex() then
		return common.instance(ConvexPolygonShape, polygon)
	end
	return common.instance(ConcavePolygonShape, polygon)
end

local function newCircleShape(...)
	return common.instance(CircleShape, ...)
end

local function newPointShape(...)
	return common.instance(PointShape, ...)
end

return {
	ConcavePolygonShape = ConcavePolygonShape,
	ConvexPolygonShape  = ConvexPolygonShape,
	CircleShape         = CircleShape,
	PointShape          = PointShape,
	newPolygonShape     = newPolygonShape,
	newCircleShape      = newCircleShape,
	newPointShape       = newPointShape,
}

