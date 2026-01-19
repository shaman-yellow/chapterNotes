local M = {}

local state = {
  chapter_to_notes = {},
  note_windows = { left = nil, right = nil },
  current_chapter = nil,
  config = nil,
  window_marker = "__chapter_notes_window__"
}

local utils = require('chapter-notes.utils')

-- 初始化
function M.init(config)
  state.config = config
end

-- 清理
function M.cleanup()
  M.close_notes_windows()
  state.chapter_to_notes = {}
  state.note_windows = { left = nil, right = nil }
  state.current_chapter = nil
end

-- 获取笔记文件名
local function get_note_filenames(chapter_file)
  if chapter_file == "" then return "", "" end
  
  local basename = vim.fn.fnamemodify(chapter_file, ":t:r")
  local dir = vim.fn.fnamemodify(chapter_file, ":h")
  
  local left_file = string.format("%s/.%s%s%s", 
    dir, basename, state.config.left_notes_suffix, state.config.notes_extension)
  local right_file = string.format("%s/.%s%s%s", 
    dir, basename, state.config.right_notes_suffix, state.config.notes_extension)
  
  return left_file, right_file
end

local function get_or_create_note_buffer(note_file)
  -- 检查是否已有 buffer
  local buf_list = vim.fn.getbufinfo({ buflisted = 1 })
  for _, buf in ipairs(buf_list) do
    if buf.name == note_file then
      return buf.bufnr
    end
  end
  
  -- 使用 bufadd 创建与文件关联的 buffer
  local bufnr = vim.fn.bufadd(note_file)
  
  -- 确保 buffer 被加载
  vim.fn.bufload(bufnr)
  
  -- 设置 buffer 选项
  vim.api.nvim_buf_set_option(bufnr, 'buftype', '')  -- 普通文件 buffer
  vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'hide')
  vim.api.nvim_buf_set_option(bufnr, 'swapfile', true)  -- 启用交换文件
  vim.api.nvim_buf_set_option(bufnr, 'undolevels', 1000)
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'markdown')
  vim.api.nvim_buf_set_option(bufnr, 'modified', false)  -- 初始未修改状态
  
  -- 如果文件不存在，设置 buffer 为可写入状态
  if vim.fn.filereadable(note_file) == 0 then
    -- 文件不存在，设置一个空 buffer
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
    vim.api.nvim_buf_set_option(bufnr, 'modified', false)
  end
  
  return bufnr
end

-- 关闭笔记窗口
function M.close_notes_windows()
  for side, win in pairs(state.note_windows) do
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    state.note_windows[side] = nil
  end
end

-- 检查并关闭笔记窗口
function M.check_and_close_notes()
  if not state.config.close_on_no_chapter then
    return
  end
  
  local has_chapter = false
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local win_buf = vim.api.nvim_win_get_buf(win)
    local win_file = vim.api.nvim_buf_get_name(win_buf)
    if utils.is_chapter_file(win_file, state.config) then
      has_chapter = true
      break
    end
  end
  
  if not has_chapter then
    M.close_notes_windows()
  end
end

local function create_notes_windows()
  -- 检查窗口是否已存在且有效
  local left_valid = state.note_windows.left and vim.api.nvim_win_is_valid(state.note_windows.left)
  local right_valid = state.note_windows.right and vim.api.nvim_win_is_valid(state.note_windows.right)
  
  if left_valid and right_valid then
    return state.note_windows
  end
  
  -- 清理无效窗口
  if state.note_windows.left and not left_valid then
    state.note_windows.left = nil
  end
  if state.note_windows.right and not right_valid then
    state.note_windows.right = nil
  end
  
  local chapter_win = vim.api.nvim_get_current_win()
  local total_width = vim.o.columns
  local win_height = vim.api.nvim_win_get_height(chapter_win)
  
  -- 计算窗口宽度
  local chapter_width = math.min(state.config.max_chapter_width, total_width - (state.config.min_notes_width * 2))
  local notes_width = math.floor((total_width - chapter_width) / 2)
  
  -- 调整 chapter 窗口宽度
  vim.api.nvim_win_set_width(chapter_win, chapter_width)
  
  -- 创建左笔记窗口 - 使用 split='left'
  local left_win = vim.api.nvim_open_win(0, false, {
    win = chapter_win,
    split = 'left',
    width = notes_width,
    height = win_height,
    focusable = false,  -- 关键：不获取焦点
  })
  
  -- 创建右笔记窗口 - 使用 split='right'
  local right_win = vim.api.nvim_open_win(0, false, {
    win = chapter_win,
    split = 'right', 
    width = notes_width,
    height = win_height,
    focusable = false,  -- 关键：不获取焦点
  })
  
  -- 设置窗口选项
  vim.api.nvim_win_set_option(left_win, 'wrap', true)
  vim.api.nvim_win_set_option(right_win, 'wrap', true)
  
  -- 为窗口设置文件类型（可选）
  vim.api.nvim_win_call(left_win, function()
    vim.cmd('set filetype=markdown')
  end)
  
  vim.api.nvim_win_call(right_win, function()
    vim.cmd('set filetype=markdown')
  end)
  
  -- 标记窗口
  vim.api.nvim_win_set_var(left_win, state.window_marker, "left_note")
  vim.api.nvim_win_set_var(right_win, state.window_marker, "right_note")
  
  state.note_windows = { left = left_win, right = right_win }
  
  return state.note_windows
end

function M.update_notes_for_current_buffer()
  local chapter_bufnr = vim.api.nvim_get_current_buf()
  local chapter_file = vim.api.nvim_buf_get_name(chapter_bufnr)
  
  if not utils.is_chapter_file(chapter_file, state.config) then
    return
  end
  
  -- 获取笔记文件
  local left_file, right_file = get_note_filenames(chapter_file)
  
  -- 获取或创建笔记 buffer
  local left_bufnr = get_or_create_note_buffer(left_file)
  local right_bufnr = get_or_create_note_buffer(right_file)
  
  -- 更新状态
  state.chapter_to_notes[chapter_bufnr] = {
    left = left_bufnr,
    right = right_bufnr,
    chapter_file = chapter_file,
    left_file = left_file,
    right_file = right_file
  }
  
  state.current_chapter = chapter_bufnr
  
  -- 创建窗口并设置 buffer
  local windows = create_notes_windows()
  
  -- 设置笔记窗口的 buffer
  if windows.left and vim.api.nvim_win_is_valid(windows.left) then
    vim.api.nvim_win_set_buf(windows.left, left_bufnr)
  end
  
  if windows.right and vim.api.nvim_win_is_valid(windows.right) then
    vim.api.nvim_win_set_buf(windows.right, right_bufnr)
  end
  
  -- 为笔记窗口添加更好的标识（使用 statusline）
  if windows.left and vim.api.nvim_win_is_valid(windows.left) then
    local basename = vim.fn.fnamemodify(chapter_file, ":t:r")
    vim.api.nvim_win_set_option(windows.left, 'statusline', state.config.left_window_title)
  end
  
  if windows.right and vim.api.nvim_win_is_valid(windows.right) then
    local basename = vim.fn.fnamemodify(chapter_file, ":t:r")
    vim.api.nvim_win_set_option(windows.right, 'statusline', state.config.right_window_title)
  end
  
  -- 设置自动保存
  if state.config.auto_save then
    local save_group = vim.api.nvim_create_augroup("ChapterNotesAutoSave", { clear = false })
    
    -- 左笔记自动保存
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = save_group,
      buffer = left_bufnr,
      callback = function()
        vim.cmd("silent! write")
      end
    })
    
    -- 右笔记自动保存
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = save_group,
      buffer = right_bufnr,
      callback = function()
        vim.cmd("silent! write")
      end
    })
  end
end

function M.sync_all_notes()
  local chapter_bufnr = state.current_chapter
  
  if not chapter_bufnr or not state.chapter_to_notes[chapter_bufnr] then
    return
  end
  
  -- 保存笔记
  local notes = state.chapter_to_notes[chapter_bufnr]
  
  -- 保存左笔记
  if vim.api.nvim_buf_is_loaded(notes.left) then
    vim.api.nvim_buf_call(notes.left, function()
      vim.cmd("silent! write")
    end)
  end
  
  -- 保存右笔记
  if vim.api.nvim_buf_is_loaded(notes.right) then
    vim.api.nvim_buf_call(notes.right, function()
      vim.cmd("silent! write")
    end)
  end
end

-- 切换笔记窗口
function M.toggle_notes()
  local left_valid = state.note_windows.left and vim.api.nvim_win_is_valid(state.note_windows.left)
  local right_valid = state.note_windows.right and vim.api.nvim_win_is_valid(state.note_windows.right)
  
  if left_valid and right_valid then
    M.close_notes_windows()
    vim.notify("The note window has been closed", vim.log.levels.INFO)
  else
    local current_file = vim.api.nvim_buf_get_name(0)
    if utils.is_chapter_file(current_file, state.config) then
      M.update_notes_for_current_buffer()
      vim.notify("The note window is open", vim.log.levels.INFO)
    else
      vim.notify("Currently not a chapter file", vim.log.levels.WARN)
    end
  end
end

-- 显示状态
function M.show_status()
  print("=== Chapter Notes 状态 ===")
  print(string.format("当前章节: %s", 
    state.current_chapter and 
    vim.api.nvim_buf_get_name(state.current_chapter) or "无"))
  
  if state.current_chapter and state.chapter_to_notes[state.current_chapter] then
    local notes = state.chapter_to_notes[state.current_chapter]
    print(string.format("左笔记: %s", notes.left_file))
    print(string.format("右笔记: %s", notes.right_file))
    print(string.format("左 buffer: %d", notes.left))
    print(string.format("右 buffer: %d", notes.right))
  end
  
  local left_valid = state.note_windows.left and vim.api.nvim_win_is_valid(state.note_windows.left)
  local right_valid = state.note_windows.right and vim.api.nvim_win_is_valid(state.note_windows.right)
  
  print(string.format("左窗口: %s (ID: %s)", 
    left_valid and "有效" or "无效",
    state.note_windows.left or "无"))
  print(string.format("右窗口: %s (ID: %s)", 
    right_valid and "有效" or "无效",
    state.note_windows.right or "无"))
  
  print(string.format("配置: auto_save=%s, auto_open=%s", 
    tostring(state.config.auto_save), 
    tostring(state.config.auto_open)))
end

-- 导出状态供调试
function M.get_state()
  return {
    chapter_to_notes = state.chapter_to_notes,
    note_windows = state.note_windows,
    current_chapter = state.current_chapter
  }
end

return M

