local M = {}

-- 检查是否为 chapter 文件

function M.is_chapter_file(filename, config)
  if filename == "" then return false end
  -- 直接使用 Lua 正则匹配
  -- chapter*.md -> chapter.*\.md（Lua 正则）
  local pattern = config.chapter_pattern
    :gsub("%.", "%.")     -- 转义点号
    :gsub("%*", ".*")     -- 将 * 替换为 .*
  
  -- 检查文件名是否匹配模式
  local basename = vim.fn.fnamemodify(filename, ":t")
  return basename:match("^" .. pattern .. "$") ~= nil
end

-- 安全获取窗口变量
function M.get_win_var(win_id, var_name)
  local ok, value = pcall(vim.api.nvim_win_get_var, win_id, var_name)
  return ok and value or nil
end

-- 检查窗口是否属于插件
function M.is_notes_window(win_id, state)
  return M.get_win_var(win_id, state.window_marker) ~= nil
end

-- 获取所有 chapter 文件 buffer
function M.get_chapter_buffers(config)
  local chapter_buffers = {}
  local buf_list = vim.fn.getbufinfo({ buflisted = 1 })
  
  for _, buf in ipairs(buf_list) do
    if M.is_chapter_file(buf.name, config) then
      table.insert(chapter_buffers, buf.bufnr)
    end
  end
  
  return chapter_buffers
end

-- 日志函数
function M.log(message, level)
  level = level or vim.log.levels.INFO
  vim.notify("[Chapter Notes] " .. message, level)
end

-- 调试日志
function M.debug(message, config)
  if config and config.debug then
    M.log(message, vim.log.levels.DEBUG)
  end
end

-- 确保目录存在
function M.ensure_dir_exists(filepath)
  local dir = vim.fn.fnamemodify(filepath, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
end

-- 计算窗口布局
function M.calculate_layout(total_width, config)
  local chapter_width = math.min(config.max_chapter_width, total_width - (config.min_notes_width * 2))
  local remaining_width = total_width - chapter_width
  local notes_width = math.floor(remaining_width / 2)
  
  -- 确保最小宽度
  if notes_width < config.min_notes_width then
    notes_width = config.min_notes_width
    chapter_width = total_width - (notes_width * 2)
  end
  
  return {
    chapter = chapter_width,
    notes = notes_width,
    total_notes = notes_width * 2
  }
end

return M
