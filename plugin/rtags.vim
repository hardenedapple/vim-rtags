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

if g:rtagsUseGlobalMappings == 1
  nnoremap <silent> <Leader>ri :call rtags#SymbolInfo()<CR>
  nnoremap <silent> <Leader>rj :call rtags#JumpToSameWindow()<CR>
  nnoremap <silent> <Leader>rJ :call rtags#JumpToSameWindow({ '--declaration-only' : '' })<CR>
  nnoremap <silent> <Leader>rS :call rtags#JumpToHSplit()<CR>
  nnoremap <silent> <Leader>rV :call rtags#JumpToVSplit()<CR>
  nnoremap <silent> <Leader>rT :call rtags#JumpToNewTab()<CR>
  nnoremap <silent> <Leader>rp :call rtags#JumpToParent()<CR>
  nnoremap <silent> <Leader>rf :call rtags#FindRefs()<CR>
  nnoremap <silent> <Leader>rn :call rtags#FindRefsByName(input("Pattern? ", "", "customlist,rtags#CompleteSymbols"))<CR>
  nnoremap <silent> <Leader>rs :call rtags#FindSymbols(input("Pattern? ", "", "customlist,rtags#CompleteSymbols"))<CR>
  nnoremap <silent> <Leader>rr :call rtags#ReindexFile()<CR>
  nnoremap <silent> <Leader>rl :call rtags#ProjectList()<CR>
  nnoremap <silent> <Leader>rw :call rtags#RenameSymbolUnderCursor()<CR>
  nnoremap <silent> <Leader>rv :call rtags#FindVirtuals()<CR>
  nnoremap <silent> <Leader>rb :call rtags#JumpBack()<CR>
  nnoremap <silent> <Leader>rC :call rtags#FindSuperClasses()<CR>
  nnoremap <silent> <Leader>rc :call rtags#FindSubClasses()<CR>
  nnoremap <silent> <Leader>rd :call rtags#Diagnostics()<CR>
endif

command -nargs=1 -complete=customlist,rtags#CompleteSymbols RtagsFindSymbols call rtags#FindSymbols(<q-args>)
command -nargs=1 -complete=customlist,rtags#CompleteSymbols RtagsFindRefsByName call rtags#FindRefsByName(<q-args>)

command -nargs=1 -complete=customlist,rtags#CompleteSymbols RtagsIFindSymbols call rtags#IFindSymbols(<q-args>)
command -nargs=1 -complete=customlist,rtags#CompleteSymbols RtagsIFindRefsByName call rtags#IFindRefsByName(<q-args>)

command -nargs=1 -complete=dir RtagsLoadCompilationDb call rtags#LoadCompilationDb(<q-args>)

" The most commonly used find operation
command -nargs=1 -complete=customlist,rtags#CompleteSymbols Rtag RtagsIFindSymbols <q-args>

