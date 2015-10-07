# HC

## Module HC [The main module.]

	Collider = require "HC"

The main module.

HC will automatically detect - but not resolve - collisions. It
uses an efficient search data structure (a [spatial
hash](#HC.spatialhash)) to quickly find colliding shapes.

A spatial hash is basically a grid that is laid over the whole scene in which a
shape can occupy several cells. To find shapes that may be colliding, you
simply need to look which shapes occupy the same cell. You can specify the cell
size in the [`new()`](#HC) function.

To get a less boring explanation on how to use this, see the
[tutorial](tutorial.html).


### function new(cell_size, callback_collide, callback_stop) [Creates a new collider instance.]

Initializes the library. Call this in `love.load()`. All parameters may be
omitted.

**Note:** The cell size does not determine the granularity of the collision
detection, but is an *optimization parameter*. Values that are too small or too
big will have a negative impact on the detection speed. The meaning of too
small and too big depends on the size of the shapes in the collision detection.

#### Parameters:

=number cell_size (100)=
	Cell size for internal search structure.
=function callback_collide (empty function)=
	Called when two shapes are colliding.
=function callback_stop (empty function)=
	Called when two shapes were colliding in the last frame, but are not in this frame.

#### Example:

	Collider = require 'HC'
	function love.load()
		HC = Collider.new(150)
		-- or: HC = Collider(150)
	end

### function HC:clear() [Clears collision data.]

Remove all shapes from the collider instance.

#### Example:

	function game:leave()
		HC:clear()
	end

### function HC:setCallbacks(collide, stop) [Set callback functions.]

Sets the collision callbacks.

If nil is passed for either argument, the corresponding callback will not be
changed.

The callbacks must have the following function prototype:

	function callback(dt, shape_one, shape_two, dx, dy)

`shape_one` and `shape_two` are the colliding shapes and `dx` and `dy` define
the separating vector, i.e. the direction and magnitude `shape_one` has to be
moved so that the collision will be resolved. Note that if one of the shapes is
a point shape, the translation vector will be invalid.

#### Parameters:

=function collide=
	Called when two shapes are colliding.
=function stop=
	Called when two shapes were colliding in the last frame, but are not in this frame.

#### Example:

	Collider = require 'HC'
	
	function collide(dt, shape_one, shape_two, dx, dy)
		print('colliding:', shape_one, shape_two)
		print('mtv:', dx, dy)
		-- move both shape_one and shape_two to resolve the collision
		shape_one:move(dx/2, dy/2)
		shape_two:move(-dx/2, -dy/2)
	end
	
	function colliding_two(dt, shape_one, shape_two, dx, dy)
		print('colliding:', shape_one, shape_two)
		-- move only shape_one to resolve the collision
		shape_one:move(dx, dy)
	end
	
	-- ignore the translation vector
	
	function stop(dt, shape_one, shape_two)
		print('collision resolved')
	end
	
	function love.load()
		HC = Collider()
		-- set initial callbacks
		HC:setCallbacks(collide)
		-- add stop callback
		HC:setCallbacks(nil, stop)
		-- change collide callback
		HC:setCallbacks(collide_two)
	end

### function HC:update(dt) [Update collision detection.]

Checks for collisions and call callbacks. Use this in `love.update(dt)`.

**Note:** `dt` has no effect on the collision detection itself, but will be
passed to the callback functions.

#### Parameters:

=number dt=
	The time since the last update.

#### Example:

	function love.update(dt)
		HC:update(dt)
	end

### function HC:addPolygon(x1,y1, ..., xn,yn) [Add polygon to the scene.]

Add a polygon to the collision detection system. Any non-intersection polygon
will work, even convex polygons.

**Note:** If three consecutive points lie on a line, the middle point will be
discarded. This means you cannot construct polygon shapes out of lines.

#### Parameters:

=numbers x1,y1, ..., xn,yn=
	The corners of the polygon. At least three corners (that do not lie on a line) are needed.

#### Returns:

=Shape=
	The polygon shape added to the scene.

#### Example:

	shape = HC:addPolygon(10,10, 40,50, 70,10, 40,30)

### function HC:addRectangle(x, y, w, h) [Add rectangle to the scene.]

Add a rectangle shape to the collision detection system.

**Note:** Shape transformations, e.g.
[`shape:moveTo()`](#HC.shapesshape:moveTo) and
[`shape:rotate()`](#HC.shapesshape:rotate), will be with respect to the
rectangle center, *not* to the upper left corner.

#### Parameters:

=numbers x, y=
	The upper left corner of the rectangle.
=numbers w, h=
	The width and height of the rectangle.

#### Returns:

=Shape=
	The rectangle added to the scene.

#### Example:

	rect = HC:addRectangle(100,120, 200,40)

### function HC:addCircle(cx, cy, radius) [Add circle to the scene.]

Add a circle shape to the collision detection system.

#### Parameters:

=numbers cx, cy=
	The circle center.
=number radius=
	The circle radius.

#### Returns:

=Shape=
	The circle added to the scene.

#### Example:

	circle = HC:addCircle(400,300, 100)

### function HC:addPoint(x, y) [Add point to the scene.]

Add a point shape to the collision detection system.

Point shapes are most useful for bullets and such, because detecting collisions
between a point and any other shape is a little faster than detecting collision
between two non-point shapes. In case of a collision, the callback will not
receive a valid minimum translation vector.

#### Parameters:

=numbers x, y=
	The point's position.

#### Returns:

=Shape=
	The point added to the scene.

#### Example:

	bullets[#bulltes+1] = HC:addPoint(player.pos.x,player.pos.y)

### function HC:addShape(shape) [Add custom shape to the scene.]

Add a custom shape to the collision detection system.

The shape must implement two functions for this to work:

	function shape:bbox()
		return corners-of-axis-aligned-bounding-box
	end

and

	function shape:collidesWith(other)
		local colliding = ...
		local sx,sy = separating-vector(self, other)
		return colliding, sx,sy
	end

The shape will be augmented with the function
[`shape:neighbors()`](#HC.shapesshape:neighbors).

#### Parameters:

=mixed shape=
	Custom shape.

#### Returns:

=mixed=
	The shape.

#### Example:

	AABB = {x = ..., y = ..., width = ..., height = ...}
	
	function AABB:bbox()
		return self.x, self.y, self.x+self.width, self.y+self.height
	end
	
	function AABB:collidesWith(other)
		return magic
	end
	
	AABB = HC:addShape(AABB)

### function HC:remove(shape, ...) [Remove shapes from the scene.]

Remove a shape from the collision detection system. Note that if you remove a
shape in the `collide()` callback, it will still be an argument to the `stop()`
callback in the next frame.

#### Parameters:

=Shape(s) shape, ...=
	The shape(s) to be removed.

#### Example:

	HC:remove(circle)
	HC:remove(enemy1, enemy2)

### function HC:addToGroup(group, shape, ...) [Group shapes that should not collide.]

Add shapes to a group. Shapes in the same group will not emit collision
callbacks when colliding with each other.

#### Parameters:

=string group=
	The name of the group.
=Shapes shape, ...=
	The shapes to be added or removed to the group.

#### Example:

	HC:addToGroup("platforms", platform1, platform2, platform3)
	HC:removeFromGroup("platforms", platform1)

### function HC:removeFromGroup(group, shape, ...) [Remove shapes from group.]

Remove shapes from a group.

#### Parameters:

=string group=
	The name of the group.
=Shapes shape, ...=
	The shapes to be added or removed to the group.

#### Example:

	HC:addToGroup("platforms", platform1, platform2, platform3)
	HC:removeFromGroup("platforms", platform1)

### function HC:setPassive(shape, ...) [Flag shapes as passive.]

Sets shape to be passive. Passive shapes will be subject to collision
detection, but will not actively search for collision candidates. This means
that if two passive shapes collide, no collision callback will be invoked (in
fact, the collision won't even be detected).

This enables you to significantly speed up the collision detection. Typical
candidates for passive shapes are those which are numerous, but don't act in
themselves, e.g. the level geometry.

**Note**: Added shapes are active by default.

#### Parameters:

=Shapes shape, ...=
	The shapes to be flagged as passive.

#### Example:

	HC:setPassive(ground, bridge, spikes)

### function HC:setActive(shape, ...) [Flag shapes as active.]

Flags a shape active.

**Note**: Added shapes are active by default.

#### Parameters:

=Shapes shape, ...=
	The shapes to be flagged as active.

#### Example:

	HC:setActive(collapsing_bridge)

### function HC:activeShapes() [Iterator over all active shapes.]

Iterator over all active shapes. Mostly for internal use.

#### Returns:

=iterator=
	Iterator over all active shapes.

#### Example:

	-- rotate all active shapes
	for shape in HC:activeShapes() do
		shape:rotate(dt)
	end

### function HC:setGhost(shape, ...) [Stop shapes from colliding.]

Makes a shape permeable: Ghost shapes will not collide with any other shape.

#### Parameters:

=Shapes shape, ...=
	The shapes to become permeable.

#### Example:

	-- make player invincible for 5 seconds
	HC:setGhost(player)
	Timer.add(5, function() HC:setSolid(player) end)

### function HC:setSolid(shape, ...) [Make shapes collidable again.]

Makes a permeable shape solid again.

#### Parameters:

=Shapes shape, ...=
	The shapes to become solid.

#### Example:

	-- make player invincible for 5 seconds
	HC:setGhost(player)
	Timer.add(5, function() HC:setSolid(player) end)

### function HC:shapesAt(x,y) [Get list of shapes covering a point.]

Retrieve a list of shapes covering the point `(x,y)`, i.e. all shapes that
contain `(x,y)`. This includes active, passive, solid and ghost shapes.

#### Parameters:

=numbers x, y=
	Coordinates of the point to query.

#### Returns:

=table=
	List of shapes containing point `(x,y)`.

#### Example:

	-- select the units under the mouse cursor
	function love.mousereleased(x,y,btn)
		for _, shape in ipairs(HC:shapesAt(x,y)) do
			shape.object:select()
		end
	end

### function HC:shapesInRange(x1,y1, x2,y2) [Get list of shapes covering a rectangle.]

Returns all shapes contained in the rectangle `(x1,y1)-(x2,y2)`.
Useful for RTS-style unit selection to select shapes to draw (see example).

#### Parameters:

=numbers x1, y1=
	Upper left corner of the bounding box.
=numbers x2, y2=
	Lower right corner of the bounding box.

#### Returns:

=Set=
	A set (i.e. table of `t[shape] = shape`) of shapes.

#### Example:

	-- draw only visible shapes
	local width = love.graphics.getWidth()
	local height = love.graphics.getHeight()
	for shape in pairs(HC:shapesInRange(0,0, width,height) do
		shape.object:draw()
	end

## Module HC.shapes [Shape classes.]

	shapes = require "HC.shapes"

Shape classes with collision detection methods.

This module defines methods to move, rotate and draw shapes created with
`HC:add*`.

As each shape is at it's core a Lua table, you can attach values and add
functions to it. Be careful though not to use keys that name a function or
start with an underscore, e.g. `move` or `_groups`, since these are used
internally. Everything else is fine.

If you don't want to use the full blown module, you can still use these classes
to test for colliding shapes. Doing so might be useful for a highly customized
collision detection loop exploiting some prior knowledge of the scene.


### function newPolygonShape(x1,y1, ..., xn,yn) [Create new polygon shape.]

Construct a shape using a non-self-intersecting ploygon.

The corresponding classes are available as `shapes.ConvexPolygonShape` and
`shapes.ConcavePolygonShape`.

You can either specify the coordinates as with
[`HC:addPolygon()`](#HC:addPolygon) or use an instance
of the Polygon class.

#### Parameters:

=numbers x1,y1, ..., xn,yn=
	The corners of the polygon. At least three corners (that do not lie on a line) are needed.
=Polygon polygon=
	Construct the shape from this polygon.

#### Returns:

=Shape=
	The constructed shape.

#### Example:

	shape = shapes.newPolygonShape(100,100, 200,200, 300,100)
	shape2 = shapes.newPolygonShape(shape)

### function newCircleShape(cx,cy, radius) [Create new circle shape.]

Construct a circular shape.

The corresponding class is available as `shapes.CircleShape`.

#### Parameters:

=numbers cx, cy=
	The circle center.
=number radius=
	The circle radius.

#### Returns:

=Shape=
	The constructed circle shape.

#### Example:

	shape = shapes.newCircleShape(400,300, 100)

### function newPointShape(x,y) [Create new point shape.]

Construct a point shape.

The corresponding class is available as `shapes.PointShape`.

#### Parameters:

=numbers x, y=
	The point's position.

#### Returns:

=Shape=
	The constructed point shape.

#### Example:

	shape = shapes.newPointShape(400,300)

### function shape:contains(x, y) [Test if shape contains a point.]

Test if the shape contains a given point.

#### Parameters:

=numbers x, y=
	Point to test.

#### Returns:

=boolean=
	`true` if `x,y` lies in the interior of the shape.

#### Example:

	if unit.shape:contains(love.mouse.getPosition) then
		unit:setHovered(true)
	end

### function shape:intersectsRay(x, y, dx, dy) [Test if shape intersects a ray.]

Test if the shape intersects a ray.

#### Parameters:

=numbers x, y=
	Starting point of the ray.
=numbers dx, dy=
	Direction of the ray.

#### Returns:

=boolean=
	`true` if the given ray intersects the shape.
=number=
	Ray parameter of the intersection, if `shape` intersects the ray.

#### Example:

	local intersecting, t = player:intersectsRay(x,y, dx,dy)
	if intersecting then
		-- find point of intersection
		local vx,vy = vector.add(x, y, vector.mul(t, dx, dy))
		player:addMark(vx,vy)
	end

### function shape:move(x, y) [Move shape by some amount.]

Move the shape.

#### Parameters:

=numbers x, y=
	The direction to move the shape in.

#### Example:

	circle:move(10,15) -- move the circle 10 units right and 15 units down

### function shape:moveTo(x, y) [Move shape to a position.]

Set the shape's position.

**Important:** This function moves the shape's center to `(x,y)`. It is
equivalent to:

	local cx,cy = shape:center()
	shape:move(x-cx, y-cy)

#### Parameters:

=numbers x, y=
	Point to place the shape.

#### Example:

	circle:moveTo(400,300) -- move circle to screen center

### function shape:scale(s) [Scale shape.]

Scale the shape relative to it's center.

#### Parameters:

=number s=
	Scale factor. Must be > 0.

#### Example:

	circle:scale(2) -- double the circle's size

### function shape:rotate(angle, cx,cy) [Rotate shape by some amount.]

Rotate the shape. A rotation center can be specified. If no center is given,
the shape's center is used.

#### Parameters:

=number angle=
	Amount to rotate the shape (in radians).
=numbers cx, cy (optional)=
	Rotation center. Defaults to the shape's center if omitted.

#### Example:

	rectangle:rotate(math.pi/4)

### function shape:setRotation(angle, cx,cy) [Set shape rotation.]

Set the rotation of a shape. A rotation center can be specified. If no center
is given, the shape's center is used.

Equivalent to:

	shape:rotate(angle - shape.rotation, cx,cy)

#### Parameters:

=number angle=
	Rotation angle (in radians).
=numbers cx, cy (optional)=
	Rotation center. Defaults to the shape's center if omitted.

#### Example:

	rectangle:setRotation(math.pi, 100,100)

### function shape:center() [Get the shape's center.]

Get the shape's center.

If the shape is a CircleShape, returns the circle center. In case of a point
shape, returns the position. Else returns the polygon's centroid.

#### Returns:

=numbers x, y=
	The center of the shape.

#### Example:

	print("Circle at:", circle:center())

### function shape:rotation() [Get the shape's rotation.]

Get the shape's rotation angle in radians.

#### Returns:

=number angle=
	The rotation angle in radians.

#### Example:

	print("Box rotation:", box:rotation())

### function shape:outcircle() [Get circle containing the shape.]

Get circle that fully contains the shape.

#### Returns:

=numbers x, y=
	Center of the circle.
=number r=
	Radius of the circle.

#### Example:

	if player:hasShield() then
		-- draw shield
		love.graphics.circle('line', player:outcircle())
	end

### function shape:bbox() [Get axis aligned bounding box.]

Get axis aligned bounding box.

#### Returns:

=numbers x1, y1=
	Upper left edge of the bounding box.
=number x2, y2=
	Lower right edge of the bounding box.

#### Example:

	-- draw bounding box
	local x1,y1, x2,y2 = shape:bbox()
	love.graphics.rectangle('line', x1,y1, x2-x1,y2-y1)

### function shape:draw(mode) [Draw the shape.]

Draw the shape either filled or as outline.

#### Parameters:

=DrawMode mode=
	How to draw the shape. Either 'line' or 'fill'.

#### Example:

	circle:draw('fill')

### function shape:support(dx,dy) [Get furthest vertex of the shape wrt. a direction.]

Get furthest vertex of the shape with respect to the direction `dx, dy`.

Used in the collision detection algorithm, but may be useful for other things -
e.g. lighting - too.

#### Parameters:

=numbers dx, dy=
	Search direction.

#### Returns:

=numbers=
	The furthest vertex in direction `dx, dy`.

#### Example:

	-- get vertices that produce a shadow volume
	local x1,y1 = circle:support(lx, ly)
	local x2,y2 = circle:support(-lx, -ly)

### function shape:collidesWith(other) [Test for collision.]

Test if two shapes collide.

#### Parameters:

=Shape other=
	Test for collision with this shape.

#### Returns:

=boolean collide=
	`true` if the two shapes collide, `false` otherwise.
=numbers dx, dy=
	The separating vector, or nil if the two shapes do not collide.

#### Example:

	if circle:collidesWith(rectangle) then
		print("collision detected!")
	end

### function shape:neighbors() [Iterator over neighboring shapes.]

**Only available in shapes created with main module (i.e.
[`HC:addRectangle()`](#HC:addRectangle), ...).**

Iterator over neighboring shapes.

#### Returns:

=iterator=
	Iterator over neighboring shapes.

#### Example:

	-- check for collisions with neighboring shapes
	for other in shape:neighbors() do
		if shape:collidesWith(other) then
			print("collision detected!")
		end
	end

## Module HC.polygon [Polygon class.]

	polygon = require "HC.polygon"

Definition of a Polygon class and implementation of some handy algorithms.

On it's own, this class does not offer any collision detection. If you want
that, use a [`PolygonShape`](#HC.shapesnewPolygonShape) instead.

### class Polygon(x1,y1, ..., xn,yn) [The polygon class]

**Syntax depends on used class system. Shown syntax works for bundled
[hump.class](http://vrld.github.com/hump/#hump.class) and
[slither](https://bitbucket.org/bartbes/slither).**

Construct a polygon.

At least three points that are not collinear (i.e. lying on a straight line)
are needed to construct the polygon. If there are collinear points, these
points will be removed so that the overall shape of the polygon is not changed.

#### Parameters:

=numbers x1,y1, ..., xn,yn=
	The corners of the polygon. At least three corners are needed.

#### Returns:

=Polygon=
	The polygon object.

#### Example:

	Polygon = require 'HC.polygon'
	poly = Polygon(10,10, 40,50, 70,10, 40,30)

### function polygon:unpack() [Get coordinates.]

Get the polygon's vertices. Useful for drawing with `love.graphics.polygon()`.

#### Returns:

=numbers x1,y1, ..., xn,yn=
	The vertices of the polygon.

#### Example:

	love.graphics.draw('line', poly:unpack())

### function polygon:clone() [Copy polygon.]

Get a copy of the polygon.

Since Lua uses references when simply assigning an existing polygon to a
variable, unexpected things can happen when operating on the variable. Consider
this code:

	p1 = Polygon(10,10, 40,50, 70,10, 40,30)
	p2 = p1
	p3 = p1:clone()
	p2:rotate(math.pi) -- p1 will be rotated, too!
	p3:rotate(-math.pi) -- only p3 will be rotated

#### Returns:

=Polygon polygon=
	A copy of the polygon.

#### Example:

	copy = poly:clone()
	copy:move(10,20)

### function polygon:bbox() [Get axis aligned bounding box.]

Get axis aligned bounding box.

#### Returns:

=numbers x1, y1=
	Upper left corner of the bounding box.
=numbers x2, y2=
	Lower right corner of the bounding box.

#### Example:

	x1,y1,x2,y2 = poly:bbox()
	-- draw bounding box
	love.graphics.rectangle('line', x1,y2, x2-x1, y2-y1)

### function polygon:isConvex() [Test if polygon is convex.]

Test if a polygon is convex, i.e. a line line between any two points inside the
polygon will lie in the interior of the polygon.

#### Returns:

=boolean convex=
	true if the polygon is convex, false otherwise.

#### Example:

	-- split into convex sub polygons
	if not poly:isConvex() then
		list = poly:splitConvex()
	else
		list = {poly:clone()}
	end

### function polygon:move(x,y) [Move polygon by some amount.]

Move a polygon in a direction..

#### Parameters:

=numbers x, y=
	Coordinates of the direction to move.

#### Example:

	poly:move(10,-5) -- move 10 units right and 5 units up

### function polygon:rotate(angle, cx, cy) [Rotate polygon by some amount.]

Rotate the polygon. You can define a rotation center. If it is omitted, the
polygon will be rotated around it's centroid.


#### Parameters:

=number angle=
	The angle to rotate in radians.
=numbers cx, cy (optional)=
	The rotation center.

#### Example:

	p1:rotate(math.pi/2)          -- rotate p1 by 90° around it's center
	p2:rotate(math.pi/4, 100,100) -- rotate p2 by 45° around the point 100,100

### function polygon:triangulate() [Triangulate polygon.]

Split the polygon into triangles.

#### Returns:

=table of Polygons=
	Triangles that the polygon is composed of.

#### Example:

	triangles = poly:triangulate()
	for i,triangle in ipairs(triangles) do 
		triangles.move(math.random(5,10), math.random(5,10))
	end	

### function polygon:splitConvex() [Decompose polygon in convex polygons.]

Split the polygon into convex sub polygons.

#### Returns:

=table of Polygons=
	Convex polygons that form the original polygon.

#### Example:

	convex = concave_polygon:splitConvex()
	function love.draw()
		for i,poly in ipairs(convex) do
			love.graphics.polygon('fill', poly:unpack())
		end
	end

### function polygon:mergedWith(other) [Merge with other polygon.]

Create a merged polygon of two polygons if, and only if the two polygons share
one complete edge. If the polygons share more than one edge, the result may be
erroneous.

This function does not change either polygon, but rather create a new one.

#### Parameters:

=Polygon other=
	The polygon to merge with.

#### Returns:

=Polygon merged=
	The merged polygon, or nil if the two polygons don't share an edge.

#### Example:

	merged = p1:mergedWith(p2)

### function polygon:contains(x, y) [Test if polygon contains a point.]

Test if the polygon contains a given point.

#### Parameters:

=numbers x, y=
	Point to test.

#### Returns:

=boolean=
	`true` if `x,y` lies in the interior of the polygon.

#### Example:

	if button:contains(love.mouse.getPosition()) then
		button:setHovered(true)
	end

### function polygon:intersectsRay(x, y, dx, dy) [Test if polygon intersects a ray.]

Test if the polygon intersects a ray.

#### Parameters:

=numbers x, y=
	Starting point of the ray.
=numbers dx, dy=
	Direction of the ray.

#### Returns:

=boolean=
	`true` if the ray intersects the shape.
=number=
	Ray parameter of the intersection or `nil` if there was no intersection.

#### Example:

	if poly:intersectsRay(400,300, dx,dy) then
		love.graphics.setLine(2) -- highlight polygon
	end

## Module HC.spatialhash [Spatial hash.]

	spatialhash = require "HC.spatialhash"

A spatial hash implementation that supports scenes of arbitrary size. The hash
is sparse, which means that cells will only be created when needed.

### class Spatialhash(cellsize) [Spatial hash class.]

**Syntax depends on used class system. Shown syntax works for bundled
[hump.class](http://vrld.github.com/hump/#hump.class) and
[slither](https://bitbucket.org/bartbes/slither).**

Create a new spatial hash with a given cell size.

Choosing a good cell size depends on your application. To get a decent speedup,
the average cell should not contain too many objects, nor should a single
object occupy too many cells. A good rule of thumb is to choose the cell size
so that the average object will occupy only one cell.

#### Parameters:

=number cellsize (100)=
	Width and height of a cell.

#### Returns:

=Spatialhash=
	A fresh object instance.

#### Example:

	Spatialhash = require 'HC.spatialhash'
	hash = Spatialhash(150)

### function hash:cellCoords(x,y) [Get cell coordinates of a point.]

Get coordinates of a given value, i.e. the cell index in which a given point
would be placed.

#### Parameters:

=numbers x, y=
	The position to query.

#### Returns:

=numbers=
	Coordinates of the cell which would contain `x,y`.

#### Example:

	local mx,my = love.mouse.getPosition()
	cx, cy = hash:cellCoords(mx, my)

### function hash:cell(i,k) [Get cell of a given index.]

Get the cell with given coordinates.

A cell is a table which's keys and value are the objects stored in the cell, i.e.:

	cell = {
		[obj1] = obj1,
		[obj2] = obj2,
		...
	}

You can iterate over the objects in a cell using `pairs()`:

	for object in pairs(cell) do stuff(object) end

#### Parameters:

=numbers i, k=
	The cell index.

#### Returns:

=table=
	Set of objects contained in the cell.

#### Example:

	local mx,my = love.mouse.getPosition()
	cx, cy = hash:cellCoords(mx, my)
	cell = hash:cell(cx, cy)

### function hash:cellAt(x,y) [Get cell for a given point.]

Get the cell that contains point x,y.

Same as `hash:cell(hash:cellCoords(x,y))`


#### Parameters:

=numbers x, y=
	The position to query.

#### Returns:

=table=
	Set of objects contained in the cell.

#### Example:

	local mx,my = love.mouse.getPosition()
	cell = hash:cellAt(mx, my)

### function hash:insert(obj, x1,y1, x2,y2) [Insert object.]

Insert an object into the hash using a given bounding box.

#### Parameters:

=mixed obj=
	Object to place in the hash. It can be of any type except `nil`.
=numbers x1,y1=
	Upper left corner of the bounding box.
=numbers x2,y2=
	Lower right corner of the bounding box.

#### Example:

	hash:insert(shape, shape:bbox())

### function hash:remove(obj, x1,y1, x2,y2) [Remove object.]

Remove an object from the hash using a bounding box.

If no bounding box is given, search the whole hash to delete the object.


#### Parameters:

=mixed obj=
	The object to delete
=numbers x1,y1 (optional)=
	Upper left corner of the bounding box.
=numbers x2,y2 (optional)=
	Lower right corner of the bounding box.

#### Example:

	hash:remove(shape, shape:bbox())
	hash:remove(object_with_unknown_position)

### function hash:update(obj, x1,y1, x2,y2, x3,y3, x4,y4) [Update object's position.]

Update an objects position given the old bounding box and the new bounding box.

#### Parameters:

=mixed obj=
	The object to be updated.
=numbers x1,y1=
	Upper left corner of the bounding box before the object was moved.
=numbers x2,y2=
	Lower right corner of the bounding box before the object was moved.
=numbers x3,y3=
	Upper left corner of the bounding box after the object was moved.
=numbers x4,y4=
	Lower right corner of the bounding box after the object was moved.

#### Example:

	hash:update(shape, -100,-30, 0,60, -100,-70, 0,20)

### function hash:inRange(x1,y1, x2,y2) [Query objects in a rectangle.]

Query objects in the rectangle `(x1,y1) - (x2,y2)`.


#### Parameters:

=numbers x1, y1=
	Upper left corner of the object's bounding box.
=numbers x2, y2=
	Lower right corner of the object's bounding box.

#### Returns:

=Set=
	A set (i.e. table of `t[obj] = obj`) of objects.

#### Example:

	local objects = hash:inRange(0,0, 800,600)
	for obj in pairs(objects) do
		obj:draw()
	end

### function hash:rangeIter(x1,y1, x2,y2) [Iterator over objects in a rectangle.]

Iterator to objects in the rectangle `(x1,y1) - (x2,y2)`.

Alias to `pairs(hash:inRange(x1,y1, x2,y2))`.

#### Parameters:

=numbers x1, y1=
	Upper left corner of the object's bounding box.
=numbers x2, y2=
	Lower right corner of the object's bounding box.

#### Returns:

=iterator=
	An iterator to objects in the range.

#### Example:

	for obj in hash:rangeIter(0,0, 800,600) do
		obj:draw()
	end

### function hash:draw(draw_mode, show_empty, print_key) [Draw the grid.]

Draw hash cells on the screen, mostly for debug purposes

#### Parameters:

=string draw_mode=
	Either 'fill' or 'line'. See the LÖVE wiki.
=boolean show_empty (true)=
	Wether to draw empty cells.
=boolean print_key (false)=
	Wether to print cell coordinates.

#### Example:

	love.graphics.setColor(160,140,100,100)
	hash:draw('line', true, true)
	hash:draw('fill', false)

## HC.vector-light [Lightweight vector operations.]

	require "HC.vector-light"

See [hump.vector-light](http://vrld.github.com/hump/#hump.vector-light).

## HC.class [Simple class implementation]

	require "HC.class"

See [hump.class](http://vrld.github.com/hump/#hump.class).

**Note:** HC uses [class
commons](https://github.com/bartbes/Class-Commons) to be even more awesome.
This module will only be used if you don't supply another CC implementation.
