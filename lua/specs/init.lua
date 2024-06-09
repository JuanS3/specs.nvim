--- @module specs
--- This module provides functionality for displaying temporary popups based on cursor movement.
local Specs = {}

--- @table opts
--- Configuration options for the popup behavior.
local opts = {}

--- Internal state variables
local old_cur
local au_toggle

--- @table DEFAULT_OPTS
--- Default configuration options for the popup.
local DEFAULT_OPTS = {
  show_jumps       = true,          --- Show popups when cursor moves a certain distance.
  min_jump         = 30,            --- Minimum cursor movement distance to trigger popup (in characters).
  popup            = {
    delay_ms = 10,                  --- Delay before showing the popup (in milliseconds).
    inc_ms = 5,                     --- Increment for progressive fade-in (in milliseconds).
    blend = 10,                     --- Blend value for the popup window (0-100).
    width = 20,                     --- Width of the popup window (in characters).
    winhl = "PMenu",                --- Window highlight group for styling.
    fader = Specs.exp_fader,        --- Fader function for controlling popup transparency.
    resizer = Specs.shrink_resizer, --- Resizer function for controlling popup width and position.
  },
  ignore_filetypes = {},            --- Filetypes to ignore for popup display (empty table by default).
  --- Buffer types to ignore for popup display.
  ignore_buftypes  = {
    nofile = true,
  },
}

--- @function Specs.on_cursor_moved()
--- Handles cursor movement events and triggers popup display if necessary.
function Specs.on_cursor_moved()
  local cur = vim.fn.winline() + vim.api.nvim_win_get_position(0)[1]
  if old_cur then
    local jump = math.abs(cur - old_cur)
    if jump >= opts.min_jump then
      Specs.show_specs()
    end
  end
  old_cur = cur
end

--- @function Specs.should_show_specs(start_win_id)
--- Checks if the popup should be displayed based on current context and configuration.
--- @param start_win_id number ID of the current window
--- @return boolean Returns false if the window is invalid, if a command is being executed, or if the buffer or file type is in the ignored lists
function Specs.should_show_specs(start_win_id)
  if not vim.api.nvim_win_is_valid(start_win_id) then
    return false
  end

  if vim.fn.getcmdpos() ~= 0 then
    return false
  end

  if type(opts.ignore_filetypes) ~= 'table' or type(opts.ignore_buftypes) ~= 'table' then
    return true
  end

  local buftype, filetype, ok
  ok, buftype = pcall(vim.api.nvim_get_option_value, 'buftype', 0)

  if ok and opts.ignore_buftypes[buftype] then
    return false
  end

  ok, filetype = pcall(vim.api.nvim_get_option_value, 'filetype', 0)

  if ok and opts.ignore_filetypes[filetype] then
    return false
  end

  return true
end

--- @function Specs.show_specs(popup)
--- Creates and displays the popup window with specified configuration.
--- @param popup table|nil Optional custom popup settings
function Specs.show_specs(popup)
  local start_win_id = vim.api.nvim_get_current_win()

  if not Specs.should_show_specs(start_win_id) then
    return
  end

  popup = popup or {}

  -- Merge user-provided popup options with defaults.
  local _opts = vim.tbl_deep_extend('force', opts, { popup = popup })

  local cursor_col = vim.fn.wincol() - 1
  local cursor_row = vim.fn.winline() - 1
  local bufh = vim.api.nvim_create_buf(false, true)
  local win_id = vim.api.nvim_open_win(
    bufh,
    false,
    {
      relative = 'win',
      width = 1,
      height = 1,
      col = cursor_col,
      row = cursor_row,
      style = 'minimal'
    }
  )

  vim.api.nvim_set_option_value('winhl', 'Normal:' .. _opts.popup.winhl, { win = win_id })
  vim.api.nvim_set_option_value('winblend', _opts.popup.blend, { win = win_id })

  local cnt = 0
  local config = vim.api.nvim_win_get_config(win_id)
  local timer = vim.loop.new_timer()
  local closed = false

  vim.loop.timer_start(timer, _opts.popup.delay_ms, _opts.popup.inc_ms, vim.schedule_wrap(function()
    if closed or vim.api.nvim_get_current_win() ~= start_win_id then
      if not closed then
        pcall(vim.loop.close, timer)
        pcall(vim.api.nvim_win_close, win_id, true)

        -- Callbacks might stack up before the timer actually gets closed, track that state
        -- internally here instead
        closed = true
      end
      return
    end

    if vim.api.nvim_win_is_valid(win_id) then
      local bl = _opts.popup.fader(_opts.popup.blend, cnt)
      local dm = _opts.popup.resizer(_opts.popup.width, cursor_col, cnt)

      if bl ~= nil then
        vim.api.nvim_set_option_value('winblend', bl, { win = win_id })
      end
      if dm ~= nil then
        config.col = dm[2]
        vim.api.nvim_win_set_config(win_id, config)
        vim.api.nvim_win_set_width(win_id, dm[1])
      end
      if bl == nil and dm == nil then -- Done blending and resizing
        vim.loop.close(timer)
        vim.api.nvim_win_close(win_id, true)
      end
      cnt = cnt + 1
    end
  end))
end


--  _____                                                     _____
-- ( ___ )                                                   ( ___ )
--  |   |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|   |
--  |   |                                                     |   |
--  |   |    _______ _______ _____  _______ ______ _______    |   |
--  |   |   |    ___|   _   |     \|    ___|   __ \     __|   |   |
--  |   |   |    ___|       |  --  |    ___|      <__     |   |   |
--  |   |   |___|   |___|___|_____/|_______|___|__|_______|   |   |
--  |   |                                                     |   |
--  |   |                                                     |   |
--  |___|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|___|
-- (_____)                                                   (_____)
--- Faders to control the transparency of the popup window

--- @function Specs.linear_fader(blend, cnt)
--- Linear fader function for popup transparency.
--- @param blend number Initial blend level
--- @param cnt number Iteration counter
--- @return number|nil New transparency level
function Specs.linear_fader(blend, cnt)
  if blend + cnt <= 100 then
    return cnt
  end
end

--- @function Specs.sinus_fader(blend, cnt)
--- Sinusoidal fader function for popup transparency.
--- @param blend number Initial blend level
--- @param cnt number Iteration counter
--- @return number|nil New transparency level
function Specs.sinus_fader(blend, cnt)
  if cnt <= 100 then
    return math.ceil((math.sin(cnt * (1 / blend)) * 0.5 + 0.5) * 100)
  end
end

--- @function Specs.exp_fader(blend, cnt)
--- Exponential fader function for popup transparency.
--- @param blend number Initial blend level
--- @param cnt number Iteration counter
--- @return number|nil New transparency level
function Specs.exp_fader(blend, cnt)
  if blend + math.floor(math.exp(cnt / 10)) <= 100 then
    return blend + math.floor(math.exp(cnt / 10))
  end
end

--- @function Specs.pulse_fader(blend, cnt)
--- Pulse fader function for popup transparency.
--- @param blend number Initial blend level
--- @param cnt number Iteration counter
--- @return number|nil New transparency level
function Specs.pulse_fader(blend, cnt)
  if cnt < (100 - blend) / 2 then
    return cnt
  elseif cnt < 100 - blend then
    return 100 - cnt
  end
end

--- @function Specs.empty_fader()
--- Empty fader (no effect)
--- @return nil
function Specs.empty_fader(_, _)
  return nil
end


--  _____                                                                     _____
-- ( ___ )                                                                   ( ___ )
--  |   |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|   |
--  |   |                                                                     |   |
--  |   |    ______ _______ _______ _______ _______ _______ ______ _______    |   |
--  |   |   |   __ \    ___|     __|_     _|__     |    ___|   __ \     __|   |   |
--  |   |   |      <    ___|__     |_|   |_|     __|    ___|      <__     |   |   |
--  |   |   |___|__|_______|_______|_______|_______|_______|___|__|_______|   |   |
--  |   |                                                                     |   |
--  |   |                                                                     |   |
--  |___|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|___|
-- (_____)                                                                   (_____)
--- Resizers to control the size of the popup window

--- @function Specs.shrink_resizer(width, ccol, cnt)
--- Resizer function that shrinks the popup width.
--- @param width number Initial width
--- @param ccol number Cursor column
--- @param cnt number Iteration counter
--- @return table|nil New size and position
function Specs.shrink_resizer(width, ccol, cnt)
  if width - cnt > 0 then
    return { width - cnt, ccol - (width - cnt) / 2 + 1 }
  end
end

--- @function Specs.slide_resizer(width, ccol, cnt)
--- Resizer function that slides the popup to the left.
--- @param width number Initial width
--- @param ccol number Cursor column
--- @param cnt number Iteration counter
--- @return table|nil New size and position
function Specs.slide_resizer(width, ccol, cnt)
  if width - cnt > 0 then
    return { width - cnt, ccol }
  end
end

--- @function Specs.empty_resizer(width, ccol, cnt)
--- Empty resizer (no effect)
--- @param width number Initial width
--- @param ccol number Cursor column
--- @param cnt number Iteration counter
--- @return table|nil New size and position
function Specs.empty_resizer(width, ccol, cnt)
  if cnt < 100 then
    return { width, ccol - width / 2 }
  end
end



--- Sets up the module with custom options and creates the necessary autocmds
--- @param user_opts table Custom options
function Specs.setup(user_opts)
  opts = vim.tbl_deep_extend('force', DEFAULT_OPTS, user_opts)
  Specs.create_autocmds()
end

--- Toggles the activation of the autocmds
function Specs.toggle()
  if au_toggle then
    Specs.clear_autocmds()
  else
    Specs.create_autocmds()
  end
end

--- Creates the necessary autocmds
function Specs.create_autocmds()
  vim.cmd('augroup Specs')
  vim.cmd('autocmd!')
  if opts.show_jumps then
    vim.cmd("silent autocmd CursorMoved * :lua require('specs').on_cursor_moved()")
  end
  vim.cmd('augroup END')
  au_toggle = true
end

--- Clears the autocmds
function Specs.clear_autocmds()
  vim.cmd('augroup Specs')
  vim.cmd('autocmd!')
  vim.cmd('augroup END')
  au_toggle = false
end

return Specs
