local M = {}

-- 导入子模块
local config = require('chapter-notes.config')
local core = require('chapter-notes.core')
local utils = require('chapter-notes.utils')

-- 插件状态
local state = {
  initialized = false,
  config = nil
}

-- 设置函数
function M.setup(user_config)
  if state.initialized then
    vim.notify("Chapter Notes Already initialized", vim.log.levels.WARN)
    return
  end
  
  -- 配置
  state.config = config.setup(user_config or {})
  
  -- 初始化核心功能
  core.init(state.config)
  
  -- 设置自动命令
  M.setup_autocmds()
  
  -- 设置用户命令
  M.setup_commands()
  
  -- 设置默认快捷键
  M.setup_keymaps()
  
  state.initialized = true
end

-- 设置自动命令
function M.setup_autocmds()
  local augroup = vim.api.nvim_create_augroup("ChapterNotes", { clear = true })
  
  -- 进入 chapter 文件时
  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    callback = function()
      local file = vim.api.nvim_buf_get_name(0)
      if utils.is_chapter_file(file, state.config) then
        core.update_notes_for_current_buffer()
      else
        core.check_and_close_notes()
      end
    end
  })

  vim.api.nvim_create_autocmd("User", {
    pattern = "SessionWritePreUser",
    callback = function()
      core.check_and_close_notes()
    end,
  })

  -- vim.api.nvim_create_autocmd("User", {
  --   pattern = SessionLoadPreUser,
  --   callback = function()
  --     core.check_and_close_notes()
  --   end,
  -- })

  -- 写入 chapter 文件时同步笔记
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = augroup,
    callback = function()
      local file = vim.api.nvim_buf_get_name(0)
      if utils.is_chapter_file(file, state.config) then
        core.sync_all_notes()
      end
    end
  })

  -- 切换标签页时检查
  -- vim.api.nvim_create_autocmd("TabEnter", {
  --   group = augroup,
  --   callback = function()
  --     vim.defer_fn(function()
  --       core.check_and_close_notes()
  --     end, 50)
  --   end
  -- })

  vim.api.nvim_create_autocmd("VimResized", {
    group = augroup,
    callback = function()
      -- 延迟一小段时间，确保窗口大小变化已经完成
      -- vim.defer_fn(function()
        core.adjust_windows_layout()
      -- end, 50)
    end
  })
end

-- 设置用户命令
function M.setup_commands()
  vim.api.nvim_create_user_command("ChapterNotesToggle", function()
    core.toggle_notes()
  end, { desc = "Switch note window display/hide" })
  
  vim.api.nvim_create_user_command("ChapterNotesSync", function()
    core.sync_all_notes()
  end, { desc = "Manually synchronize all notes" })
  
  vim.api.nvim_create_user_command("ChapterNotesStatus", function()
    core.show_status()
  end, { desc = "Display plugin status" })
  
  vim.api.nvim_create_user_command("ChapterNotesUpdate", function()
    core.update_notes_for_current_buffer()
  end, { desc = "Open a note window for the current file" })

  vim.api.nvim_create_user_command("ChapterNotesOpen", function()
    local file = vim.api.nvim_buf_get_name(0)
    if utils.is_chapter_file(file, state.config) then
      core.update_notes_for_current_buffer()
      vim.notify("The note window has been opened", vim.log.levels.INFO)
    else
      vim.notify("Currently not a chapter file", vim.log.levels.WARN)
    end
  end, { desc = "Open a note window for the current file" })
  
  vim.api.nvim_create_user_command("ChapterNotesClose", function()
    core.close_notes_windows()
    vim.notify("The note window has been closed", vim.log.levels.INFO)
  end, { desc = "Close all note windows" })
end

-- 设置默认快捷键
function M.setup_keymaps()
  local opts = { silent = true, noremap = true }
  
  -- 只有在有配置的情况下才设置默认快捷键
  if state.config.default_keymaps then
    vim.keymap.set('n', state.config.toggle_keymap, '<cmd>ChapterNotesToggle<CR>', opts)
    vim.keymap.set('n', state.config.sync_keymap, '<cmd>ChapterNotesSync<CR>', opts)
    vim.keymap.set('n', state.config.status_keymap, '<cmd>ChapterNotesStatus<CR>', opts)
  end
end

-- 获取插件状态
function M.get_state()
  return {
    initialized = state.initialized,
    config = state.config
  }
end

-- 重新加载插件
function M.reload()
  state.initialized = false
  core.cleanup()
  vim.notify("Chapter Notes have been reloaded", vim.log.levels.INFO)
end

return M
