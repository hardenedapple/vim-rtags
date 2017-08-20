if !get(g:, "rtagsActiveFiletypes", 0) || index(g:rtagsActiveFiletypes, &filetype) != -1
  " Default for using local mappings is the opposite of whether the global
  " mappings are defined.
  if get(g:, 'rtagsUseDefaultMappings', !g:rtagsUseGlobalMappings)
    nnoremap <buffer> <LocalLeader>ri :call rtags#SymbolInfo()<CR>
    nnoremap <buffer> <LocalLeader>rj :call rtags#JumpToSameWindow()<CR>
    nnoremap <buffer> <LocalLeader>rJ :call rtags#JumpToSameWindow({ '--declaration-only' : '' })<CR>
    nnoremap <buffer> <LocalLeader>rS :call rtags#JumpToHSplit()<CR>
    nnoremap <buffer> <LocalLeader>rV :call rtags#JumpToVSplit()<CR>
    nnoremap <buffer> <LocalLeader>rT :call rtags#JumpToNewTab()<CR>
    nnoremap <buffer> <LocalLeader>rp :call rtags#JumpToParent()<CR>
    nnoremap <buffer> <LocalLeader>rf :call rtags#FindRefs()<CR>
    nnoremap <buffer> <LocalLeader>rn :call rtags#FindRefsByName(input("Pattern? ", "", "customlist,rtags#CompleteSymbols"))<CR>
    nnoremap <buffer> <LocalLeader>rs :call rtags#FindSymbols(input("Pattern? ", "", "customlist,rtags#CompleteSymbols"))<CR>
    nnoremap <buffer> <LocalLeader>rr :call rtags#ReindexFile()<CR>
    nnoremap <buffer> <LocalLeader>rl :call rtags#ProjectList()<CR>
    nnoremap <buffer> <LocalLeader>rw :call rtags#RenameSymbolUnderCursor()<CR>
    nnoremap <buffer> <LocalLeader>rv :call rtags#FindVirtuals()<CR>
    nnoremap <buffer> <LocalLeader>rb :call rtags#JumpBack()<CR>
    nnoremap <buffer> <LocalLeader>rC :call rtags#FindSuperClasses()<CR>
    nnoremap <buffer> <LocalLeader>rc :call rtags#FindSubClasses()<CR>
    nnoremap <buffer> <LocalLeader>rd :call rtags#Diagnostics()<CR>
  endif
  if get(g:, 'rtagsUseCompleteFunc', 0) && &l:completefunc == ""
      set completefunc=rtags#RtagsCompleteFunc
  endif
endif
