package = "lua-resty-logger-socket"
version = "master-0"
source = {
   url = "git://github.com/api7/lua-resty-logger-socket",
   branch = "master",
}

description = {
   summary = "Raw-socket-based Logger Library for Nginx/Lua",
   homepage = "https://github.com/api7/lua-resty-logger-socket",
   license = "BSD license",
   maintainer = "Yuansheng Wang <membphis@gmail.com>"
}

build = {
   type = "builtin",
   modules = {
      ["resty.logger.socket"] = "lib/resty/logger/socket.lua",
   }
}
