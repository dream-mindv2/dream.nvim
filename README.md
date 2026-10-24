# Dream for Neovim

Dream support for Neovim (0.11 or later): a filetype, syntax highlighting,
indentation, and everything else from [`lucid`](https://github.com/dream-mindv2/lucid/blob/main/README.md), the
language server -- which is the Dream compiler, answering the editor out of the
tables it builds to compile.

Through Neovim's own LSP client, with nothing else installed:

- **Diagnostics** as you type, in the words a build gives, because they are the
  same errors.
- **Go to definition** (`gd` if you map it, `<C-]>` by default), across files and packages.
- **Hover** (`K`): what a name resolved to, and which module it came from.
- **Outline** (`gO`): what a file declares.
- **Completion** (`<C-x><C-o>`, or any completion plugin): a module's members
  after a `.`, and everything in scope elsewhere.
- **Rename** (`grn`), **format** (`vim.lsp.buf.format()`, the house style of
  `dreams/src/fmt.dr`) and **inlay hints** (`vim.lsp.inlay_hint.enable()`).

The server reads the buffer rather than the file on disk, so all of this works
on code you have not saved.

## Installing

You need the VM on your `PATH` and a built server image. `just install` in
the [Dream workspace](https://github.com/Custards1/dream) puts both in place (`~/.mindv2`; put
`~/.mindv2/bin` on your `PATH`). Then add this plugin to Neovim:

```lua
-- lazy.nvim
{ 'dream-mindv2/dream.nvim', ft = 'dream', opts = {} }

-- or from a checkout, by hand, in init.lua
vim.opt.runtimepath:append('/path/to/dream.nvim')
require('dream').setup({})
```

`setup` is optional: with no call, the defaults below apply.

## Finding the server

`lucid` is an image, not a native program, so the plugin starts it as
`dream lucid.dream -L <root>` and speaks LSP to it over stdin and stdout. It
takes the first `lucid.dream` it finds -- the same order as the VS Code
extension:

1. `server`, when it is set;
2. `build/lucid.dream` (or `build-dream/bin/lucid.dream`) under the project
   root, when that root is one `trusted` names -- so the Dream checkout runs
   the server it just built, not an installed one;
3. `$LUCID_IMAGE`;
4. `$MINDV2_PATH/lucid.dream`;
5. wherever the VM says the installation is (`dream --mindv2-path`), which
   finds it even when Neovim was not started with `$MINDV2_PATH` set -- as
   under the Nix flake's wrapped `dream`.

When the image is the project's own build and `build-dream/bin/dream` is
beside it, that VM runs it rather than the one on `PATH` (unless `vm` is set):
an image built from the checkout can name builtins an installed VM does not
have yet, and fails with `unknown builtin id`.

**A project's own builds run only if you trust it.** They are programs the
project supplies -- a cloned repository can put anything at
`build-dream/bin/dream` -- and opening one of its files must not run them. So
steps 2 and the VM beside it apply only to a root listed in `trusted`; the
Dream checkout is the usual one:
`require('dream').setup({ trusted = { '~/src/dream' } })`.

**The project root** is the outermost `mind.toml` that declares a
`[workspace]`, then the nearest `mind.toml`, then the repository, then the
file's directory. The workspace wins because its members import one another;
a server rooted at one member would call every sibling import an error. One
server runs per root.

`:DreamRestart` picks up a rebuilt image, and writing a `mind.toml` does it by
itself. Rebuild the image with `just lucid` after changing the language:
`just` alone does not, and new syntax shows as a parse error until you do.
`:DreamStart` and `:DreamStop` are the rest.

## Settings

```lua
require('dream').setup({
  vm = 'dream',           -- the VM
  server = nil,           -- the lucid.dream to run; found as above when nil
  package_paths = {},     -- extra package roots, passed as -L
  stdlib = nil,           -- the directory holding std; nil leaves it to the server
  trusted = {},           -- project roots whose own builds may be run
  autostart = true,       -- start for every Dream buffer
  lsp = {},               -- merged into the vim.lsp.start config: on_attach, capabilities, ...
})
```

`~` and `$VARS` are expanded in every path.

**If every file is suddenly red**, the server cannot see the standard library:
every `import std.x` is an error, which looks like a broken plugin rather than a
missing setting. With `stdlib` unset the server reads `$MIND_STDLIB` and then
the installation; set it to `mind` in the checkout, or `~/.mindv2`.
`:checkhealth dream` says which VM, image, root and command it would use.

## Developing

`syntax/dream.vim` says what [vscode-dream](https://github.com/dream-mindv2/vscode-dream)'s `syntaxes/dream.tmLanguage.json`
says, rule for rule; the reasoning for each rule is in that grammar's comments.
Change both together.

```
just test-nvim    # in the workspace: a headless Neovim against build/lucid.dream
```

`test/run.lua` opens a file in a workspace member and checks the filetype,
a handful of highlight groups and indents, that `lucid` attaches at the
workspace root, that hover answers, and that an unsaved mistake becomes a
diagnostic and goes away when fixed. It is not part of `just test`, because it
needs Neovim and nothing else in the suite needs anything from outside the
repository.
