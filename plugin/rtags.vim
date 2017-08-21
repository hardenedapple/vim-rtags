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

let g:rtagsDefaultMappings = [
  \ ['ri', " :call rtags#SymbolInfo()<CR>"],
  \ ['rj', " :call rtags#JumpToSameWindow()<CR>"],
  \ ['rJ', " :call rtags#JumpToSameWindow({ '--declaration-only' : '' })<CR>"],
  \ ['rS', " :call rtags#JumpToHSplit()<CR>"],
  \ ['rV', " :call rtags#JumpToVSplit()<CR>"],
  \ ['rT', " :call rtags#JumpToNewTab()<CR>"],
  \ ['rp', " :call rtags#JumpToParent()<CR>"],
  \ ['rf', " :call rtags#FindRefs()<CR>"],
  \ ['rn', " :call rtags#FindRefsByName(input('Pattern? ', '', 'customlist,rtags#CompleteSymbols'))<CR>"],
  \ ['rs', " :call rtags#FindSymbols(input('Pattern? ', '', 'customlist,rtags#CompleteSymbols'))<CR>"],
  \ ['rr', " :call rtags#ReindexFile()<CR>"],
  \ ['rl', " :call rtags#ProjectList()<CR>"],
  \ ['rw', " :call rtags#RenameSymbolUnderCursor()<CR>"],
  \ ['rv', " :call rtags#FindVirtuals()<CR>"],
  \ ['rb', " :call rtags#JumpBack()<CR>"],
  \ ['rC', " :call rtags#FindSuperClasses()<CR>"],
  \ ['rc', " :call rtags#FindSubClasses()<CR>"],
  \ ['rd', " :call rtags#Diagnostics()<CR>"],
  \ ]

if g:rtagsUseGlobalMappings == 1
  for [trigger, expansion] in g:rtagsDefaultMappings
    execute 'nnoremap <silent> <Leader>' . trigger . expansion
  endfor
endif

command -nargs=1 -complete=customlist,rtags#CompleteSymbols RtagsFindSymbols call rtags#FindSymbols(<q-args>)
command -nargs=1 -complete=customlist,rtags#CompleteSymbols RtagsFindRefsByName call rtags#FindRefsByName(<q-args>)

command -nargs=1 -complete=customlist,rtags#CompleteSymbols RtagsIFindSymbols call rtags#IFindSymbols(<q-args>)
command -nargs=1 -complete=customlist,rtags#CompleteSymbols RtagsIFindRefsByName call rtags#IFindRefsByName(<q-args>)

command -nargs=1 -complete=dir RtagsLoadCompilationDb call rtags#LoadCompilationDb(<q-args>)

" The most commonly used find operation
command -nargs=1 -complete=customlist,rtags#CompleteSymbols Rtag RtagsIFindSymbols <q-args>

