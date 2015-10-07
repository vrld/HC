package = "HardonCollider"
version = "1.0-1"
source = {
  url = "git://github.com/vrld/HardonCollider.git"
}
description = {}
dependencies = {
  "lua = 5.1"
}
build = {
  type = "builtin",
  modules = {
    ["hardoncollider"] = "init.lua",
    ["hardoncollider.class"] = "class.lua",
    ["hardoncollider.gjk"] = "gjk.lua",
    ["hardoncollider.polygon"] = "polygon.lua",
    ["hardoncollider.shapes"] = "shapes.lua",
    ["hardoncollider.spatialhash"] = "spatialhash.lua",
    ["hardoncollider.vector-light"] = "vector-light.lua",
  }
}
