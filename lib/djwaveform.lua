-- djwaveform.lua – helper for both column and line renderers
local DJW = {}

local profiler = require("lib.profiler")
local ffi = require("ffi")

-- constants
DJW.WIN_NONE, DJW.WIN_HANN, DJW.WIN_HAMM, DJW.WIN_BLACK = 0, 1, 2, 3
DJW.RANGE_FULL = 0

-- Lua helpers
local abs = math.abs
local cos = math.cos
local pi = math.pi

profiler.push("lib shader compile")
local csFFT = love.graphics.newComputeShader("shaders/preprocess.comp")
local csCopy = love.graphics.newComputeShader("shaders/sample2img.comp")
profiler.pop()
profiler.report(true, true)

local gradBufF
local gradBufC
local sampleBuf
local sampleBufSize = 0

local hannBuf
local hannSize = 0

-- Hann window buffer
local function updateHannBuffer(N)
  profiler.push("updateHannBuffer")
  if hannBuf and hannSize == N then
    return
  end
  local vals = {}
  for i = 0, N - 1 do
    vals[i + 1] = 0.5 * (1 - cos(2 * pi * i / (N - 1)))
  end
  hannBuf = love.graphics.newBuffer("float", vals, { shaderstorage = true })
  hannSize = N
  profiler.pop()
end

-- gradient buffers
local function buildGradientBuffers(grad)
  profiler.push("updateHannBuffer")
  if gradBufF then
    return
  end
  local freq = {}
  local flat = {}
  for i = 1, 64 do
    local p = grad[i] or grad[#grad]
    freq[i] = p.freq
    flat[#flat + 1] = p.r / 255
    flat[#flat + 1] = p.g / 255
    flat[#flat + 1] = p.b / 255
    flat[#flat + 1] = 0
  end
  gradBufF = love.graphics.newBuffer("float", freq, { shaderstorage = true })
  gradBufC = love.graphics.newBuffer("float", flat, { shaderstorage = true })
  profiler.pop()
end

-- sample SSBO
local function updateSampleBuffer(samples)
  profiler.push("updateSampleBuffer")
  local n = #samples
  if not sampleBuf or n > sampleBufSize then
    sampleBuf = love.graphics.newBuffer(
      "float",
      samples,
      { shaderstorage = true }
    )
    sampleBufSize = n
  end
  profiler.pop()
end

function DJW.generateTexture(soundData, grad, cfg)
  cfg.actualSampleRate = soundData:getSampleRate()
  local total = soundData:getSampleCount()
  local ch = soundData:getChannelCount()
  local mono = {}
  for i = 0, total - 1 do
    local s = 0
    for c = 1, ch do
      s = s + soundData:getSample(i, c)
    end
    mono[i + 1] = s / ch
  end
  return buildTexture(mono, grad, cfg, cfg.width, cfg.height)
end

-- line-renderer data
function DJW.buildWaveBuffers(soundData, grad, cfg)
  buildGradientBuffers(grad)
  updateHannBuffer(cfg.fftSize)

  cfg.actualSampleRate = soundData:getSampleRate()
  profiler.push("SSBO upload (packed uint32)")

  local frames = soundData:getSampleCount()
  local channels = soundData:getChannelCount()
  local bitDepth = soundData:getBitDepth()
  assert(bitDepth == 16, "This path only supports 16-bit PCM")

  local totalWords = frames * channels / 2
  assert(channels == 2, "Packing only shown for stereo PCM")

  if not sampleBuf or totalWords > sampleBufSize then
    sampleBuf = love.graphics.newBuffer(
      "uint32",
      totalWords,
      { shaderstorage = true }
    )
    sampleBufSize = totalWords
  end

  print(
    "Packed "
      .. frames
      .. " samples into "
      .. totalWords
      .. " uint32"
  )

  sampleBuf:setArrayData(soundData)
  profiler.pop()

  local maxW = 8192
  local total = frames * 2
  local sampW = math.min(maxW, total)
  local sampH = math.ceil(total / sampW)

  local hop = cfg.fftSize / cfg.overlapFactor
  local nWin = math.max(1, math.floor((total - cfg.fftSize) / hop))
  local winW = math.min(maxW, nWin)
  local winH = math.ceil(nWin / winW)

  local sampTex = love.graphics.newTexture(
    sampW,
    sampH,
    { format = "r32f", computewrite = true }
  )
  local colTex = love.graphics.newTexture(
    winW,
    winH,
    { format = "rgba32f", computewrite = true }
  )

  csFFT:send("SamplesBuf", sampleBuf)
  csFFT:send("WindowBuf", hannBuf)
  csFFT:send("FreqBuf", gradBufF)
  csFFT:send("ColorBuf", gradBufC)
  csFFT:send("LineImg", colTex)
  csFFT:send("totalSamples", total)
  csFFT:send("hop", hop)
  csFFT:send("sampleRate", cfg.actualSampleRate)
  csFFT:send("useLog", cfg.useLogFreq or 0)
  csFFT:send("texWidth", winW)

  profiler.push("FFT analysis")
  love.graphics.dispatchThreadgroups(csFFT, nWin, 1, 1)
  profiler.pop()

  profiler.push("copy FFT output")
  csCopy:send("SamplesBuf", sampleBuf)
  csCopy:send("SampImg", sampTex)
  csCopy:send("totalSamples", total)
  csCopy:send("texWidth", sampW)
  local groups = math.ceil(total / 256)
  love.graphics.dispatchThreadgroups(csCopy, groups, 1, 1)
  profiler.pop()

  profiler.report(true, true)

  return sampTex,
    colTex,
    hop,
    nWin,
    sampW,
    sampH,
    winW,
    winH,
    total
end

return DJW
