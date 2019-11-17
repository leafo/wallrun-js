
js = require "js"
warn = (...) -> js.global.console\warn ...

package.path = "./?.lua;ludum-dare-30/?.lua;lovekit/?.lua"

RESOURCE_PREFIX = "ludum-dare-30/"

_G.unpack = table.unpack

_G.setfenv = (fn, env) ->
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

_G.getfenv = (fn) ->
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

local app_config, app

create_app = (config) ->
  dom_canvas = js.global.document\createElement "canvas"
  dom_canvas.width = config.window.width
  dom_canvas.height = config.window.height

  {
    load_promises: js.new js.global.Array
    :dom_canvas
  }

class ImageFont
  failfast_module @__name, @__base
  new: (@path, characters) =>

class Image
  failfast_module @__name, @__base

  @dom_images: {}

  loaded: false
  width: 0
  height: 0

  new: (@path) =>
    @dom_image = js.new js.global.Image
    @dom_image.src = "#{RESOURCE_PREFIX}#{@path}"

    @@dom_images[@path] = @dom_image

    p = js.new js.global.Promise, (_, @resolve_promise) ->
    app.load_promises\push p

    @dom_image\addEventListener "load", @\on_loaded, false

    @dom_image\addEventListener(
      "error"
      -> js.global.console\error "Image failed to load: #{@path}"
      false
    )

  on_loaded: =>
    @loaded = true
    @width = @dom_image.width
    @height = @dom_image.height
    if rp = @resolve_promise
      @resolve_promise = nil
      rp!

  setFilter: (@filter_min, @filter_mag, anisotropy) =>
    if anisotropy
      @filter_anisotropy = anisotropy

  setWrap: (@wrap_horiz, @rap_vert, depth) =>
    if depth
      @wrap_depth = depth

  getWidth: =>
    unless @loaded
      warn "getting image width for unloaded image: #{@path}"
    @width

  getHeight: =>
    unless @loaded
      warn "getting image height for unloaded image: #{@path}"
    @height

thn = (p, ...) -> p["then"] p, ...

class AudioSource
  failfast_module @__name, @__base

  @get_audio_context: =>
    if rawget @, "audio_context"
      return @audio_context

    -- NOTE: audio context will be created disabled until there is user interaction
    audio_cls = js.global.AudioContext or window.webkitAudioContext
    @audio_context = js.new audio_cls

    @audio_context

  new: (@path, source_type) =>
    -- TODO: error handling
    p = js.global\fetch("#{RESOURCE_PREFIX}#{@path}")
    thn p, (_, res) ->
      thn res\arrayBuffer!, (_, buffer) ->
        context = @@get_audio_context!

        if context
          @dom_source = @@get_audio_context!\createBufferSource!
          context\decodeAudioData buffer, (_, decoded_data) ->
            @dom_source.buffer = decoded_data
            @dom_source\connect context.destination
        else
          js.global.console\warn "Unable to get audio context right"


_G.love = failfast_module nil, {
  graphics: failfast_module "graphics", {
    newImageFont: (...) ->
      ImageFont ...

    setFont: (font) ->
      warn "setFont"

    setColor: (r,g,b,a) ->
      warn "setColor: #{r} #{g} #{b} #{a}"
      -- context = app.dom_canvas\getContext "2d"
      -- context.fillStyle = "rgba(#{r*255}, #{g*255}, #{b*255}, #{a})"

    setBackgroundColor: (r,g,b) ->
      warn "setBackgroundColor: #{r} #{g} #{b}"

    getBackgroundColor: ->
      0,0,0,1

    clear: (r,g,b,a) ->
      if r == nil
        r,g,b,a = love.graphics.getBackgroundColor!

      context = app.dom_canvas\getContext "2d"
      if r == 0 and g == 0 and b == 0 and a == 0
        context\clearRect 0, 0, app.dom_canvas.width, app.dom_canvas.height
      else
        context.fillStyle = "rgba(#{r*255}, #{g*255}, #{b*255}, #{a})"
        context\fillRect 0, 0, app.dom_canvas.width, app.dom_canvas.height

    rectangle: (mode, x, y, width, height) ->
      error "draw rectangle: #{mode} #{x}, #{y}, #{width}, #{height}"

    line: (points, ...) ->
      error "draw line"

    triangle: (...) ->
      error "draw triangle"

    origin: ->
      warn "graphics.origin"
      context = app.dom_canvas\getContext "2d"
      context\setTransform 1, 0, 0, 1, 0, 0

    push: ->
      warn "graphics.push"
      context = app.dom_canvas\getContext "2d"
      context\save!

    pop: ->
      warn "graphics.pop"
      context = app.dom_canvas\getContext "2d"
      context\restore!

    scale: (sx=1, sy=1) ->
      warn "graphics.scale(#{sx}, #{sy})"
      context = app.dom_canvas\getContext "2d"
      context\scale sx, sy

    translate: (tx, ty) ->
      warn "graphics.translate(#{tx}, #{ty})"
      context = app.dom_canvas\getContext "2d"
      context\translate tx, ty

    draw: (thing, x, y=0, r=0, sx=1, sy=1, ox=0, oy=0, kx=0, ky=0) ->
      assert type(x) == "number", "implement drawq"
      context = app.dom_canvas\getContext "2d"
      context.imageSmoothingEnabled = false

      switch thing.__class
        when Image
          warn "graphics.draw(image: #{thing.path}, #{x}, #{y})"
          js.global.console\log thing.dom_image
          context = app.dom_canvas\getContext "2d"
          context\drawImage thing.dom_image, x,y
        else
          error "don't know how to draw object"

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
app = create_app app_config

js.global.document.body\appendChild app.dom_canvas

-- start the game
love.load!

-- -- delay
-- p = js.new js.global.Promise, (_, resolve) ->
--   js.global\setTimeout resolve, 1000
-- app.load_promises\push p

print "Waiting for promises: #{app.load_promises.length}"
thn js.global.Promise\all(app.load_promises), ->
  print "Promises ready"

  -- run one update
  love.update 1/60

  -- run one draw
  -- https://github.com/love2d/love/blob/master/src/scripts/boot.lua#L614
  love.graphics.origin!
  love.graphics.clear love.graphics.getBackgroundColor!

  love.draw!

  context = app.dom_canvas\getContext "2d"
  context.fillStyle = "white"
  context\fillRect 0, 0, 10, 10






