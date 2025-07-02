" Set the leader
let mapleader=","

set nocompatible  " Use Vim settings, rather then Vi settings

" General config
set history=1000		" big phat history
set ruler         	" show the cursor position all the time
set showcmd       	" display incomplete commands
set incsearch     	" do incremental searching
set laststatus=2  	" Always display the status line
set number        	" Line numbers are good
set gdefault      	" subtitutions globally on lines
set showmode        " Show current mode down the bottom
set gcr=a:blinkon0  " Disable cursor blink
set visualbell      " No sounds
set autoread        " Reload files changed outside vim
set hidden					" buffer can exist in background
set mouse=          " disable mouse
set modeline
set modelines=1

set fillchars=stl:─,stlnc:─,vert:│,fold:·,diff:- " for split style

" Turn off swap files
set nobackup
set nowritebackup
set noswapfile

" completion
set wildmode=list:longest
set wildmenu                "enable ctrl-n and ctrl-p to scroll thru matches
set wildignore=*.o,*.obj,*~ "stuff to ignore when tab completing
set wildignore+=*vim/backups*
set wildignore+=*sass-cache*
set wildignore+=*DS_Store*
set wildignore+=vendor/rails/**
set wildignore+=vendor/cache/**
set wildignore+=*.gem
set wildignore+=log/**
set wildignore+=tmp/**
set wildignore+=*.png,*.jpg,*.gif

" for mark
nnoremap ` '

" Left insert mode
inoremap jj <ESC>

"" fold
set foldmethod=indent   "fold based on indent
set foldnestmax=3       "deepest fold is 3 levels
set nofoldenable        "dont fold by default

" Easy split navigation
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Vertical resize shortcuts
nnoremap <silent> <Leader>[ :exe "vertical resize " . (winwidth(0) * 3/4)<CR>
nnoremap <silent> <Leader>] :exe "vertical resize " . (winwidth(0) * 4/3)<CR>
nnoremap <silent> <Leader>- :exe "resize " . (winheight(0) * 2/3)<CR>
nnoremap <silent> <Leader>= :exe "resize " . (winheight(0) * 3/2)<CR>

" Open new split and focus on it
nnoremap <leader>w <C-w>v<C-w>l

" Reselect paste line
nnoremap <leader>v V`]

" Display extra whitespace
"set list listchars=tab:»·,trail:·

" Switch syntax highlighting on, when the terminal has colors
" Also switch on highlighting the last used search pattern.
if (&t_Co > 2 || has("gui_running")) && !exists("syntax_on")
  syntax on
endif

" Tab completion
" will insert tab at beginning of line,
" will use completion if not at beginning
set wildmode=list:longest,list:full
set complete=.,w,t
function! InsertTabWrapper()
    let col = col('.') - 1
    if !col || getline('.')[col - 1] !~ '\k'
        return "\<tab>"
    else
        return "\<c-p>"
    endif
endfunction
inoremap <Tab> <c-r>=InsertTabWrapper()<cr>

augroup vimrcEx
  au!

  " For all text files set 'textwidth' to 78 characters.
  autocmd FileType text setlocal textwidth=78

  " When editing a file, always jump to the last known cursor position.
  " Don't do it for commit messages, when the position is invalid, or when
  " inside an event handler (happens when dropping a file on gvim).
  autocmd BufReadPost *
    \ if &ft != 'gitcommit' && line("'\"") > 0 && line("'\"") <= line("$") |
    \   exe "normal g`\"" |
    \ endif
augroup END

" Keep undo
silent !mkdir ~/.vim/backups > /dev/null 2>&1
set undodir=~/.vim/backups
set undofile

" For plugins
if filereadable(expand("~/.vimrc.bundles"))
  source ~/.vimrc.bundles
endif

colors new-railscasts

" Softtabs, 2 spaces
set autoindent
set smartindent
set smarttab
set shiftwidth=2
set softtabstop=2
set tabstop=2
set expandtab
set backspace=2

filetype plugin on
filetype indent on

"" Ctags
" Index ctags from any project, including those outside Rails
map <Leader>ct :!ctags -R .<CR>

" quick ctags
nnoremap <leader>a :Ack

" configure syntastic syntax checking to check on open as well as save
let g:syntastic_check_on_open=1

" vim-rspec
let g:rspec_command = "Dispatch bundle exec ./bin/rspec {spec}"
let g:rspec_runner = "os_x_iterm"

" vim-rspec mappings
nnoremap <Leader>t :call RunCurrentSpecFile()<CR>
nnoremap <Leader>s :call RunNearestSpec()<CR>
nnoremap <Leader>l :call RunLastSpec()<CR>

nnoremap <Leader>k :AV<CR>

" Use Ag (https://github.com/ggreer/the_silver_searcher) instead of Grep when
" available
if executable("ag")
  set grepprg=ag\ --nogroup\ --nocolor
endif

" Treat <li> and <p> tags like the block tags they are
let g:html_indent_tags = 'li\|p'

"" Markdown
" Set syntax highlighting for specific file types
au BufRead,BufNewFile *.md set filetype=markdown

" Automatically wrap at 80 characters for Markdown
au BufRead,BufNewFile *.md setlocal textwidth=80

" Finally, local config
if filereadable($HOME . "/.vimrc.local")
  source ~/.vimrc.local
endif

autocmd BufWritePre * :%s/\s\+$//e

nnoremap <C-p> :Unite file_rec/async<cr>
nnoremap <leader>d :Dash<cr>

" Syntastic
let g:syntastic_scss_checkers = [ 'sasslint' ]
let g:syntastic_sass_checkers = [ 'sasslint' ]
let g:sass_lint_config = '~/.sass-lint.yml'

" Syntastic + Angular.js
let g:syntastic_html_tidy_ignore_errors=["proprietary attribute \"", "<form> lacks \"action\" attribute", "discarding unexpected", "is not recognized!", "trimming empty <i>", "discarding unexpected </"]
let g:used_javascript_libs = 'jquery,angularjs'
let g:syntastic_javascript_checkers = ['jshint']
" let g:syntastic_ruby_checkers = ['flog']

imap ,/ </<C-X><C-O><ESC>x

autocmd VimResized * :normal =

let g:slime_target = "tmux"

" Dash
nmap <silent> <leader>d <Plug>DashSearch

nnoremap <Leader>c :tabclose<cr>

nnoremap sb obinding.pry<cr><esc>
nnoremap sf O# frozen_string_literal: true<cr><esc>ddO<esc>
nnoremap sjson oprint JSON.pretty_generate(JSON.parse(response.body))<cr><esc>

" Emmet
let g:user_emmet_leader_key='<C-y>'
let g:user_emmet_install_global = 1

" Templates
if has("autocmd")
  augroup templates
    autocmd BufNewFile *_spec.rb  0r ~/dotfiles/vim/templates/skeleton_spec.rb

    autocmd BufNewFile * %substitute#\[:VIM_EVAL:\]\(.\{-\}\)\[:END_EVAL:\]#\=eval(submatch(1))#ge
  augroup END
endif

" vim-gist
let g:gist_post_private = 1
let g:gist_clip_command = 'pbcopy'

" CoC
let g:coc_global_extensions = [
  \ 'coc-css',
  \ 'coc-eslint',
  \ 'coc-json',
  \ 'coc-html',
  \ 'coc-markdownlint',
  \ 'coc-pairs',
  \ 'coc-prettier',
  \ 'coc-stylelintplus',
  \ 'coc-sql',
  \ 'coc-yaml',
  \ ]

nmap <silent> qf <Plug>(coc-fix-current)
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

autocmd BufWritePre *.rb :call CocAction('format')

hi CocFloating ctermbg=255 ctermfg=black
