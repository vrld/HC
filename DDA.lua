function traverse(cellSizeX,cellSizeY,x1,y1,x2,y2,onTraverse)
  --compute the cooridinates of the cell the first point is in
  local gridXPos,gridYPos = math.floor( x1 / cellSizeX ), math.floor ( y1 / cellSizeY ) 
  --traverse the first cell
  onTraverse(gridXPos,gridYPos)
  --direction vector from p1 to p2
  local dirX,dirY = x2 - x1,y2 - y1;
  --sqared magnitide of direction vector
  local distSqr = dirX^2 + dirY^2;
  if(distSqr < 0.00000001) then return end
  --normalize the direction vector
  dirX,dirY = dirX/math.sqrt(distSqr),dirY/math.sqrt(distSqr)
  --compute increment for each component
  local deltaX,deltaY = cellSizeX / math.abs(dirX),cellSizeY / math.abs(dirY)
  --compute maxX and maxY
  local maxX = gridXPos * cellSizeX - x1;
  local maxY = gridYPos * cellSizeY - y1;
  if dirX >= 0 then maxX = maxX + cellSizeX end
  if dirY >= 0 then maxY = maxY + cellSizeY end
  maxX = maxX/dirX
  maxY = maxY/dirY
  --compute sign of increment for each component
  local signX 
  if dirX < 0 then signX = -1 else signX = 1 end
  local signY 
  if dirY < 0 then signY = -1 else signY = 1 end
  --compute the cooridinates for the cell where p2 is
  local gridGoalX = math.floor(x2 / cellSizeX)
  local gridGoalY = math.floor(y2 / cellSizeY)
  --direction vector from center of current cell to goal cell
  local currentDirX = gridGoalX - gridXPos
  local currentDirY = gridGoalY - gridYPos
  --while there is still distance between the current cell and the goal cell,
  --traverse the next cell
  while ( currentDirX * signX > 0 or currentDirY * signY > 0 ) do
    if maxX<maxY then
      maxX = maxX + deltaX
      gridXPos = gridXPos + signX
      currentDirX = gridGoalX - gridXPos
    else
      maxY = maxY + deltaY
      gridYPos = gridYPos + signY
      currentDirY = gridGoalY - gridYPos
    end
    onTraverse(gridXPos,gridYPos) 
  end
end