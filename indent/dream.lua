-- Indentation by brackets, as the VS Code extension's language configuration
-- does it: a line after one that left a bracket open goes in a level, and a
-- line that starts by closing one comes back out. The house style is the
-- formatter's (dreams/src/fmt.dr), which the server runs for `vim.lsp.buf.format()`;
-- this is only for the line being typed.

if vim.b.did_indent then return end
vim.b.did_indent = true

-- Brackets in strings, characters and comments do not count. Strings are
-- dropped before comments, so a `//` inside one is not taken for a comment.
local function code_of(line)
  line = line:gsub('\\.', '')
  line = line:gsub('"[^"]*"', '""')
  line = line:gsub("'[^']*'", "''")
  line = line:gsub('//.*$', '')
  line = line:gsub('/%*.-%*/', '')
  return line
end

local function depth(line)
  local d = 0
  for c in code_of(line):gmatch('[%[%]{}()]') do
    if c == '{' or c == '[' or c == '(' then d = d + 1 else d = d - 1 end
  end
  return d
end

function _G.DreamIndent(lnum)
  local prev = vim.fn.prevnonblank(lnum - 1)
  if prev == 0 then return 0 end
  local prev_line = vim.fn.getline(prev)
  local ind = vim.fn.indent(prev)
  local sw = vim.fn.shiftwidth()

  -- What the previous line opened and did not close. A line that starts by
  -- closing (`}` or `} else {`) was already dedented itself, so its leading
  -- closers are not counted against the line after it.
  local leading = #(prev_line:match('^%s*([%]}%)]*)') or '')
  if depth(prev_line) + leading > 0 then ind = ind + sw end

  if vim.fn.getline(lnum):match('^%s*[%]}%)]') then ind = ind - sw end
  return math.max(ind, 0)
end

vim.bo.indentexpr = 'v:lua.DreamIndent(v:lnum)'
vim.bo.indentkeys = '0{,0},0),0],!^F,o,O,e'
vim.bo.autoindent = true

vim.b.undo_indent = 'setl inde< indk< ai<'
