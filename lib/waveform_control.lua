local djw = require("lib.djwaveform")

local WC = {}
WC.__index = WC

-- constructor ----------------------------------------------------------
function WC.new(soundData, gradient, cfg, x, y, w, h)
  local self = setmetatable({}, WC)

  self.x = x
  self.y = y
  self.w = w
  self.h = h

  -- physical-pixel scale
  self.scale =
    love.window.getDPIScale and love.window.getDPIScale() or 1
  self.physW = w * self.scale
  self.physH = h * self.scale

  -- GPU textures + counts
  self.sampTex,
  self.colTex,
  self.hop,
  self.nWin,
  self.sampW,
  self.sampH,
  self.winW,
  self.winH,
  self.nSamples =
    djw.buildWaveBuffers(soundData, gradient, cfg)

  -- navigation
  self.minZoom =
    (self.nSamples > 0) and (self.nSamples / self.physW) or 1
  self.zoom = self.minZoom
  self.offset = 0

  self.dragging = false
  self.dragStartPx = 0
  self.origOffset = 0

  -- vertical layout in physical px
  self.centerY = (y + h * 0.5) * self.scale
  self.gain = self.physH * 0.45
  self.baseThickness = 1.0 * self.scale

  self.shader = love.graphics.newShader("shaders/waveform.frag")
  return self
end

-- hit-test in logical coords ------------------------------------------
function WC:contains(mx, my)
  return
    mx >= self.x and
    mx <  self.x + self.w and
    my >= self.y and
    my <  self.y + self.h
end

-- wheel zoom (cursor-locked) ------------------------------------------
function WC:wheelmoved(mx, my, dy)
  if dy == 0 or not self:contains(mx, my) then
    return
  end

  local zx = math.exp(-dy * 0.15)
  local newZoom =
    math.max(
      0.25,
      math.min(self.minZoom, self.zoom * zx)
    )

  -- cursor x in physical px relative to control
  local localPx = (mx - self.x) * self.scale
  local sampleAtCursor = self.offset + localPx * self.zoom

  self.offset = sampleAtCursor - localPx * newZoom
  self.zoom = newZoom
  self:clampOffset()
end

-- drag-pan -------------------------------------------------------------
function WC:mousepressed(mx, my, button)
  if button == 1 and self:contains(mx, my) then
    self.dragging = true
    self.dragStartPx = mx * self.scale
    self.origOffset = self.offset
    love.mouse.setGrabbed(true)
  end
end

function WC:mousereleased(button)
  if button == 1 and self.dragging then
    self.dragging = false
    love.mouse.setGrabbed(false)
    self:clampOffset()
  end
end

function WC:mousemoved(mx, my, dx)
  if not self.dragging then
    return
  end
  -- delta in physical pixels from where drag started
  local deltaPx = (mx * self.scale) - self.dragStartPx
  self.offset = self.origOffset - deltaPx * self.zoom
  self:clampOffset()
end

-- keep offset inside [0 .. max] ---------------------------------------
function WC:clampOffset()
  local maxOff =
    math.max(0, self.nSamples - self.physW * self.zoom)
  self.offset = math.max(0, math.min(self.offset, maxOff))
end

-- draw the waveform and border ----------------------------------------
function WC:draw()
  if not self.sampTex then
    return
  end

  local s = self.shader

  -- textures + tiling
  s:send("SampTex", self.sampTex)
  s:send("ColTex", self.colTex)
  s:send("u_sampW", self.sampW)
  s:send("u_sampH", self.sampH)
  s:send("u_winW", self.winW)
  s:send("u_winH", self.winH)

  -- counts + nav
  s:send("u_sampleCount", self.nSamples)
  s:send("u_winCount", self.nWin)
  s:send("u_offset", self.offset)
  s:send("u_samplesPerPixel", self.zoom)
  s:send("u_hop", self.hop)

  -- vertical layout
  s:send("u_centerY", self.centerY)
  s:send("u_gain", self.gain)
  s:send("u_baseThickness", self.baseThickness)

  love.graphics.setShader(s)
  love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
  love.graphics.setShader()

  -- 1-px border
  love.graphics.setColor(1, 1, 1, 0.25)
  love.graphics.rectangle(
    "line",
    self.x + 0.5,
    self.y + 0.5,
    self.w - 1,
    self.h - 1
  )
  love.graphics.setColor(1, 1, 1, 1)
end

return WC
