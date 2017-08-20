if !get(g:, "rtagsActiveFiletypes", 0) || index(g:rtagsActiveFiletypes, &filetype) != -1
  " Default for using local mappings is the opposite of whether the global
  " mappings are defined.
  if get(g:, 'rtagsUseDefaultMappings', !g:rtagsUseGlobalMappings)
    noremap <buffer> <LocalLeader>ri :call rtags#SymbolInfo()<CR>
    noremap <buffer> <LocalLeader>rj :call rtags#JumpTo(g:SAME_WINDOW)<CR>
    noremap <buffer> <LocalLeader>rJ :call rtags#JumpTo(g:SAME_WINDOW, { '--declaration-only' : '' })<CR>
    noremap <buffer> <LocalLeader>rS :call rtags#JumpTo(g:H_SPLIT)<CR>
    noremap <buffer> <LocalLeader>rV :call rtags#JumpTo(g:V_SPLIT)<CR>
    noremap <buffer> <LocalLeader>rT :call rtags#JumpTo(g:NEW_TAB)<CR>
    noremap <buffer> <LocalLeader>rp :call rtags#JumpToParent()<CR>
    noremap <buffer> <LocalLeader>rf :call rtags#FindRefs()<CR>
    noremap <buffer> <LocalLeader>rn :call rtags#FindRefsByName(input("Pattern? ", "", "customlist,rtags#CompleteSymbols"))<CR>
    noremap <buffer> <LocalLeader>rs :call rtags#FindSymbols(input("Pattern? ", "", "customlist,rtags#CompleteSymbols"))<CR>
    noremap <buffer> <LocalLeader>rr :call rtags#ReindexFile()<CR>
    noremap <buffer> <LocalLeader>rl :call rtags#ProjectList()<CR>
    noremap <buffer> <LocalLeader>rw :call rtags#RenameSymbolUnderCursor()<CR>
    noremap <buffer> <LocalLeader>rv :call rtags#FindVirtuals()<CR>
    noremap <buffer> <LocalLeader>rb :call rtags#JumpBack()<CR>
    noremap <buffer> <LocalLeader>rC :call rtags#FindSuperClasses()<CR>
    noremap <buffer> <LocalLeader>rc :call rtags#FindSubClasses()<CR>
    noremap <buffer> <LocalLeader>rd :call rtags#Diagnostics()<CR>
  endif
endif
