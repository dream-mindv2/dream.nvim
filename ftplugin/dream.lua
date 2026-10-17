if vim.b.did_ftplugin then return end
vim.b.did_ftplugin = true

vim.bo.commentstring = '// %s'
vim.bo.comments = 's1:/*,mb:*,ex:*/,:///,://'
-- `!` ends an impure name and `?` ends `let?`; both are part of the word, so
-- `*` on `print!` finds `print!` and not every `print`.
vim.opt_local.iskeyword:append({ '!', '?' })
vim.bo.expandtab = true
vim.bo.shiftwidth = 4
vim.bo.softtabstop = 4
-- A `/// ` comment continues as one; `gq` wraps prose comments, while `=` and
-- formatting through the server (`vim.lsp.buf.format()`) lay out code.
vim.opt_local.formatoptions:remove('t')
vim.opt_local.formatoptions:append('cqrj')

vim.b.undo_ftplugin = 'setl cms< com< isk< et< sw< sts< fo<'
