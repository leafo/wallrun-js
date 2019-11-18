
js = require "js"

_debug = (...) -> -- js.global.console\warn ...
_warn = (...) -> js.global.console\warn ...

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

-- covnert love2d key constant to js event.key
key_to_js = (key) ->
  switch key
    when "space"
      " "
    when "left"
      "ArrowLeft"
    when "right"
      "ArrowRight"
    when "up"
      "ArrowUp"
    when "down"
      "ArrowDown"
    else
      key

local app_config, app

create_app = (config) ->
  dom_canvas = js.global.document\createElement "canvas"
  dom_canvas.width = config.window.width
  dom_canvas.height = config.window.height
  dom_canvas.tabIndex = 0

  keys_held = {}

  dom_canvas\addEventListener "keydown", (_, e) ->
    -- TODO: push events to be flushed on next update
    keys_held[e.key] = true

  dom_canvas\addEventListener "keyup", (_, e) ->
    keys_held[e.key] = false

  {
    load_promises: js.new js.global.Array
    :dom_canvas
    :keys_held
  }

class Quad
  failfast_module @__name, @__base
  getViewport: =>
    @[1], @[2], @[3], @[4]

class ImageFont
  failfast_module @__name, @__base
  new: (@path, characters) =>

class SpriteBatch
  failfast_module @__name, @__base

  new: (@image, @batch_size) =>
    @batch = {}

  clear: =>
    @batch = {}

  add: (...) =>
    table.insert @batch, {...}
    #@batch

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

    @dom_image\addEventListener "load", @\on_loaded

    @dom_image\addEventListener "error", ->
      js.global.console\error "Image failed to load: #{@path}"

    co, main = coroutine.running!
    unless main
      coroutine.yield p

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
      _warn "getting image width for unloaded image: #{@path}"
    @width

  getHeight: =>
    unless @loaded
      _warn "getting image height for unloaded image: #{@path}"
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

  loaded: false

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
          _warn "Unable to get audio context right"

  stop: =>
    _debug "source stop: #{@path}"

  play: =>
    _debug "source play: #{@path}"

_G.love = failfast_module nil, {
  graphics: failfast_module "graphics", {
    print: ->
      -- noop

    newImageFont: (...) ->
      ImageFont ...

    setFont: (font) ->
      _debug "setFont"

    setColor: (r,g,b,a) ->
      _debug "setColor: #{r} #{g} #{b} #{a}"
      context = app.dom_canvas\getContext "2d"
      context.fillStyle = "rgba(#{r*255}, #{g*255}, #{b*255}, #{a})"

    setBackgroundColor: (r,g,b) ->
      _debug "setBackgroundColor: #{r} #{g} #{b}"

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
      switch mode
        when "fill"
          context = app.dom_canvas\getContext "2d"
          context\fillRect x,y, width, height
        else
          error "draw rectangle: #{mode} #{x}, #{y}, #{width}, #{height}"

    line: (points, ...) ->
      error "draw line"

    triangle: (...) ->
      error "draw triangle"

    origin: ->
      _debug "graphics.origin"
      context = app.dom_canvas\getContext "2d"
      context\setTransform 1, 0, 0, 1, 0, 0

    push: ->
      _debug "graphics.push"
      context = app.dom_canvas\getContext "2d"
      context\save!

    pop: ->
      _debug "graphics.pop"
      context = app.dom_canvas\getContext "2d"
      context\restore!

    scale: (sx=1, sy=1) ->
      _debug "graphics.scale(#{sx}, #{sy})"
      context = app.dom_canvas\getContext "2d"
      context\scale sx, sy

    translate: (tx, ty) ->
      _debug "graphics.translate(#{tx}, #{ty})"
      context = app.dom_canvas\getContext "2d"
      context\translate tx, ty

    rotate: (rad) ->
      _debug "graphics.rotate(#{rad})"
      context = app.dom_canvas\getContext "2d"
      context\rotate rad

    -- draw: (thing, x, y=0, r=0, sx=1, sy=1, ox=0, oy=0, kx=0, ky=0) ->
    draw: (thing, quad, ...) ->
      local x, y, r, sx, sy, ox, oy, kx, ky

      if type(quad) == "table"
        x, y, r, sx, sy, ox, oy, kx, ky = ...
      else
        x, y, r, sx, sy, ox, oy, kx, ky = quad, ...
        quad = nil

      x or= 0
      y or= 0
      r or= 0
      sx or= 1
      sy or= 1
      ox or= 0
      oy or= 0
      kx or= 0
      ky or= 0

      context = app.dom_canvas\getContext "2d"
      context.imageSmoothingEnabled = false

      needs_pop = false

      if sx != 1 or sy != 1
        -- this doesn't work
        context\save!
        context\translate x, y

        x = 0
        y = 0
        context\scale sx, sy

        if ox != 0 or oy != 0
          context\translate -ox, -oy

        needs_pop = true

      switch thing.__class
        when Image
          _debug "graphics.draw(image: #{thing.path}, #{x}, #{y})"
          context = app.dom_canvas\getContext "2d"
          if quad
            -- TODO: this doesn't respect wrap setting
            qx, qy, qw, qh, qsw, qsh = unpack quad
            context\drawImage thing.dom_image, qx, qy, qw, qh, x, y, qw, qh
          else
            context\drawImage thing.dom_image, x,y

        when SpriteBatch
          for args in *thing.batch
            love.graphics.draw thing.image, unpack args
        else
          error "don't know how to draw object: #{thing and thing.__class and thing.__class.__name}"

      if needs_pop
        context\restore!

    newImage: (...) ->
      Image ...

    newSpriteBatch: (...) ->
      SpriteBatch ...

    getWidth: ->
      app_config.window.width

    getHeight: ->
      app_config.window.height

    newQuad: (x, y, width, height, sw, sh) ->
      setmetatable {
        x or 0
        y or 0
        width or 0
        height or 0
        sw or 0
        sh or 0
      }, Quad.__base
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
  keyboard: failfast_module "keyboard", {
    isDown: (key, ...) ->
      return false unless key

      if app.keys_held[key_to_js key]
        return true

      if ...
        love.keyboard.isDown ...
      else
        false
  }
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

-- create the canvas
app = create_app app_config

js.global.document.body\appendChild app.dom_canvas

-- start the game
loader = coroutine.wrap -> love.load!

tick_loader = (loader, done) ->
  if p = loader!
    thn p, -> tick_loader loader, done
  else
    done!

run_app = ->
  update_tick = ->
    -- update
    js.global.performance\mark "before update"
    love.update 1/60
    js.global.performance\mark "end update"
    js.global.performance\measure "update", "before update", "end update"

    -- draw
    -- https://github.com/love2d/love/blob/master/src/scripts/boot.lua#L614
    love.graphics.origin!
    love.graphics.clear love.graphics.getBackgroundColor!


    js.global.performance\mark "before draw"
    love.draw!
    js.global.performance\mark "end draw"
    js.global.performance\measure "draw", "before draw", "end draw"

    js.global\requestAnimationFrame update_tick

  js.global\requestAnimationFrame update_tick

tick_loader loader, run_app

-- -- delay
-- p = js.new js.global.Promise, (_, resolve) ->
--   js.global\setTimeout resolve, 1000
-- app.load_promises\push p

-- print "Waiting for promises: #{app.load_promises.length}"
-- thn js.global.Promise\all(app.load_promises), ->
--   print "Promises ready"
--   run_app!

