---@module faders
---Provides a variety of fader functions for controlling popup transparency.
local faders = {}

---Linear fader function for popup transparency.
---
---@param blend (number) Initial blend value (0-100).
---@param cnt (number) Current animation frame count.
---
---@return number
function faders.linear_fader(blend, cnt)
  if blend + cnt <= 100 then
    return cnt
  else
    return 100
  end
end

---Sinusoidal fader function for popup transparency.
---
---@param blend (number) Initial blend value (0-100).
---@param cnt (number) Current animation frame count.
---
---@return number
function faders.sinus_fader(blend, cnt)
  if cnt <= 100 then
    return math.ceil((math.sin(cnt * (1 / blend)) * 0.5 + 0.5) * 100)
  else
    return 100
  end
end

---Exponential fader function for popup transparency.
---
---@param blend (number) Initial blend value (0-100).
---@param cnt (number) Current animation frame count.
---
---@return number
function faders.exp_fader(blend, cnt)
  if blend + math.floor(math.exp(cnt / 10)) <= 100 then
    return blend + math.floor(math.exp(cnt / 10))
  else
    return 100
  end
end

---Pulse fader function for popup transparency.
---
---@param blend (number) Initial blend value (0-100).
---@param cnt (number) Current animation frame count.
---
---@return number
function faders.pulse_fader(blend, cnt)
  if cnt < (100 - blend) / 2 then
    return cnt
  elseif cnt < 100 - blend then
    return 100 - cnt
  else
    return blend
  end
end

---Empty fader function (no transparency change).
---
---@param _ (any) Unused parameter.
---@param _ (any) Unused parameter.
---
---@return nil
function faders.empty_fader(_, _)
  return nil
end

return faders
