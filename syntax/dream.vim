" Dream syntax, the Vim side of editors/vscode/syntaxes/dream.tmLanguage.json.
"
" The two are meant to say the same things, and the TextMate grammar's comments
" are where each rule's reasoning lives; when one changes, change both. Like that
" grammar this is a pile of regular expressions with no compiler behind it --
" the language server is what knows what a name means -- so where a word is
" contextual (`receive!`, `where`, `resource`, `out`) this is a reader's guess.

if exists('b:current_syntax')
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" The buffer's 'iskeyword' takes in `!` and `?` for motions; the keywords here
" are matched by pattern where they carry one, so syntax keeps the plain set.
syn iskeyword @,48-57,_,192-255

" --- names ----------------------------------------------------------------------

" A trailing `!` means impure, which is a real distinction in this language and
" worth seeing. First, so that every more specific rule below wins over it.
syn match dreamImpure "\<\h\w*!"

" The names the language provides without a module: the VM's builtin table.
syn match dreamBuiltin "\<\%(spawn\|join\|send\|recv\|self\|raise\|strict\)!"
syn keyword dreamBuiltin type_of to_string len

" --- keywords -------------------------------------------------------------------

" The parser's list (`keywords` in dreams/src/parser.dr), split by what each does.
syn keyword dreamConditional if else match
syn keyword dreamException catch
syn keyword dreamKeyword when not expand
syn match dreamException "\<try!"
syn match dreamException "\<defer!"
syn match dreamKeyword "\<comp!"
" Contextual: syntax only before a brace, and a function may still be called that.
syn match dreamKeyword "\<receive!\ze\s*{"
syn keyword dreamStorage priv rec virtual derive
syn keyword dreamKeyword fn comp mod as
syn keyword dreamInclude import
syn keyword dreamBoolean true false
" Refines a type. Contextual, so a reader's guess.
syn keyword dreamKeyword where

" The name a declaration introduces, so a definition stands out from a use.
" `resource` is a keyword only here, in front of the handle type it declares.
syn match dreamDeclare "\<\%(let?\|\%(let\|macro\|group\|struct\|mapping\|type\|union\|resource\)\>\)"
      \ nextgroup=dreamRec,dreamDeclName skipwhite
syn keyword dreamRec rec contained nextgroup=dreamDeclName skipwhite
syn match dreamDeclName "\h\w*!\?" contained

" A library's header: `foreign name from system "x" {`, or another image's,
" `image name from installed "x" {`. `from`, `system`, `installed` and
" `embedded` are keywords only here; `image` is one only when `from` follows.
syn keyword dreamDeclare foreign nextgroup=dreamForeignName skipwhite
syn match dreamDeclare "\<image\ze\s\+\h\w*\s\+from\>" nextgroup=dreamForeignName skipwhite
syn match dreamForeignName "\h\w*" contained nextgroup=dreamFrom skipwhite
syn match dreamFrom "\<from\%(\s\+\%(system\|installed\|embedded\)\>\)\?" contained

" A line that begins `name : type` declares that name: a function in a
" `foreign` block, or an annotated field of a record.
syn match dreamDeclName "^\s*\zs\h\w*!\?\ze\s*:\s"

" `out`, `borrow` and `taken` modify a C type after a signature's `:` or `->`.
syn match dreamCType "\%(->\|:\)\s*\zs\<\%(out\|borrow\|taken\)\ze\s\+[:A-Za-z_(]"

" --- literals -------------------------------------------------------------------

syn match dreamEscape "\\\%(u{\x\+}\|.\)" contained
syn region dreamString start=+"+ skip=+\\.+ end=+"+ contains=dreamEscape,@Spell
syn match dreamChar "'\%(\\\%(u{\x\+}\|.\)\|[^'\\]\)'"

" `$"..{expr}.."`: the braces hold code, which may itself hold braces.
syn region dreamInterp matchgroup=dreamString start=+\$"+ skip=+\\.+ end=+"+
      \ contains=dreamEscape,dreamInterpExpr
syn region dreamInterpExpr matchgroup=dreamInterpDelim start="{" end="}" contained
      \ contains=@dreamCode,dreamNested
syn region dreamNested start="{" end="}" contained transparent contains=@dreamCode,dreamNested

syn match dreamNumber "\<\d[0-9_]*\>"
syn match dreamNumber "\<0[xX][0-9A-Fa-f_]\+\>"
syn match dreamNumber "\<0[bB][01_]\+\>"
syn match dreamFloat "\<\d[0-9_]*\.\d[0-9_]*\%([eE][-+]\?\d\+\)\?\>"

" An atom is a colon and a name: :ok, :error. `::` is cons, and the lexer reads
" `::ok` as `::` then `ok`, so it is matched first and consumes both colons.
syn match dreamAtom ":\h\w*!\?"
syn match dreamOperator "::"

" --- operators and punctuation ---------------------------------------------------

" A comment starting at the same place is defined later, and so wins over `/`.
syn match dreamOperator "|>\|->\|=>\|==\|!=\|<=\|>=\|&&\|||\|[<>|+\-*/%@=]\|\.\."
syn match dreamSpecial "\$("
syn match dreamSpecial "%{"
syn match dreamSpecial "#\["

" --- comments -------------------------------------------------------------------

syn keyword dreamTodo TODO FIXME XXX NOTE contained
syn match dreamComment "//.*$" contains=dreamTodo,@Spell
syn match dreamDocComment "///.*$" contains=dreamTodo,@Spell
syn region dreamComment start="/\*" end="\*/" contains=dreamTodo,@Spell

syn cluster dreamCode contains=dreamImpure,dreamBuiltin,dreamConditional,dreamException,
      \dreamKeyword,dreamStorage,dreamInclude,dreamBoolean,dreamDeclare,dreamString,dreamChar,
      \dreamInterp,dreamNumber,dreamFloat,dreamAtom,dreamOperator,dreamSpecial,dreamComment

syn sync minlines=200

hi def link dreamImpure      Function
hi def link dreamBuiltin     Function
hi def link dreamConditional Conditional
hi def link dreamException   Exception
hi def link dreamKeyword     Keyword
hi def link dreamStorage     StorageClass
hi def link dreamInclude     Include
hi def link dreamBoolean     Boolean
hi def link dreamDeclare     Keyword
hi def link dreamRec         StorageClass
hi def link dreamDeclName    Function
hi def link dreamForeignName Function
hi def link dreamFrom        Keyword
hi def link dreamCType       StorageClass
hi def link dreamEscape      SpecialChar
hi def link dreamString      String
hi def link dreamInterp      String
hi def link dreamInterpDelim Delimiter
hi def link dreamChar        Character
hi def link dreamNumber      Number
hi def link dreamFloat       Float
hi def link dreamAtom        Constant
hi def link dreamOperator    Operator
hi def link dreamSpecial     Delimiter
hi def link dreamTodo        Todo
hi def link dreamComment     Comment
hi def link dreamDocComment  SpecialComment

let b:current_syntax = 'dream'

let &cpo = s:cpo_save
unlet s:cpo_save
