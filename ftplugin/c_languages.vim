if !get(g:, "rtagsActiveFiletypes", 0) || index(g:rtagsActiveFiletypes, &filetype) != -1
  " Default for using local mappings is the opposite of whether the global
  " mappings are defined.
  if get(g:, 'rtagsUseDefaultMappings', !g:rtagsUseGlobalMappings)
    nnoremap <silent> <buffer> <LocalLeader>ri :call rtags#SymbolInfo()<CR>
    nnoremap <silent> <buffer> <LocalLeader>rj :call rtags#JumpToSameWindow()<CR>
    nnoremap <silent> <buffer> <LocalLeader>rJ :call rtags#JumpToSameWindow({ '--declaration-only' : '' })<CR>
    nnoremap <silent> <buffer> <LocalLeader>rS :call rtags#JumpToHSplit()<CR>
    nnoremap <silent> <buffer> <LocalLeader>rV :call rtags#JumpToVSplit()<CR>
    nnoremap <silent> <buffer> <LocalLeader>rT :call rtags#JumpToNewTab()<CR>
    nnoremap <silent> <buffer> <LocalLeader>rp :call rtags#JumpToParent()<CR>
    nnoremap <silent> <buffer> <LocalLeader>rf :call rtags#FindRefs()<CR>
    nnoremap <silent> <buffer> <LocalLeader>rn :call rtags#FindRefsByName(input("Pattern? ", "", "customlist,rtags#CompleteSymbols"))<CR>
    nnoremap <silent> <buffer> <LocalLeader>rs :call rtags#FindSymbols(input("Pattern? ", "", "customlist,rtags#CompleteSymbols"))<CR>
    nnoremap <silent> <buffer> <LocalLeader>rr :call rtags#ReindexFile()<CR>
    nnoremap <silent> <buffer> <LocalLeader>rl :call rtags#ProjectList()<CR>
    nnoremap <silent> <buffer> <LocalLeader>rw :call rtags#RenameSymbolUnderCursor()<CR>
    nnoremap <silent> <buffer> <LocalLeader>rv :call rtags#FindVirtuals()<CR>
    nnoremap <silent> <buffer> <LocalLeader>rb :call rtags#JumpBack()<CR>
    nnoremap <silent> <buffer> <LocalLeader>rC :call rtags#FindSuperClasses()<CR>
    nnoremap <silent> <buffer> <LocalLeader>rc :call rtags#FindSubClasses()<CR>
    nnoremap <silent> <buffer> <LocalLeader>rd :call rtags#Diagnostics()<CR>
  endif
  if get(g:, 'rtagsUseCompleteFunc', 0) && &l:completefunc == ""
      set completefunc=rtags#RtagsCompleteFunc
  endif
endif
