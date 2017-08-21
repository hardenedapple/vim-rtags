if empty(get(g:, "rtagsActiveFiletypes", [])) || index(g:rtagsActiveFiletypes, &filetype) != -1

  " Start the rtags daemon automatically if the user wants.
  if get(g:, 'rtagsAutoLaunchRdm', 0) && !get(g:, 'rtagsDaemonStarted', 0)
      call system(g:rtagsRcCmd." -w")
      if v:shell_error != 0 
        let rdm = get(g:, 'rtagsRdmCmd', 'rdm')
        call system(rdm." --daemon > /dev/null")
      end
      " Only start it once.
      let g:rtagsDaemonStarted = 1
  end

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
