local M = {}

-- 默认配置
local defaults = {
  -- 文件模式
  chapter_pattern = "chapter.*md",
  notes_extension = ".md",
  
  -- 文件命名
  left_notes_suffix = ".left",
  right_notes_suffix = ".right",
  
  -- 窗口布局
  max_chapter_width = 90,
  min_notes_width = 5,
  border_style = "rounded",
  border_chars = {
    "─", "│", "─", "│", "╭", "╮", "╯", "╰"
  },
  
  -- 窗口标题
  left_window_title = " Left Note ",
  right_window_title = " Right Note ",
  
  -- 自动行为
  auto_save = true,
  auto_open = true,
  close_on_no_chapter = true,
  
  -- 快捷键
  default_keymaps = true,
  toggle_keymap = "<leader>cn",
  sync_keymap = "<leader>cs",
  status_keymap = "<leader>cS",
  
  -- 外观
  window_hl = "Normal:NormalFloat",
  border_hl = "FloatBorder",
  title_hl = "FloatTitle",
  
  -- 调试
  debug = false,
  log_level = vim.log.levels.INFO
}

-- 配置验证
local function validate_config(user_config)
  local config = vim.tbl_deep_extend("force", {}, defaults, user_config or {})
  
  -- 确保宽度设置合理
  if config.max_chapter_width < 20 then
    config.max_chapter_width = 20
    vim.notify("max_chapter_width Too small, adjusted to 20", vim.log.levels.WARN)
  end
  
  if config.min_notes_width < 5 then
    config.min_notes_width = 5
    vim.notify("min_notes_width Too small, adjusted to 10", vim.log.levels.WARN)
  end
  
  -- 验证边框样式
  local valid_borders = {
    "none", "single", "double", "rounded", "solid", "shadow",
    { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }
  }
  
  if type(config.border_style) == "string" then
    local valid = false
    for _, border in ipairs(valid_borders) do
      if border == config.border_style then
        valid = true
        break
      end
    end
    if not valid then
      config.border_style = defaults.border_style
    end
  end
  
  return config
end

-- 配置设置
function M.setup(user_config)
  local config = validate_config(user_config)
  
  if config.debug then
    for k, v in pairs(config) do
      vim.notify(string.format("  %s: %s", k, vim.inspect(v)), vim.log.levels.DEBUG)
    end
  end
  
  return config
end

-- 导出默认配置
M.defaults = defaults

return M
