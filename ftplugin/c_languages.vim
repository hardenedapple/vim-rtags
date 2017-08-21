if !get(g:, "rtagsActiveFiletypes", 0) || index(g:rtagsActiveFiletypes, &filetype) != -1
  " Default for using local mappings is the opposite of whether the global
  " mappings are defined.
  if get(g:, 'rtagsUseDefaultMappings', !g:rtagsUseGlobalMappings)
    " Mappings are defined in plugin/rtags.vim
    for [trigger, expansion] in g:rtagsDefaultMappings
      execute 'nnoremap <silent> <buffer> <LocalLeader>' . trigger . expansion
    endfor
  endif
  if get(g:, 'rtagsUseCompleteFunc', 0) && &l:completefunc == ""
      set completefunc=rtags#RtagsCompleteFunc
  endif
endif
