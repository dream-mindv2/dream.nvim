-- The plugin, checked in a headless Neovim against a real server.
--
--   nvim --headless --clean --cmd 'set rtp^=editors/nvim' -l editors/nvim/test/run.lua
--
-- from the root of the checkout, with build/lucid.dream built (`just lucid`)
-- and the VM in $DREAM or on PATH. `just test-nvim` is that. It asks what a
-- user would notice first: that a `.dr` file is Dream, that it is coloured,
-- that the server starts and attaches, and that it answers -- a diagnostic for
-- a broken buffer, a hover for a name.

local failures = 0
local function check(ok, what)
  if ok then
    print('ok   ' .. what)
  else
    failures = failures + 1
    print('FAIL ' .. what)
  end
end

local root = vim.uv.cwd()
-- A workspace with the program in one of its members: the server must be
-- rooted at the workspace, where the members can see one another, and not at
-- the member's own manifest.
local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp .. '/app', 'p')
vim.fn.writefile({ '[workspace]', 'name = "ws"', 'members = ["app"]' }, tmp .. '/mind.toml')
vim.fn.writefile({ '[package]', 'name = "app"', 'version = "0.1.0"', 'src = "."' }, tmp .. '/app/mind.toml')
local file = tmp .. '/app/app.dr'
vim.fn.writefile({
  'import std.console;',
  '',
  '/// Twice what it is given.',
  'let double n = n * 2;',
  '',
  'let main! = {',
  '    console.print! (to_string (double 21))',
  '};',
  'let greet n = $"hi {to_string n}";',
}, file)

-- The plugin directory is on 'runtimepath', but `-l` runs before plugin/ and
-- ftdetect/ are sourced, so do here what startup would have.
vim.cmd('runtime! plugin/dream.lua')
vim.cmd('runtime! ftdetect/dream.lua')
require('dream').setup({
  vm = vim.env.DREAM or 'dream',
  server = root .. '/build/lucid.dream',
  stdlib = root .. '/mind',
})

vim.cmd('syntax on')
vim.cmd('filetype plugin indent on')
vim.cmd('edit ' .. file)
check(vim.bo.filetype == 'dream', 'a .dr file is filetype dream')
check(vim.bo.commentstring == '// %s', 'the ftplugin ran')
check(vim.bo.indentexpr ~= '', 'the indent script ran')

local function group_at(line, col)
  local id = vim.fn.synID(line, col, 1)
  return vim.fn.synIDattr(vim.fn.synIDtrans(id), 'name'), vim.fn.synIDattr(id, 'name')
end
local _, g = group_at(1, 1)
check(g == 'dreamInclude', '`import` is highlighted (' .. g .. ')')
_, g = group_at(3, 1)
check(g == 'dreamDocComment', '`///` is a doc comment (' .. g .. ')')
_, g = group_at(4, 5)
check(g == 'dreamDeclName', 'the name a `let` declares stands out (' .. g .. ')')
_, g = group_at(7, 13)
check(g == 'dreamImpure', '`print!` is impure (' .. g .. ')')
_, g = group_at(7, 21)
check(g == 'dreamBuiltin', '`to_string` is a builtin (' .. g .. ')')
_, g = group_at(9, 20)
check(g == 'dreamInterpDelim', 'an interpolation opens in a string (' .. g .. ')')
_, g = group_at(9, 21)
check(g == 'dreamBuiltin', 'and holds code (' .. g .. ')')

-- Indentation: inside the block, and back out at its close.
check(DreamIndent(7) == 4, 'a line inside `{` is indented')
check(DreamIndent(8) == 0, 'a line closing `}` comes back out')

local attached = vim.wait(20000, function()
  return #vim.lsp.get_clients({ bufnr = 0, name = 'lucid' }) > 0
end, 100)
check(attached, 'lucid attaches to the buffer')

if attached then
  local client = vim.lsp.get_clients({ bufnr = 0, name = 'lucid' })[1]
  check(client.root_dir == tmp, 'the root is the workspace, not the member (' .. tostring(client.root_dir) .. ')')

  -- Hover on `double`, the use on line 7.
  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  params.position = { line = 6, character = 31 }
  local reply = client:request_sync('textDocument/hover', params, 20000, 0)
  local text = reply and reply.result and vim.inspect(reply.result.contents) or ''
  check(text:find('double') ~= nil, 'hover answers for a name: ' .. text:sub(1, 60):gsub('\n', ' '))

  -- A broken buffer: an unbound name is reported, without saving.
  vim.api.nvim_buf_set_lines(0, 6, 7, false, { '    console.print! (to_string (tripple 21))' })
  local got = vim.wait(20000, function() return #vim.diagnostic.get(0) > 0 end, 100)
  check(got, 'an unsaved mistake is a diagnostic')

  -- And fixed, it is withdrawn.
  vim.api.nvim_buf_set_lines(0, 6, 7, false, { '    console.print! (to_string (double 21))' })
  local cleared = vim.wait(20000, function() return #vim.diagnostic.get(0) == 0 end, 100)
  check(cleared, 'the diagnostic goes when the mistake does')
end

for _, c in ipairs(vim.lsp.get_clients({ name = 'lucid' })) do c:stop(true) end
vim.fn.delete(tmp, 'rf')
print(failures == 0 and 'all passed' or (failures .. ' failed'))
os.exit(failures == 0 and 0 or 1)
