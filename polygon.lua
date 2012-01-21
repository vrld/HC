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

local _PACKAGE = (...):match("^(.+)%.[^%.]+")
if not (common and common.class and common.instance) then
	class_commons = true
	require(_PACKAGE .. '.class')
end
local vector = require(_PACKAGE .. '.vector')

----------------------------
-- Private helper functions
--
-- create vertex list of coordinate pairs
local function toVertexList(vertices, x,y, ...)
	if not x or not y then return vertices end -- no more arguments

	vertices[#vertices + 1] = vector(x, y)     -- set vertex
	return toVertexList(vertices, ...)         -- recurse
end

-- returns true if three points lie on a line
local function areCollinear(p,q,r)
	return (q - p):cross(r - p) == 0
end
-- remove vertices that lie on a line
local function removeCollinear(vertices)
	local ret = {}
	for k=1,#vertices do
		local i = k > 1 and k - 1 or #vertices
		local l = k < #vertices and k + 1 or 1
		if not areCollinear(vertices[i], vertices[k], vertices[l]) then
			ret[#ret+1] = vertices[k]
		end
	end
	return ret
end

-- get index of rightmost vertex (for testing orientation)
local function getIndexOfleftmost(vertices)
	local idx = 1
	for i = 2,#vertices do
		if vertices[i].x < vertices[idx].x then
			idx = i
		end
	end
	return idx
end

-- returns true if three points make a counter clockwise turn
local function ccw(p, q, r)
	return (q - p):cross(r - p) >= 0
end

-- unpack vertex coordinates, i.e. {x=p, y=q}, ... -> p,q, ...
local function unpackHelper(v, ...)
	if not v then return end
	return v.x,v.y,unpackHelper(...)
end

-- test if a point lies inside of a triangle using cramers rule
local function pointInTriangle(q, p1,p2,p3)
	local v1,v2 = p2 - p1, p3 - p1
	local qp = q - p1
	local dv = v1:cross(v2)
	local l = qp:cross(v2)
	if l <= 0 then return false end
	local m = v1:cross(qp)
	if m <= 0 then return false end
	return (l+m)/dv < 1
end

-- returns starting indices of shared edge, i.e. if p and q share the
-- edge with indices p1,p2 of p and q1,q2 of q, the return value is p1,q1
local function getSharedEdge(p,q)
	local vertices = {}
	for i,v in ipairs(q) do vertices[ tostring(v) ] = i end
	for i,v in ipairs(p) do
		local w = (i == #p) and p[1] or p[i+1]
		if vertices[ tostring(v) ] and vertices[ tostring(w) ] then
			return i, vertices[ tostring(v) ]
		end
	end
end

-----------------
-- Polygon class
--
local Polygon = {}
function Polygon:init(...)
	local vertices = removeCollinear( toVertexList({}, ...) )
	assert(#vertices >= 3, "Need at least 3 non collinear points to build polygon (got "..#vertices..")")

	-- assert polygon is oriented counter clockwise
	local r = getIndexOfleftmost(vertices)
	local q = r > 1 and r - 1 or #vertices
	local s = r < #vertices and r + 1 or 1
	if not ccw(vertices[q], vertices[r], vertices[s]) then -- reverse order if polygon is not ccw
		local tmp = {}
		for i=#vertices,1,-1 do
			tmp[#tmp + 1] = vertices[i]
		end
		vertices = tmp
	end
	self.vertices = vertices
	-- make vertices immutable
	setmetatable(self.vertices, {__newindex = function() error("Thou shall not change a polygons vertices!") end})

	-- compute polygon area and centroid
	self.area = vertices[#vertices]:cross(vertices[1])
	for i = 1,#vertices-1 do
		self.area = self.area + vertices[i]:cross(vertices[i+1])
	end
	self.area = self.area / 2

	local p,q = vertices[#vertices], vertices[1]
	local det = p:cross(q)
	self.centroid = vector((p.x+q.x) * det, (p.y+q.y) * det)
	for i = 1,#vertices-1 do
		p,q = vertices[i], vertices[i+1]
		det = p:cross(q)
		self.centroid.x = self.centroid.x + (p.x+q.x) * det
		self.centroid.y = self.centroid.y + (p.y+q.y) * det
	end
	self.centroid = self.centroid / (6 * self.area)

	-- get outcircle
	self._radius = 0
	for i = 1,#vertices do
		self._radius = math.max(vertices[i]:dist(self.centroid), self._radius)
	end
end
local newPolygon

-- return vertices as x1,y1,x2,y2, ..., xn,yn
function Polygon:unpack()
	return unpackHelper( unpack(self.vertices) )
end

-- deep copy of the polygon
function Polygon:clone()
	return Polygon( self:unpack() )
end

-- get bounding box
function Polygon:getBBox()
	local ul = self.vertices[1]:clone()
	local lr = ul:clone()
	for i=2,#self.vertices do
		local p = self.vertices[i]
		if ul.x > p.x then ul.x = p.x end
		if ul.y > p.y then ul.y = p.y end

		if lr.x < p.x then lr.x = p.x end
		if lr.y < p.y then lr.y = p.y end
	end

	return ul.x,ul.y, lr.x,lr.y
end

-- a polygon is convex if all edges are oriented ccw
function Polygon:isConvex()
	local function isConvex()
		local v = self.vertices
		if #v == 3 then return true end

		if not ccw(v[#v], v[1], v[2]) then
			return false
		end
		for i = 2,#v-1 do
			if not ccw(v[i-1], v[i], v[i+1]) then
				return false
			end
		end
		if not ccw(v[#v-1], v[#v], v[1]) then
			return false
		end
		return true
	end

	-- replace function so that this will only be computed once
	local status = isConvex()
	self.isConvex = function() return status end
	return status
end

function Polygon:move(dx, dy)
	if not dy then
		dx, dy = dx:unpack()
	end
	for i,v in ipairs(self.vertices) do
		v.x = v.x + dx
		v.y = v.y + dy
	end
	self.centroid.x = self.centroid.x + dx
	self.centroid.y = self.centroid.y + dy
end

function Polygon:rotate(angle, center, cy)
	local center = center or self.centroid
	if cy then center = vector(center, cy) end
	for i,v in ipairs(self.vertices) do
		self.vertices[i] = (self.vertices[i] - center):rotate_inplace(angle) + center
	end
	self.centroid = (self.centroid - center):rotate_inplace(angle) + center
end

-- triangulation by the method of kong
function Polygon:triangulate()
	if #self.vertices == 3 then return {self:clone()} end
	local triangles = {} -- list of triangles to be returned
	local concave = {}   -- list of concave edges
	local adj = {}       -- vertex adjacencies
	local vertices = self.vertices

	-- retrieve adjacencies as the rest will be easier to implement
	for i,p in ipairs(vertices) do
		local l = (i == 1) and vertices[#vertices] or vertices[i-1]
		local r = (i == #vertices) and vertices[1] or vertices[i+1]
		adj[p] = {p = p, l = l, r = r} -- point, left and right neighbor
		-- test if vertex is a concave edge
		if not ccw(l,p,r) then concave[p] = p end
	end

	-- and ear is an edge of the polygon that contains no other
	-- vertex of the polygon
	local function isEar(p1,p2,p3)
		if not ccw(p1,p2,p3) then return false end
		for q,_ in pairs(concave) do
			if pointInTriangle(q, p1,p2,p3) then return false end
		end
		return true
	end

	-- main loop
	local nPoints, skipped = #vertices, 0
	local p = adj[ vertices[2] ]
	while nPoints > 3 do
		if not concave[p.p] and isEar(p.l, p.p, p.r) then
			-- polygon may be a 'collinear triangle', i.e.
			-- all three points are on a line. In that case
			-- the polygon constructor throws an error.
			if not areCollinear(p.l, p.p, p.r) then
				triangles[#triangles+1] = newPolygon(unpackHelper(p.l, p.p, p.r))
			end

			if concave[p.l] and ccw(adj[p.l].l, p.l, p.r) then
				concave[p.l] = nil
			end
			if concave[p.r] and ccw(p.l, p.r, adj[p.r].r) then
				concave[p.r] = nil
			end
			-- remove point from list
			adj[p.p] = nil
			adj[p.l].r = p.r
			adj[p.r].l = p.l
			nPoints = nPoints - 1
			skipped = 0
			p = adj[p.l]
		else
			p = adj[p.r]
			skipped = skipped + 1
			assert(skipped <= nPoints, "Cannot triangulate polygon (is the polygon intersecting itself?)")
		end
	end

	if not areCollinear(p.l, p.p, p.r) then
		triangles[#triangles+1] = newPolygon(unpackHelper(p.l, p.p, p.r))
	end

	return triangles
end

-- return merged polygon if possible or nil otherwise
function Polygon:mergedWith(other)
	local p,q = getSharedEdge(self.vertices, other.vertices)
	if not (p and q) then return nil end

	local ret = {}
	for i = 1, p do ret[#ret+1] = self.vertices[i] end
	for i = 2, #other.vertices-1 do
		local k = i + q - 1
		if k > #other.vertices then k = k - #other.vertices end
		ret[#ret+1] = other.vertices[k]
	end
	for i = p+1,#self.vertices do ret[#ret+1] = self.vertices[i] end
	return newPolygon( unpackHelper( unpack(ret) ) )
end

-- split polygon into convex polygons.
-- note that this won't be the optimal split in most cases, as
-- finding the optimal split is a really hard problem.
-- the method is to first triangulate and then greedily merge
-- the triangles.
function Polygon:splitConvex()
	-- edge case: polygon is a triangle or already convex
	if #self.vertices <= 3 or self:isConvex() then return {self:clone()} end

	local convex = self:triangulate()
	local i = 1
	repeat
		local p = convex[i]
		local k = i + 1
		while k <= #convex do
			local _, merged = pcall(function() return p:mergedWith(convex[k]) end)
			if merged and merged:isConvex() then
				convex[i] = merged
				p = convex[i]
				table.remove(convex, k)
			else
				k = k + 1
			end
		end
		i = i + 1
	until i >= #convex
	
	return convex
end

function Polygon:contains(x,y)
	-- test if an edge cuts the ray
	local function cut_ray(p,q)
		return ((p.y > y and q.y < y) or (p.y < y and q.y > y)) -- possible cut
			and (x - p.x < (y - p.y) * (q.x - p.x) / (q.y - p.y)) -- x < cut.x
	end

	-- test if the ray crosses boundary from interior to exterior.
	-- this is needed due to edge cases, when the ray passes through
	-- polygon corners
	local function cross_boundary(p,q)
		return (p.y == y and p.x > x and q.y < y)
			or (q.y == y and q.x > x and p.y < y)
	end

	local v = self.vertices
	local in_polygon = false
	for i = 1, #v do
		local p, q = v[i], v[(i % #v) + 1]
		if cut_ray(p,q) or cross_boundary(p,q) then
			in_polygon = not in_polygon
		end
	end
	return in_polygon
end

function Polygon:intersectsRay(x,y, dx,dy)
	local p = vector(x,y)
	local v = vector(dx,dy)
	local n = v:perpendicular()

	local vertices = self.vertices
	for i = 1, #vertices do
		local q1, q2 = vertices[i], vertices[ (i % #vertices) + 1 ]
		local w = q2 - q1
		local det = v:cross(w)

		if det ~= 0 then
			-- there is an intersection point. check if it lies on both
			-- the ray and the segment.
			local r = q2 - p
			local l = r:cross(w)
			local m = v:cross(r)
			if l >= 0 and m >= 0 and m <= det then return true, l end
		else
			-- lines parralel or incident. get distance of line to
			-- anchor point. if they are incident, check if an endpoint
			-- lies on the ray
			local dist = (q1 - p) * n
			if dist == 0 then
				local l,m = v * (q1 - p), v * (q2 - p)
				if l >= 0 and l >= m then return true, l end
				if m >= 0 then return true, m end
			end
		end
	end
	return false
end

Polygon = common.class('Polygon', Polygon)
newPolygon = function(...) return common.instance(Polygon, ...) end
return Polygon
