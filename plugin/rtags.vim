if !exists("g:rtagsRcCmd")
    let g:rtagsRcCmd = "rc"
endif

if !exists("g:rtagsRdmCmd")
    let g:rtagsRdmCmd = "rdm"
endif

if !exists("g:rtagsAutoLaunchRdm")
    let g:rtagsAutoLaunchRdm = 0
endif

if !exists("g:rtagsJumpStackMaxSize")
    let g:rtagsJumpStackMaxSize = 100
endif

if !exists("g:rtagsExcludeSysHeaders")
    let g:rtagsExcludeSysHeaders = 0
endif

let g:rtagsJumpStack = []

if !exists("g:rtagsUseLocationList")
    let g:rtagsUseLocationList = 1
endif

if !exists("g:rtagsUseGlobalMappings")
    let g:rtagsUseGlobalMappings = 1
endif

if !exists("g:rtagsMinCharsForCommandCompletion")
    let g:rtagsMinCharsForCommandCompletion = 4
endif

if !exists("g:rtagsMaxSearchResultWindowHeight")
    let g:rtagsMaxSearchResultWindowHeight = 10
endif

if g:rtagsAutoLaunchRdm
    call system(g:rtagsRcCmd." -w")
    if v:shell_error != 0 
        call system(g:rtagsRdmCmd." --daemon > /dev/null")
    end
end

let g:SAME_WINDOW = 'same_window'
let g:H_SPLIT = 'hsplit'
let g:V_SPLIT = 'vsplit'
let g:NEW_TAB = 'tab'

if g:rtagsUseGlobalMappings == 1
  nnoremap <Leader>ri :call rtags#SymbolInfo()<CR>
  nnoremap <Leader>rj :call rtags#JumpTo(g:SAME_WINDOW)<CR>
  nnoremap <Leader>rJ :call rtags#JumpTo(g:SAME_WINDOW, { '--declaration-only' : '' })<CR>
  nnoremap <Leader>rS :call rtags#JumpTo(g:H_SPLIT)<CR>
  nnoremap <Leader>rV :call rtags#JumpTo(g:V_SPLIT)<CR>
  nnoremap <Leader>rT :call rtags#JumpTo(g:NEW_TAB)<CR>
  nnoremap <Leader>rp :call rtags#JumpToParent()<CR>
  nnoremap <Leader>rf :call rtags#FindRefs()<CR>
  nnoremap <Leader>rn :call rtags#FindRefsByName(input("Pattern? ", "", "customlist,rtags#CompleteSymbols"))<CR>
  nnoremap <Leader>rs :call rtags#FindSymbols(input("Pattern? ", "", "customlist,rtags#CompleteSymbols"))<CR>
  nnoremap <Leader>rr :call rtags#ReindexFile()<CR>
  nnoremap <Leader>rl :call rtags#ProjectList()<CR>
  nnoremap <Leader>rw :call rtags#RenameSymbolUnderCursor()<CR>
  nnoremap <Leader>rv :call rtags#FindVirtuals()<CR>
  nnoremap <Leader>rb :call rtags#JumpBack()<CR>
  nnoremap <Leader>rC :call rtags#FindSuperClasses()<CR>
  nnoremap <Leader>rc :call rtags#FindSubClasses()<CR>
  nnoremap <Leader>rd :call rtags#Diagnostics()<CR>
  if &completefunc == ""
    set completefunc=rtags#RtagsCompleteFunc
  endif
endif

command -nargs=1 -complete=customlist,rtags#CompleteSymbols RtagsFindSymbols call rtags#FindSymbols(<q-args>)
command -nargs=1 -complete=customlist,rtags#CompleteSymbols RtagsFindRefsByName call rtags#FindRefsByName(<q-args>)

command -nargs=1 -complete=customlist,rtags#CompleteSymbols RtagsIFindSymbols call rtags#IFindSymbols(<q-args>)
command -nargs=1 -complete=customlist,rtags#CompleteSymbols RtagsIFindRefsByName call rtags#IFindRefsByName(<q-args>)

command -nargs=1 -complete=dir RtagsLoadCompilationDb call rtags#LoadCompilationDb(<q-args>)

" The most commonly used find operation
command -nargs=1 -complete=customlist,rtags#CompleteSymbols Rtag RtagsIFindSymbols <q-args>

