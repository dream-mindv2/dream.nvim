-- The Neovim side of `lucid`.
--
-- As with the VS Code extension, there is deliberately almost nothing here.
-- Diagnostics, definitions, hover, the outline, completion, rename and
-- formatting are all answered by the language server out of the compiler's own
-- tables; anything this file computed itself would be a second opinion about a
-- program the compiler has already read. Its job is to find the server, start
-- it once per project, and get out of the way.

local M = {}

local defaults = {
  -- The VM. `lucid` is a compiled image rather than a native program, so the
  -- VM is what is actually started.
  vm = 'dream',
  -- The `lucid.dream` image. Nil means look for one (`M.find_server`).
  server = nil,
  -- Extra package roots, passed as `-L`. The project root is always one.
  package_paths = {},
  -- The directory holding `std`. Nil leaves it to the server, which reads
  -- `$MIND_STDLIB` and then the installation.
  stdlib = nil,
  -- Start the server for every Dream buffer. False leaves it to the caller,
  -- through `require('dream').start()`.
  autostart = true,
  -- Handed to `vim.lsp.start` as they are: `capabilities`, `on_attach`,
  -- `settings` and anything else a client config takes.
  lsp = {},
}

M.config = vim.deepcopy(defaults)

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})
end

--- A path from a setting may be written for a human: `~` and `$HOME` mean what
--- they mean in a shell. Iterated, because `$MINDV2_PATH` might itself be
--- written as `~/.mindv2`.
local function expand(s)
  if not s or s == '' then return s end
  for _ = 1, 3 do
    local before = s
    s = s:gsub('%${(%w+)}', function(v) return vim.env[v] end)
    s = s:gsub('%$(%w+)', function(v) return vim.env[v] end)
    s = s:gsub('^~(/?)', function(slash) return vim.env.HOME .. slash end)
    if s == before then break end
  end
  return s
end

local function exists(p)
  return p and p ~= '' and vim.uv.fs_stat(p) ~= nil
end

--- The project a buffer belongs to, which is what a server is started for.
---
--- A `mind.toml` with `[workspace]` wins over a nearer manifest, because a
--- workspace's members import one another, and a server rooted at one member
--- reports every import of a sibling as an error. Failing that it is the
--- nearest manifest, then the repository, then the file's own directory -- a
--- lone file is still a program.
function M.root(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr or 0)
  if name == '' then return vim.uv.cwd() end
  name = vim.fs.normalize(vim.fn.fnamemodify(name, ':p'))
  local dir = vim.fs.dirname(name)

  for manifest in vim.iter(vim.fs.find('mind.toml', { path = dir, upward = true, limit = math.huge })) do
    local f = io.open(manifest)
    if f then
      local text = f:read('*a')
      f:close()
      if text:find('^%s*%[workspace%]') or text:find('\n%s*%[workspace%]') then
        return vim.fs.dirname(manifest)
      end
    end
  end

  return vim.fs.root(name, 'mind.toml') or vim.fs.root(name, '.git') or dir
end

--- Where the server image might be, in the order worth trying: the setting, a
--- build in the project (so the Dream checkout runs the server it just built,
--- not an installed one), `$LUCID_IMAGE`, `$MINDV2_PATH`, and last whatever
--- the VM says its installation is -- which finds it even when the editor was
--- not started with `$MINDV2_PATH` set, as under the Nix flake's wrapped
--- `dream`.
function M.find_server(root)
  local cfg = M.config
  local configured = expand(cfg.server)
  if exists(configured) then return configured end

  local candidates = {}
  if root then
    table.insert(candidates, vim.fs.joinpath(root, 'build', 'lucid.dream'))
    table.insert(candidates, vim.fs.joinpath(root, 'build-dream', 'bin', 'lucid.dream'))
  end
  if vim.env.LUCID_IMAGE then table.insert(candidates, expand(vim.env.LUCID_IMAGE)) end

  local function installation(dir)
    dir = expand(dir)
    table.insert(candidates, vim.fs.joinpath(dir, 'lucid.dream'))
    table.insert(candidates, vim.fs.joinpath(dir, 'lucid'))
  end
  if vim.env.MINDV2_PATH then
    for dir in vim.gsplit(vim.env.MINDV2_PATH, ':', { plain = true, trimempty = true }) do
      installation(dir)
    end
  end

  -- A VM too old to know the flag, or missing entirely, adds nothing; the
  -- later spawn failure is then a real message instead of a silent nothing.
  local vm = expand(cfg.vm) or 'dream'
  if vim.fn.executable(vm) == 1 then
    local ok, out = pcall(function()
      return vim.system({ vm, '--mindv2-path' }, { text = true }):wait(2000)
    end)
    if ok and out and out.code == 0 and out.stdout then
      for dir in vim.gsplit(vim.trim(out.stdout), ':', { plain = true, trimempty = true }) do
        installation(dir)
      end
    end
  end

  for _, c in ipairs(candidates) do
    if exists(c) then return c end
  end
  return nil
end

--- The command line the server is started with: `dream lucid.dream -L ...`.
function M.cmd(root)
  local cfg = M.config
  local server = M.find_server(root)
  if not server then return nil end
  -- An image is only as good as the VM it was built for: the checkout's
  -- `build/lucid.dream` names builtins an installed VM may not have yet
  -- ("unknown builtin id"). So when the server is the project's own build and
  -- the project has built a VM beside it, that VM runs it, unless `vm` was set.
  local vm = expand(cfg.vm) or 'dream'
  local local_vm = root and vim.fs.joinpath(root, 'build-dream', 'bin', 'dream')
  if vm == defaults.vm and root and vim.startswith(server, root .. '/')
      and local_vm and vim.fn.executable(local_vm) == 1 then
    vm = local_vm
  end
  local cmd = { vm, server }
  local roots = { root }
  vim.list_extend(roots, cfg.package_paths or {})
  if cfg.stdlib then table.insert(roots, cfg.stdlib) end
  for _, r in ipairs(roots) do
    vim.list_extend(cmd, { '-L', expand(r) })
  end
  return cmd
end

local warned = false

--- Start (or reuse) the server for a buffer. `vim.lsp.start` reuses a client
--- with the same name and root, so this is one server per project however many
--- of its files are open.
function M.start(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local root = M.root(bufnr)
  local cmd = M.cmd(root)
  if not cmd then
    if not warned then
      warned = true
      vim.notify(
        'dream: no language server image found. Build one with `just lucid`, '
          .. 'install it with `just install`, or pass `server` to '
          .. "require('dream').setup(). `:checkhealth dream` says what was tried.",
        vim.log.levels.WARN
      )
    end
    return nil
  end
  if vim.fn.executable(cmd[1]) ~= 1 then
    if not warned then
      warned = true
      vim.notify('dream: the VM `' .. cmd[1] .. '` is not executable; set `vm` in setup().', vim.log.levels.ERROR)
    end
    return nil
  end

  local config = vim.tbl_deep_extend('force', {
    name = 'lucid',
    cmd = cmd,
    root_dir = root,
    workspace_folders = { { uri = vim.uri_from_fname(root), name = root } },
  }, M.config.lsp or {})
  return vim.lsp.start(config, { bufnr = bufnr })
end

local function clients()
  return vim.lsp.get_clients({ name = 'lucid' })
end

--- Stop every lucid and start them again for the open Dream buffers, which is
--- how a rebuilt image is picked up: `just lucid` after changing the language,
--- or new syntax reads as a parse error.
function M.restart()
  for _, c in ipairs(clients()) do c:stop(true) end
  vim.defer_fn(function()
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype == 'dream' then M.start(b) end
    end
  end, 200)
end

function M.stop()
  for _, c in ipairs(clients()) do c:stop() end
end

return M
