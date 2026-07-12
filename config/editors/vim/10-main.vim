" Description of some config for vim in .vimrc

" ===
" === Vim-plug
" ===
" Plugins will be downloaded under the specified directory.

" ===
" === UI config
" ===
syntax enable
syntax on
set nocompatible	" not for vi
set number	" number the line
set showmatch	" highlight matching {}[]()
set novisualbell	" no flashbell
set noeb	" no errorbell
set sc		" show command
set gdefault	" do with the whole line by defualt
set cul	" show cursorline of the current line
set autoread	" autoread reload the file while changed
set encoding=utf-8	" encoding utf-8

" ===
" === mapping
" ===
nnoremap <Space> <NOP>
let mapleader = "'"
nnoremap <C-j> 5j
nnoremap <C-k> 5k
vnoremap <C-j> 5j
vnoremap <C-k> 5k
nnoremap j gj
nnoremap k gk
noremap <leader>w <C-w><C-w>

" ===
" === space&tabs
" ===
set tabstop=8	" visual space per tab reading a <tab>
set softtabstop=0	" number of spaces in tab when editing
set expandtab
set shiftwidth=2 smarttab

" ===
" === search
" ===
set hls	" higlight the research
set is	" keyword research
set ignorecase " ignore capital case when searching
set smartcase " let vim judge your case to search

" ===
" === others
" ===
set completeopt=preview,menu	" complete the code
filetype plugin indent on	" plugins on
set magic	" regex magic on
set autowrite	" autosave
set backspace=indent,eol,start	" backspace delete the chr befor cursor
autocmd BufRead,BufNewFile *.t set filetype=fortran
autocmd BufRead,BufNewFile *.par set filetype=fortran
let fortran_free_source=1
let fortran_extended_line_length=1
let fortran_CUDA=1
let fortran_have_tabs=1

" ===
" === folder
" ===
set foldenable	" enable the code fold
nnoremap <F2> za		" <space> open/close folds

" ===
" === codecompile
" ===
" makeprg compile the code with f5
map <F5> :call CompileRunGcc()<CR>
    func! CompileRunGcc()
        exec "w"
if &filetype == 'c'
            exec "!g++ % -o %<"
            exec "!time ./%<"
elseif &filetype == 'cpp'
            exec "!g++ % -o %<"
            exec "!time ./%<"
elseif &filetype == 'java'
            exec "!javac %"
            exec "!time java %<"
elseif &filetype == 'sh'
            :!time bash %
elseif &filetype == 'python'
            exec "!time python %"
elseif &filetype == 'html'
            exec "!firefox % &"
elseif &filetype == 'go'
    "        exec "!go build %<"
            exec "!time go run %"
elseif &filetype == 'mkd'
            exec "!~/.vim/markdown.pl % > %.html &"
            exec "!firefox %.html &"
endif
    endfunc
" ===
" === vim airline
" ===
let g:airline#extensions#tabline#left_sep = ' ' " seperate chr for buffer
let g:airline#extensions#tabline#enabled = 1

" ===
" === vim-fzf
" ===
map <leader>f :FZF<CR>

"===
"=== markdown-preview-config
"===
nmap <C-s> <Plug>MarkdownPreview

"===
"=== vim-markdown-config
"===
let g:vim_markdown_folding_disabled = 1	" no folding
let g:vim_markdown_math = 1	" latex syntax on
let g:vim_markdown_edit_url_in = 'tab'	" open target file in a new tab

"===
"=== vim-table-mode-config
"===
