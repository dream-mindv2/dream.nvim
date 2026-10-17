-- `:checkhealth dream`: what the plugin would start, and why it might not.
--
-- The failures that matter all look the same from inside the editor -- a
-- buffer with no diagnostics, or one where every line is red -- so this says
-- which it is: no VM, no image, or a server that cannot see `std`.

local M = {}

function M.check()
  local h = vim.health
  local dream = require('dream')
  local cfg = dream.config

  h.start('dream: the VM')
  local vm = vim.fn.expand(cfg.vm or 'dream')
  if vim.fn.executable(vm) == 1 then
    h.ok('`' .. vm .. '` is ' .. vim.fn.exepath(vm))
  else
    h.error('`' .. vm .. '` is not executable', { "Put the VM on $PATH, or pass `vm` to require('dream').setup()." })
  end

  h.start('dream: the language server')
  -- `:checkhealth` opens a buffer of its own, so the buffer worth asking about
  -- is the Dream file it was run from, if there is one.
  local buf = vim.iter(vim.api.nvim_list_bufs()):find(function(b)
    return vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype == 'dream'
  end)
  local root = buf and dream.root(buf) or vim.uv.cwd()
  h.info('project root' .. (buf and (' for ' .. vim.api.nvim_buf_get_name(buf)) or '') .. ': ' .. root)
  local server = dream.find_server(root)
  if server then
    h.ok('image: ' .. server)
    local cmd = dream.cmd(root)
    if cmd then h.info('command: ' .. table.concat(cmd, ' ')) end
  else
    h.error('no lucid.dream found', {
      'Build one with `just lucid` (build/lucid.dream in the checkout).',
      'Install one with `just install`, into $MINDV2_PATH or ~/.mindv2.',
      "Or name one: require('dream').setup({ server = '/path/to/lucid.dream' }).",
    })
  end

  local running = vim.lsp.get_clients({ name = 'lucid' })
  if #running > 0 then
    for _, c in ipairs(running) do h.ok('running: client ' .. c.id .. ' at ' .. (c.root_dir or '?')) end
  else
    h.info('no lucid client is running (open a .dr file)')
  end

  h.start('dream: the standard library')
  if cfg.stdlib then
    h.info('from setup(): ' .. cfg.stdlib)
  elseif vim.env.MIND_STDLIB then
    h.info('from $MIND_STDLIB: ' .. vim.env.MIND_STDLIB)
  else
    h.info('left to the server, which looks in the installation ($MINDV2_PATH, ~/.mindv2)')
  end
  h.info('If every `import std.x` is an error, the server cannot see std: '
    .. "set `stdlib` in setup() (to `mind` in the checkout, or ~/.mindv2 for an installation).")
end

return M
