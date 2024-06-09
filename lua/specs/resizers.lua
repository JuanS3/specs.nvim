--- @module resizers
--- This module provides various resizer functions for controlling popup size and position.
local resizers = {}

--- Resizer function that shrinks the popup width.
---
--- @param width (number) The current popup width.
--- @param ccol (number) The current popup column position.
--- @param cnt (number) The current resizer counter.
--- @return table {number, number} The updated popup width and column position.
function resizers.shrink_resizer(width, ccol, cnt)
  if width - cnt > 0 then
    return { width - cnt, ccol - (width - cnt) / 2 + 1 }
  else
    return { 1, ccol }
  end
end

--- Resizer function that slides the popup to the left.
---
--- @param width (number) The current popup width.
--- @param ccol (number) The current popup column position.
--- @param cnt (number) The current resizer counter.
--- @return table {number, number} The updated popup width and column position.
function resizers.slide_resizer(width, ccol, cnt)
  if width - cnt > 0 then
    return { width - cnt, ccol }
  else
    return { 1, ccol }
  end
end

--- Empty resizer function (no width or position change).
---
--- @param width (number) The current popup width.
--- @param ccol (number) The current popup column position.
--- @param cnt (number) The current resizer counter.
--- @return table {number, number} The unchanged popup width and column position.
function resizers.empty_resizer(width, ccol, cnt)
  if cnt < 100 then
    return { width, ccol - width / 2 }
  else
    return { width, ccol }
  end
end

return resizers
