package = "HC"
version = "0.1-1"
source = {
  url = "git://github.com/vrld/HC.git"
}
description = {
  summary="General purpose 2D collision detection in pure Lua",
   homepage = "https://hc.readthedocs.io",
   license = "MIT",
}
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
