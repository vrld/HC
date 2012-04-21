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
local vector  = require(_PACKAGE .. '.vector-light')
local Polygon = require(_PACKAGE .. '.polygon')

local function math_absmin(a,b) return math_abs(a) < math_abs(b) and a or b end
local function test_axes(axes, shape_one, shape_two, sx,sy, min_overlap)
	for _,axis in ipairs(axes) do
		local l1,r1 = shape_one:projectOn(axis)
		local l2,r2 = shape_two:projectOn(axis)
		-- do the intervals overlap?
		if r1 < l2 or r2 < l1 then return false end

		-- get the smallest absolute overlap
		local overlap = math_absmin(l2-r1, r2-l1)
		if math_abs(overlap) < min_overlap then
			sx,sy = vector.mul(overlap, axis.x, axis.y)
			min_overlap = math_abs(overlap)
		end
	end
	return true, sx,sy, min_overlap
end

local function SAT(shape_one, axes_one, shape_two, axes_two)
	local collide, sx,sy, overlap = false, 0,0, math_huge
	collide, sx,sy, overlap = test_axes(axes_one, shape_one, shape_two, sx,sy, overlap)
	if not collide then return false end
	collide, sx,sy, overlap = test_axes(axes_two, shape_one, shape_two, sx,sy, overlap)
	return collide, sx,sy
end

local function outcircles_intersect(shape_one, shape_two)
	local x1,y1,r1 = shape_one:outcircle()
	local x2,y2,r2 = shape_two:outcircle()
	return vector.len2(x1-x2, y1-y2) <= (r1+r2)*(r1+r2)
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
	self._center = {x = cx, y = cy}
	self._radius = radius
end

local PointShape = {}
function PointShape:init(x,y)
	Shape.init(self, Shape.POINT)
	self._pos = {x = x, y = y}
end

--
-- collision functions
--
function ConvexPolygonShape:getAxes()
	local axes = {}
	local vert = self._polygon.vertices
	local p,q = vert[#vert], vert[#vert]
	for i = 1,#vert do
		p,q = q, vert[i]
		local x,y = vector.normalize(vector.perpendicular(p.x-q.x, p.y-q.y))
		axes[#axes+1] = {x = x, y = y}
	end
	return axes
end

function ConvexPolygonShape:projectOn(axis)
	local v = self._polygon.vertices
	local min,max = math_huge,-math_huge
	for i = 1,#v do
		local p = vector.dot(v[i].x,v[i].y, axis.x,axis.y) -- = v[i]:projectOn(axis) * axis
		min = math_min(p, min)
		max = math_max(p, max)
	end
	return min, max
end

function CircleShape:projectOn(axis)
	-- v:projectOn(a) * a = v * a (see ConvexPolygonShape)
	-- therefore: (c +- a*r) * a = c*a +- |a|^2 * r
	local center = vector.dot(self._center.x,self._center.y, axis.x,axis.y)
	local shift  = self._radius * vector.len2(axis.x, axis.y)
	return center - shift, center + shift
end

-- collision dispatching:
-- let circle shape or compund shape handle the collision
function ConvexPolygonShape:collidesWith(other)
	if other._type ~= Shape.POLYGON then
		local collide, sx,sy = other:collidesWith(self)
		return collide, sx and -sx, sy and -sy
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

	-- TODO: better way of doing this. report all the separations?
	local collide,dx,dy,count = false,0,0,0
	for _,s in ipairs(self._shapes) do
		local status, sx,sy = s:collidesWith(other)
		collide = collide or status
		if status then
			dx,dy = dx+sx, dy+sy
			count = count + 1
		end
	end
	return collide, dx/count, dy/count
end

function CircleShape:collidesWith(other)
	if other._type == Shape.CIRCLE then
		local px,py = self._center.x-other._center.x, self._center.y-other._center.y
		local d = vector.len2(px,py)
		local radii = self._radius + other._radius
		if d < radii*radii then
			-- if circles overlap, push it out upwards
			if d == 0 then return true, 0,radii end
			-- otherwise push out in best direction
			return true, vector.mul(radii - math_sqrt(d), vector.normalize(px,py))
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
	local vertices = other._polygon.vertices
	local closest, dist = vertices[1], vector.len2(self._center.x-vertices[1].x, self._center.y-vertices[1].y)
	for i = 2,#vertices do
		local d = vector.len2(self._center.x-vertices[i].x, self._center.y-vertices[i].y)
		if d < dist then
			closest, dist = vertices[i], d
		end
	end
	local axis = {x=0,y=1}
	if dist ~= 0 then
		axis.x,axis.y = vector.normalize(closest.x-self._center.x, closest.y-self._center.y)
	end
	return SAT(self, {axis}, other, other:getAxes())
end

function PointShape:collidesWith(other)
	if other._type == Shape.POINT then
		return (self._pos == other._pos), 0,0
	end
	return other:contains(self._pos.x, self._pos.y), 0,0
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
	return vector.len2(x-self._center.x, y-self._center.y) < self._radius * self._radius
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
-- than radius.
-- with r(s) = p + d*s = (x,y) + (dx,dy) * s defining the ray and
-- (x - cx)^2 + (y - cy)^2 = r^2, this problem is eqivalent to
-- solving [with c = (cx,cy)]:
--
--     d*d s^2 + 2 d*(p-c) s + (p-c)*(p-c)-r^2 = 0
function CircleShape:intersectsRay(x,y, dx,dy)
	local pcx,pcy = x-self._center.x, y-self._center.y

	local a = vector.len2(dx,dy)
	local b = 2 * vector.dot(dx,dy, pcx,pcy)
	local c = vector.len2(pcx,pcy) - self._radius * self._radius
	local discr = b*b - 4*a*c
	if discr < 0 then return false end

	discr = math_sqrt(discr)
	local s1,s2 = discr-b, -discr-b
	if s1 < 0 then -- first solution is off the ray
		return s2 >= 0, s2/(2*a)
	elseif s2 < 0 then -- second solution is off the ray
		return s1 >= 0, s1/(2*a)
	end
	-- both solutions on the ray
	return true, math_min(s1,s2)/(2*a)
end

-- point shape intersects ray if it lies on the ray
function PointShape:intersectsRay(x,y,dx,dy)
	local px,py = self._pos.x-x, self._pos.y-y
	local t = vector.dot(px,py, dx,dy) / vector.len2(dx,dy)
	return t >= 0, t
end

--
-- auxiliary
--
function ConvexPolygonShape:center()
	return self._polygon.centroid.x, self._polygon.centroid.y
end

function ConcavePolygonShape:center()
	return self._polygon.centroid.x, self._polygon.centroid.y
end

function CircleShape:center()
	return self._center.x, self._center.y
end

function PointShape:center()
	return self._pos.x, self._pos.y
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
	local cx,cy = self:center()
	local r = self._radius
	return cx-r,cy-r, cx+r,cy+r
end

function PointShape:bbox()
	local x,y = self:center()
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
	self._center.x = self._center.x + x
	self._center.y = self._center.y + y
end

function PointShape:move(x,y)
	self._pos.x = self._pos.x + x
	self._pos.y = self._pos.y + y
end


function ConcavePolygonShape:rotate(angle,cx,cy)
	Shape.rotate(self, angle)
	if not (cx and cy) then
		cx,cy = self:center()
	end
	self._polygon:rotate(angle,cx,cy)
	for _,p in ipairs(self._shapes) do
		p:rotate(angle, cx,cy)
	end
end

function ConvexPolygonShape:rotate(angle, cx,cy)
	Shape.rotate(self, angle)
	self._polygon:rotate(angle, cx, cy)
end

function CircleShape:rotate(angle, cx,cy)
	Shape.rotate(self, angle)
	if not (cx and cy) then return end
	self._center.x,self._center.y = vector.add(cx,cy, vector.rotate(angle, self._center.x-cx, self._center.y-cy))
end

function PointShape:rotate(angle, cx,cy)
	Shape.rotate(self, angle)
	if not (cx and cy) then return end
	self._pos.x,self._pos.y = vector.add(cx,cy, vector.rotate(angle, self._pos.x-cx, self._pos.y-cy))
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
	love.graphics.circle(mode or 'line', self:outcircle())
end

function PointShape:draw()
	love.graphics.point(self:center())
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

