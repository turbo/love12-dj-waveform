local djw       = require("lib.djwaveform")
local WC        = require("lib.waveform_control")
local gradient  = require("gradient")           -- 64-entry table
local profiler  = require("lib.profiler")

local cfg = {
  fftSize        = 2048,
  overlapFactor  = 2,
  windowType     = djw.WIN_HANN,
  useLogFreq     = 0,
}

local tLast   = 0
local controls = {}
local stems = {
  "target_0_drums",
  "target_1_bass",
  "target_2_other",
  "target_3_vocals" 
}

local stemData = { } -- SoundData
local stemSources = { } -- playables

function love.load()
  love.window.setMode(1600, 500, { resizable = false })
  love.graphics.setBackgroundColor(0, 0, 0)

  for i, stemFile in ipairs(stems) do
    stemData[i] = love.sound.newSoundData("assets/" .. stemFile .. ".wav")
    stemSources[i] = love.audio.newSource(stemData[i], "static")
    stemSources[i]:setVolume(1 / #stems) -- proportional volume
    controls[#controls + 1] = WC.new(
      stemData[i],
      gradient,
      cfg,
      0,
      125 * (i - 1),
      1600,
      125
    )
  end
end

function love.wheelmoved(dx, dy)
  local mx, my = love.mouse.getPosition()
  for _, c in ipairs(controls) do
    c:wheelmoved(mx, my, dy)
  end
end

function love.mousepressed(x, y, button)
  for _, c in ipairs(controls) do
    c:mousepressed(x, y, button)
  end
end

function love.mousereleased(_, _, button)
  for _, c in ipairs(controls) do
    c:mousereleased(button)
  end
end

function love.mousemoved(x, y, dx, dy)
  for _, c in ipairs(controls) do
    c:mousemoved(x, y, dx)
  end
end

function love.draw()
  for _, c in ipairs(controls) do
    c:draw()
  end
end

function love.keypressed(key)
  if key == "space" then
    local playing = stemSources[1]:isPlaying()
    for _, src in ipairs(stemSources) do
      if playing then
        src:pause()
      else
        src:play()
      end
    end
  end
end

function love.update(dt)
  tLast = tLast + dt
  -- if tLast >= 1.0 then
  --   profiler.report(true)
  --   profiler.reset()
  --   tLast = 0
  -- end
end