
js = require "js"

package.path = "./?.lua;ludum-dare-30/?.lua;lovekit/?.lua"

export setfenv = (fn, env) ->
  i = 1
  while true
    name = debug.getupvalue fn, i
    if name == "_ENV" then
      debug.upvaluejoin(
        fn
        i
        -> env
        1
      )
      break
    elseif not name
      break
    i += 1
  fn

export getfenv = (fn) ->
  i = 1

  while true
    name, val = debug.getupvalue fn, i
    if name == "_ENV"
      return val
    elseif not name
      break

    i += 1

failfast_module = (name, t) ->
  full_name = if name
    "love.#{name}"
  else
    "love"

  setmetatable t, {
    __index: (name) =>
      error "Missing field #{full_name}: #{name}: #{debug.traceback!}"
  }

local app_config

class ImageFont
  failfast_module @__name, @__base
  new: (@path, characters) =>

class Image
  failfast_module @__name, @__base
  new: (@path) =>

  setFilter: (@filter_min, @filter_mag, anisotropy) =>
    if anisotropy
      @filter_anisotropy = anisotropy

  setWrap: (@wrap_horiz, @rap_vert, depth) =>
    if depth
      @wrap_depth = depth

  getWidth: => 1
  getHeight: => 1

class AudioSource
  failfast_module @__name, @__base
  new: (@path, source_type) =>

_G.love = failfast_module nil, {
  graphics: failfast_module "graphics", {
    newImageFont: (...) ->
      ImageFont ...

    setFont: (font) ->
      print "setFont"

    setColor: (r,g,b,a) ->
      print "setColor: #{r} #{g} #{b} #{a}"

    setBackgroundColor: (r,g,b) ->
      print "setBackgroundColor: #{r} #{g} #{b}"

    rectangle: (mode, x, y, width, height) ->
      error "draw rectangle: #{mode} #{x}, #{y}, #{width}, #{height}"

    line: (points, ...) ->
      error "draw line"

    triangle: (...) ->
      error "draw triangle"

    push: ->
      error "graphics.push"

    pop: ->
      error "graphics.pop"

    scale: ->
      error "graphics.scale"

    translate: ->
      error "graphics.scale"

    newImage: (...) ->
      Image ...

    getWidth: ->
      app_config.window.width

    getHeight: ->
      app_config.window.height

  }
  audio: failfast_module "audio", {
    newSource: (...) ->
      AudioSource ...
  }
  math: failfast_module "math", {
    random: math.random
  }
  timer: failfast_module "timer", {
    getTime: ->
      js.global.performance\now! * 1000
  }
  keyboard: failfast_module "keyboard", { }
  joystick: failfast_module "joystick", {
    setGamepadMapping: -> -- noop
    getJoysticks: -> {} -- TODO:
  }
}

require("main")
require("conf")

-- initialize the config
-- https://github.com/love2d/love/blob/master/src/scripts/boot.lua#L385
app_config = {
  window: {
    width: 800
    height: 600
  }
}
if rawget love, "conf"
  love.conf app_config

for k, v in pairs app_config
  print k, v

-- create the canvas


-- start the game
love.load!

