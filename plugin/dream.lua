-- Starts `lucid` for Dream buffers and gives it commands. Configuration is
-- `require('dream').setup{}` (lua/dream/init.lua), which may come before or
-- after this runs: nothing here reads the configuration until a buffer opens.

if vim.g.loaded_dream then return end
vim.g.loaded_dream = true

local group = vim.api.nvim_create_augroup('dream', { clear = true })

vim.api.nvim_create_autocmd('FileType', {
  group = group,
  pattern = 'dream',
  callback = function(ev)
    local dream = require('dream')
    if dream.config.autostart and vim.bo[ev.buf].buftype == '' then dream.start(ev.buf) end
  end,
})

-- A manifest decides which packages a file can see, so writing one changes what
-- every open file means. The server reads manifests when it starts, so this is
-- a restart rather than a notification.
vim.api.nvim_create_autocmd('BufWritePost', {
  group = group,
  pattern = 'mind.toml',
  callback = function()
    if #vim.lsp.get_clients({ name = 'lucid' }) > 0 then require('dream').restart() end
  end,
})

vim.api.nvim_create_user_command('DreamRestart', function() require('dream').restart() end,
  { desc = 'Restart the Dream language server' })
vim.api.nvim_create_user_command('DreamStop', function() require('dream').stop() end,
  { desc = 'Stop the Dream language server' })
vim.api.nvim_create_user_command('DreamStart', function() require('dream').start() end,
  { desc = 'Start the Dream language server for this buffer' })
