if has('nvim') || (has('job') && has('channel'))
    let s:rtagsAsync = 1
    let s:job_cid = 0
    let s:jobs = {}
    let s:result_stdout = {}
    let s:result_handlers = {}
else
    let s:rtagsAsync = 0
endif

" Controlling JobState {{{
function rtags#SetJobStateFinish()
    let b:rtags_state['state'] = 'finish'
endfunction

function rtags#AddJobStandard(eventType, data)
    call add(b:rtags_state[a:eventType], a:data)
endfunction

function rtags#SetJobStateReady()
    let b:rtags_state['state'] = 'ready'
endfunction

function rtags#IsJobStateReady()
    if b:rtags_state['state'] == 'ready'
        return 1
    endif
    return 0
endfunction

function rtags#IsJobStateBusy()
    if b:rtags_state['state'] == 'busy'
        return 1
    endif
    return 0
endfunction

function rtags#IsJobStateFinish()
    if b:rtags_state['state'] == 'finish'
        return 1
    endif
    return 0
endfunction


function rtags#SetStartJobState()
    let b:rtags_state['state'] = 'busy'
    let b:rtags_state['stdout'] = []
    let b:rtags_state['stderr'] = []
endfunction

function rtags#GetJobStdOutput()
    return b:rtags_state['stdout']
endfunction

function rtags#ExistsAndCreateRtagsState()
    if !exists('b:rtags_state')
        let b:rtags_state = { 'state': 'ready', 'stdout': [], 'stderr': [] }
    endif
endfunction
" }}}

let s:SAME_WINDOW = 'edit '
let s:H_SPLIT = 'split '
let s:V_SPLIT = 'vsplit '
let s:NEW_TAB = 'tabedit '

let s:OPEN_LOADED = {
      \ s:SAME_WINDOW : 'buffer ',
      \ s:H_SPLIT : 'sbuffer ',
      \ s:V_SPLIT : 'vert sbuffer ',
      \ s:NEW_TAB : 'tab sbuffer ',
      \ }

" Utils {{{
"""
" Logging routine
"""
function rtags#Log(message)
    if exists("g:rtagsLog")
        call writefile([string(a:message)], g:rtagsLog, "a")
    endif
endfunction

function rtags#getRcCmd()
    let cmd = g:rtagsRcCmd
    let cmd .= " --absolute-path "
    if get(g:, 'rtagsExcludeSysHeaders', 0)
        return cmd." -H "
    endif
    return cmd
endfunction

function rtags#getCurrentLocation()
    let [lnum, col] = getpos('.')[1:2]
    return printf("%s:%s:%s", expand("%"), lnum, col)
endfunction

function rtags#goToFile(open_opt, file)
  " Avoid calling :edit / :split etc if the buffer is already loaded.
  " This is a noticeable efficiency gain.
  let curfile = expand('%:p')
  if a:open_opt == s:SAME_WINDOW && a:file == curfile
    return
  endif
  let bufnr = bufnr(a:file)
  if bufnr == -1
    exe a:open_opt.a:file
  else
    exe s:OPEN_LOADED[a:open_opt] . a:file
  endif
endfunction

function rtags#jumpToLocationInternal(open_opt, file, line, col)
  try
    call rtags#goToFile(a:open_opt, a:file)
    call cursor(a:line, a:col)
    return 1
  catch /.*/
    echohl ErrorMsg
    echomsg v:exception
    echohl None
    return 0
  endtry
endfunction

function rtags#CreateProject()

endfunction

function rtags#parseSourceLocation(string)
    let [location; symbol_detail] = split(a:string, '\s\+')
    let splittedLine = split(location, ':')
    if len(splittedLine) == 3
        let [jump_file, lnum, col; rest] = splittedLine
        " Must be a path, therefore leading / is compulsory
        if jump_file[0] == '/'
            return [jump_file, lnum, col]
        endif
    endif
    return ["","",""]
endfunction


"
" param[in] results - List of found locations by rc
" return locations - List of locations dict's recognizable by setloclist
"
function rtags#ParseResults(results)
    let locations = []
    let nr = 1
    for record in a:results
        let [location; rest] = split(record, '\s\+')
        let [file, lnum, col] = rtags#parseSourceLocation(location)

        let entry = {}
        "        let entry.bufn = 0
        let entry.filename = substitute(file, getcwd().'/', '', 'g')
        let entry.filepath = file
        let entry.lnum = lnum
        "        let entry.pattern = ''
        let entry.col = col
        let entry.vcol = 0
        "        let entry.nr = nr
        let entry.text = join(rest, ' ')
        let entry.type = 'ref'

        call add(locations, entry)

        let nr = nr + 1
    endfor
    return locations
endfunction

function rtags#TempFile(job_cid)
    return '/tmp/neovim_async_rtags.tmp.' . getpid() . '.' . a:job_cid
endfunction

" }}}

" Execution {{{

function s:cache_valid()
  if !&modified
    return v:true
  endif

  " Only read contents of the buffer if we know the buffer has changed since we
  " last read it.
  if get(b:, 'rtags_change_tick', -1) == b:changedtick
    return v:true
  endif
  let b:rtags_change_tick = b:changedtick
  return v:false
endfunction

function s:update_content_cache(rc_cmd)
  if s:cache_valid()
    return
  endif
  let to_send = getline(1, line('$'))
  if get(b:, 'rtags_sent_content', []) == to_send
    return
  endif
  let filename = expand("%")
  " Decrease by one for the number of bytes in the buffer
  " Decrease by one more because strlen(b:rtags_cur_content) is one less
  " than the number of bytes in the file.
  " This is because it never includes the trailing newline at the end of
  " the last line, while line2byte() always does (whether there is a
  " trailing newline or not).
  let buffer_bytes = line2byte(line('$') + 1) - 2
  let send_contents_cmd = printf("%s --wait --unsaved-file=%s:%s -V %s", a:rc_cmd, filename, buffer_bytes, filename)
  call system(send_contents_cmd, join(to_send, "\n"))
  let b:rtags_sent_content = to_send
endfunction


"
" Executes rc with given arguments and returns rc output
"
" param[in] args - dictionary of arguments
"-
" return output split by newline
function rtags#ExecuteRC(cmd)
    let output = system(a:cmd)
    if v:shell_error && len(output) > 0
        let output = substitute(output, '\n', '', '')
        echohl ErrorMsg | echomsg "[vim-rtags] Error: " . output | echohl None
        return []
    endif
    if output =~ '^Not indexed'
        echohl ErrorMsg | echomsg "[vim-rtags] Current file is not indexed!" | echohl None
        return []
    endif
    return split(output, '\n\+')
endfunction

function rtags#ExecuteHandlers(output, handlers)
    let result = a:output
    for Handler in a:handlers
        if type(Handler) == 3
            let HandlerFunc = Handler[0]
            let args = Handler[1]
            call HandlerFunc(result, args)
        else
            try
                let result = Handler(result)
            catch /E706/
                " If we're not returning the right type we're probably done
                return
            endtry
        endif
    endfor 
endfunction

" Async {{{
function rtags#HandleResults(job_id, data, event)
  if a:event == 'vim_stdout'
    call add(s:result_stdout[a:job_id], a:data)
    return
  endif

  let job_cid = remove(s:jobs, a:job_id)
  let handlers = remove(s:result_handlers, a:job_id)

  " The event is exit (because the only events we register this function under
  " are 'vim_stdout', 'vim_exit', and 'exit') we now need to distinguish
  " between vim exit and neovim exit.
  if a:event == 'vim_exit'
    let output = remove(s:result_stdout, a:job_id)
    call rtags#ExecuteHandlers(output, handlers)
  elseif a:event == 'exit'
    let temp_file = rtags#TempFile(job_cid)
    let output = readfile(temp_file)
    call rtags#ExecuteHandlers(output, handlers)
    execute 'silent !rm -f ' . temp_file
  else
    echoerr 'rtags#HandleResults() called with unexpected event: ' . a:event
  endif
endfunction

function rtags#ExecuteRCAsync(cmd, handlers)
    let s:callbacks = { 'on_exit' : function('rtags#HandleResults') }

    let s:job_cid = s:job_cid + 1
    " should have out+err redirection portable for various shells.
    if has('nvim')
        let cmd = a:cmd . '>& ' . rtags#TempFile(s:job_cid)
        let job = jobstart(cmd, s:callbacks)
        let s:jobs[job] = s:job_cid
        let s:result_handlers[job] = a:handlers
    elseif has('job') && has('channel')
        let l:opts = {}
        let l:opts.mode = 'nl'
        let l:opts.out_cb = {ch, data -> rtags#HandleResults(ch_info(ch).id, data, 'vim_stdout')}
        let l:opts.exit_cb = {ch, data -> rtags#HandleResults(ch_info(ch).id, data,'vim_exit')}
        let l:opts.stoponexit = 'kill'
        let job = job_start(a:cmd, l:opts)
        let channel = ch_info(job_getchannel(job)).id
        let s:result_stdout[channel] = []
        let s:jobs[channel] = s:job_cid
        let s:result_handlers[channel] = a:handlers
    endif

endfunction
" }}}

function rtags#ExecuteThen(args, handlers)
  let cmd = rtags#getRcCmd()

  " Give rdm unsaved file content, so that you don't have to save files
  " before each rc invocation.
  call s:update_content_cache(cmd)

  " prepare for the actual command invocation
  let arguments = map(items(a:args), { key, val -> val[0] . ' ' . val[1] })
  let full_cmd = cmd . ' ' . join(arguments, ' ')

  if s:rtagsAsync == 1
    call rtags#ExecuteRCAsync(full_cmd, a:handlers)
  else
    let result = rtags#ExecuteRC(full_cmd)
    call rtags#ExecuteHandlers(result, a:handlers)
  endif
endfunction
" }}}

" Class Hierarchy Helpers {{{
function rtags#ExtractClassHierarchyLine(line)
    return substitute(a:line, '\v.*\s+(\S+:[0-9]+:[0-9]+:\s)', '\1', '')
endfunction


"
" Converts a class hierarchy of 'rc --class-hierarchy' like:
"
" Superclasses:
"   class Foo src/Foo.h:56:7: class Foo : public Bar {
"     class Bar	src/Bar.h:46:7:	class Bar : public Bas {
"       class Bas src/Bas.h:47:7: class Bas {
" Subclasses:
"   class Foo src/Foo.h:56:7: class Foo : public Bar {
"     class Foo2 src/Foo2.h:56:7: class Foo2 : public Foo {
"     class Foo3 src/Foo3.h:56:7: class Foo3 : public Foo {
"
" into the super classes:
"
" src/Foo.h:56:7: class Foo : public Bar {
" src/Bar.h:46:7: class Bar : public Bas {
" src/Bas.h:47:7: class Bas {
"
function rtags#ExtractSuperClasses(results)
    let extracted = []
    for line in a:results
        if line == "Superclasses:"
            continue
        endif

        if line == "Subclasses:"
            break
        endif

        let extLine = rtags#ExtractClassHierarchyLine(line)
        call add(extracted, extLine)
    endfor
    return extracted
endfunction


"
" Converts a class hierarchy of 'rc --class-hierarchy' like:
"
" Superclasses:
"   class Foo src/Foo.h:56:7: class Foo : public Bar {
"     class Bar	src/Bar.h:46:7:	class Bar : public Bas {
"       class Bas src/Bas.h:47:7: class Bas {
" Subclasses:
"   class Foo src/Foo.h:56:7: class Foo : public Bar {
"     class Foo2 src/Foo2.h:56:7: class Foo2 : public Foo {
"     class Foo3 src/Foo3.h:56:7: class Foo3 : public Foo {
"
" into the sub classes:
"
" src/Foo.h:56:7: class Foo : public Bar {
" src/Foo2.h:56:7: class Foo2 : public Foo {
" src/Foo3.h:56:7: class Foo3 : public Foo {
"
function rtags#ExtractSubClasses(results)
    let extracted = []
    let atSubClasses = 0
    for line in a:results
        if atSubClasses == 0
            if line == "Subclasses:"
                let atSubClasses = 1
            endif

            continue
        endif

        let extLine = rtags#ExtractClassHierarchyLine(line)
        call add(extracted, extLine)
    endfor
    return extracted
endfunction

" }}}

" Display reply from `rc` {{{
"
" param[in] locations - List of locations, one per line
"
function rtags#DisplayLocations(locations)
    let num_of_locations = len(a:locations)
    let max_height = get(g:, 'rtagsMaxSearchResultWindowHeight', 10)
    if get(g:, 'rtagsUseLocationList', 1)
        call setloclist(winnr(), a:locations)
        if num_of_locations > 0
            exe 'lopen '.min([max_height, num_of_locations])
        endif
    else
        call setqflist(a:locations)
        if num_of_locations > 0
            exe 'copen '.min([max_height, num_of_locations])
        endif
    endif
endfunction

"
" param[in] results - List of locations, one per line
"
" Format of each line: <path>,<line>\s<text>
function rtags#DisplayResults(results)
    let locations = rtags#ParseResults(a:results)
    call rtags#DisplayLocations(locations)
endfunction

"
" param[in] results - Data get by rc diagnose command (XML format)
"
function rtags#DisplayDiagnosticsResults(results)
    exe 'sign unplace *'
    exe 'sign define fixit text=F texthl=FixIt'
    exe 'sign define warning text=W texthl=Warning'
    exe 'sign define error text=E texthl=Error'

python3 << endpython
import json
import xml.etree.ElementTree as ET

tree = ET.fromstring('\n'.join(vim.eval("a:results")))
file = tree.find('file')
errors = file.findall('error')
name = file.get('name')

quickfix_errors = []
for i, e in enumerate(errors):
    severity = e.get('severity')
    if severity == 'skipped':
        continue
    line = e.get('line')
    column = e.get('column')
    message = e.get('message')

    # strip error prefix
    s = ' Issue: '
    index = message.find(s)
    if index != -1:
      message = message[index + len(s):]

    error_type = 'E' if severity == 'error' else 'W'

    quickfix_errors.append({'lnum': line, 'col': column, 'nr': i, 'text': message, 'filename': name, 'type': error_type})
    cmd = 'sign place %d line=%s name=%s file=%s' % (i + 1, line, severity, name)
    vim.command(cmd)

vim.eval('rtags#DisplayLocations(%s)' % json.dumps(quickfix_errors))
endpython
endfunction

" }}}

" User Commands {{{
" SymbolInfo {{{
function rtags#SymbolInfoHandler(output)
    echo join(a:output, "\n")
endfunction

function rtags#SymbolInfo()
    call rtags#ExecuteThen({ '-U' : rtags#getCurrentLocation() }, [function('rtags#SymbolInfoHandler')])
endfunction
" }}}

" {{{ JumpTo
function rtags#JumpBack()
    if len(g:rtagsJumpStack) > 0
        let [jump_file, lnum, col] = remove(g:rtagsJumpStack, -1)
        call rtags#jumpToLocationInternal(jump_file, lnum, col)
    else
        echo "rtags: jump stack is empty"
    endif
endfunction

function rtags#saveLocation()
    let jumpListLen = len(g:rtagsJumpStack) 
    if jumpListLen > get(g:, 'rtagsJumpStackMaxSize', 100)
        call remove(g:rtagsJumpStack, 0)
    endif
    let [lnum, col] = getpos('.')[1:2]
    call add(g:rtagsJumpStack, [expand("%"), lnum, col])
endfunction

function rtags#JumpToHandler(results, args)
    let results = a:results

    if len(results) > 1
      " At the moment I don't know when this is ever possible.
      " We use this function in rtags#JumpToParentHandler(), and
      " rtags#JumpTo().
      " In rtags#JumpToParentHandler() we only pass this function the line
      " starting with 'Parent:' in the symbol-info from rtags.
      "   As far as I know this is only ever one line.
      "
      " In rtags#JumpTo() we call this function with the lines from 
      " `rc -f <location>`.
      "   Again, this is only ever one line.
      "
      " It's perfectly possible that I'm missing something, so leave the
      " original functionality, but get a message when it happens.
      echom 'Have results longer than one element!!'
      echom 'This is unexpected ... the elements are:'
      echom string(results)
      call rtags#DisplayResults(results)
    elseif len(results) == 1
      let [jump_file, lnum, col] = rtags#parseSourceLocation(results[0])
      if jump_file == ""
        " Usually the problem is that the user forgot to start the server.
        " Account for the general case and just print the servers message.
        echom 'Invalid result back from server: ' . results[0]
        return
      endif

      " Add location to the jumplist
      normal! m'
      call rtags#saveLocation()
      let open_opt = a:args['open_opt']
      if rtags#jumpToLocationInternal(open_opt, jump_file, lnum, col)
        normal! zz
      endif
    endif

endfunction

"
" JumpTo(open_type, args_list)
"     open_type - Vim command used for opening desired location.
"     Allowed values:
"       * s:SAME_WINDOW
"       * s:H_SPLIT
"       * s:V_SPLIT
"       * s:NEW_TAB
"
"     args_list - Either empty list or list of one dictionary of additional
"                 arguments for 'rc'
"
function rtags#JumpTo(open_opt, args_list)
    let args = {}
    if len(a:args_list) > 0
        let args = a:args_list[0]
    endif
    call extend(args, { '-f' : rtags#getCurrentLocation() })
    let results = rtags#ExecuteThen(args, [[function('rtags#JumpToHandler'), { 'open_opt' : a:open_opt }]])
endfunction

function rtags#JumpToSameWindow(...)
  call rtags#JumpTo(s:SAME_WINDOW, a:000)
endfunction
function rtags#JumpToHSplit(...)
  call rtags#JumpTo(s:H_SPLIT, a:000)
endfunction
function rtags#JumpToVSplit(...)
  call rtags#JumpTo(s:V_SPLIT, a:000)
endfunction
function rtags#JumpToNewTab(...)
  call rtags#JumpTo(s:NEW_TAB, a:000)
endfunction

function rtags#JumpToParentHandler(results, ...)
  let rgx = '^Parent: '
  let results = filter(a:results, 'matchend(v:val, rgx) != -1')
  call rtags#JumpToHandler(map(results, 'substitute(v:val, rgx, "", "")'), { 'open_opt': s:SAME_WINDOW } )
endfunction

function rtags#JumpToParent()
    let args = {
                \ '-U' : rtags#getCurrentLocation(),
                \ '--symbol-info-include-parents' : '' }

    call rtags#ExecuteThen(args, [function('rtags#JumpToParentHandler')])
endfunction
" }}}

" RenameSymbol {{{
function rtags#RenameSymbolUnderCursorHandler(output)
  let locations = rtags#ParseResults(a:output)
  if len(locations) == 0
    return
  endif

  let newName = input("Enter new name: ")
  let yesToAll = 0
  let replace_symbol = -1
  if !empty(newName)
    for loc in reverse(locations)
      if !rtags#jumpToLocationInternal(s:SAME_WINDOW, loc.filepath, loc.lnum, loc.col)
        return
      endif
      normal! zv
      normal! zz
      redraw
      let choice = yesToAll
      if choice == 0
        let location = loc.filepath.":".loc.lnum.":".loc.col
        let choices = "&Yes\nYes to &All\n&No\n&Cancel"
        let choice = confirm("Rename symbol at ".location, choices)
      endif
      if choice == 2
        let choice = 1
        let yesToAll = 1
      endif
      if choice == 1
        let curline = getline('.')
        let start_char = matchstr(curline, '\%' . loc.col . 'c.')
        " Special case for destructors (RTags column number is on the ~)
        let change_col = start_char == '~' ? loc.col : loc.col - 1
        let before_text = strpart(curline, 0, change_col)
        let after_text = strpart(curline, change_col)
        if replace_symbol == -1
          " Pattern chosen to simulate 'normal! ciw' from the original code.
          let replace_symbol = matchstr(after_text, '\w\+')
        endif
        let new_end = substitute(after_text, replace_symbol, newName, '')
        call setline('.', before_text . new_end)
      elseif choice == 4
        return
      endif
    endfor
  endif
endfunction

function rtags#RenameSymbolUnderCursor()
    let args = {
                \ '-e' : '',
                \ '-r' : rtags#getCurrentLocation(),
                \ '--rename' : '' }

    call rtags#ExecuteThen(args, [function('rtags#RenameSymbolUnderCursorHandler')])
endfunction
" }}}

function rtags#FindRefs()
    let args = {
                \ '-e' : '',
                \ '-r' : rtags#getCurrentLocation() }

    call rtags#ExecuteThen(args, [function('rtags#DisplayResults')])
endfunction

function rtags#FindSuperClasses()
    call rtags#ExecuteThen({ '--class-hierarchy' : rtags#getCurrentLocation() },
                \ [function('rtags#ExtractSuperClasses'), function('rtags#DisplayResults')])
endfunction

function rtags#FindSubClasses()
    let result = rtags#ExecuteThen({ '--class-hierarchy' : rtags#getCurrentLocation() }, [
                \ function('rtags#ExtractSubClasses'),
                \ function('rtags#DisplayResults')])
endfunction

function rtags#FindVirtuals()
    let args = {
                \ '-k' : '',
                \ '-r' : rtags#getCurrentLocation() }

    call rtags#ExecuteThen(args, [function('rtags#DisplayResults')])
endfunction

" case insensitive FindRefsByName
function rtags#IFindRefsByName(name)
    let args = {
                \ '-a' : '',
                \ '-e' : '',
                \ '-R' : a:name,
                \ '-I' : '' }

    call rtags#ExecuteThen(args, [function('rtags#DisplayResults')])
endfunction

function rtags#FindRefsByName(name)
    let args = {
                \ '-a' : '',
                \ '-e' : '',
                \ '-R' : a:name }

    call rtags#ExecuteThen(args, [function('rtags#DisplayResults')])
endfunction

" Find all those references which has the name which is equal to the word
" under the cursor
function rtags#FindRefsOfWordUnderCursor()
    let wordUnderCursor = expand("<cword>")
    call rtags#FindRefsByName(wordUnderCursor)
endfunction

""" rc -HF <pattern>
function rtags#FindSymbols(pattern)
    let args = {
                \ '-a' : '',
                \ '-F' : a:pattern }

    call rtags#ExecuteThen(args, [function('rtags#DisplayResults')])
endfunction

function rtags#FindSymbolsOfWordUnderCursor()
    let wordUnderCursor = expand("<cword>")
    call rtags#FindSymbols(wordUnderCursor)
endfunction

" Method for tab-completion for vim's commands
function rtags#CompleteSymbols(arg, line, pos)
    if len(a:arg) < get(g:, 'rtagsMinCharsForCommandCompletion', 4)
        return []
    endif
    call rtags#ExecuteThen({ '-S' : a:arg }, [function('filter')])
endfunction

" case insensitive FindSymbol
function rtags#IFindSymbols(pattern)
    let args = {
                \ '-a' : '',
                \ '-I' : '',
                \ '-F' : a:pattern }

    call rtags#ExecuteThen(args, [function('rtags#DisplayResults')])
endfunction

" Project Management {{{
function rtags#ProjectOpen(pattern)
    call rtags#ExecuteThen({ '-w' : a:pattern }, [])
endfunction

function rtags#ProjectListHandler(output)
    let projects = a:output
    let i = 1
    for p in projects
        echo '['.i.'] '.p
        let i = i + 1
    endfor
    let choice = input('Choice: ')
    if choice > 0 && choice <= len(projects)
        call rtags#ProjectOpen(projects[choice-1])
    endif
endfunction

function rtags#ProjectList()
    call rtags#ExecuteThen({ '-w' : '' }, [function('rtags#ProjectListHandler')])
endfunction

function rtags#LoadCompilationDb(pattern)
    call rtags#ExecuteThen({ '-J' : a:pattern }, [])
endfunction

function rtags#ProjectClose(pattern)
    call rtags#ExecuteThen({ '-u' : a:pattern }, [])
endfunction
" }}}

" Preprocess {{{
function rtags#PreprocessFileHandler(result)
    vnew
    call append(0, a:result)
endfunction

function rtags#PreprocessFile()
    call rtags#ExecuteThen({ '-E' : expand("%:p") }, [function('rtags#PreprocessFileHandler')])
endfunction
" }}}

function rtags#ReindexFile()
    call rtags#ExecuteThen({ '-V' : expand("%:p") }, [])
endfunction

function rtags#Diagnostics()
    let args = {
                \ '--diagnose' : expand("%:p"),
                \ '--synchronous-diagnostics' : '' }

    call rtags#ExecuteThen(args, [function('rtags#DisplayDiagnosticsResults')])
endfunction
   
" Completion function {{{
"
" This function assumes it is invoked from insert mode
"
function rtags#CompleteAtCursor(wordStart, base)
    let flags = "--synchronous-completions -l"
    let file = expand("%:p")
    let pos = getpos('.')
    let line = pos[1] 
    let col = pos[2]

    if index(['.', '::', '->'], a:base) != -1
        let col += 1
    endif

    let rcRealCmd = rtags#getRcCmd()

    exec "normal! \<Esc>"
    let stdin_lines = join(getline(1, "$"), "\n").a:base
    let offset = len(stdin_lines)

    exec "startinsert!"
    "    echomsg getline(line)
    "    sleep 1
    "    echomsg "DURING INVOCATION POS: ".pos[2]
    "    sleep 1
    "    echomsg stdin_lines
    "    sleep 1
    " sed command to remove CDATA prefix and closing xml tag from rtags output
    let sed_cmd = "sed -e 's/.*CDATA\\[//g' | sed -e 's/.*\\/completions.*//g'"
    let cmd = printf("%s %s %s:%s:%s --unsaved-file=%s:%s | %s", rcRealCmd, flags, file, line, col, file, offset, sed_cmd)
    call rtags#Log("Command line:".cmd)

    let result = split(system(cmd, stdin_lines), '\n\+')
    "    echomsg "Got ".len(result)." completions"
    "    sleep 1
    call rtags#Log("-----------")
    "call rtags#Log(result)
    call rtags#Log("-----------")
    return result
    "    for r in result
    "        echo r
    "    endfor
    "    call rtags#DisplayResults(result)
endfunction

function s:RtagsCompleteFunc(findstart, base, async)
    call rtags#Log("RtagsCompleteFunc: [".a:findstart."], [".a:base."]")

    if a:findstart
        let l:start = col('.') - 1
        if a:async == 0
            " got from RipRip/clang_complete
            let l:line = getline('.')
            let l:wsstart = l:start
            if l:line[l:wsstart - 1] =~ '\s'
                while l:wsstart > 0 && l:line[l:wsstart - 1] =~ '\s'
                    let l:wsstart -= 1
                endwhile
            endif
            while l:start > 0 && l:line[l:start - 1] =~ '\i'
                let l:start -= 1
            endwhile
            let b:col = l:start + 1
            call rtags#Log("column:".b:col)
            call rtags#Log("start:".l:start)
        else
            "buffer local variable
            call rtags#ExistsAndCreateRtagsState()

            if rtags#IsJobStateBusy() == 1
                return -3
            elseif rtags#IsJobStateReady() == 1
                let b:firstBase = a:base

                let pos = getpos('.')
                let l:line = pos[1] 
                let l:col = pos[2]

                if index(['.', '::', '->'], a:base) != -1
                    let l:col += 1
                endif
                let l:stdin_lines = join(getline(1, "$"), "\n").a:base
                let l:offset = len(l:stdin_lines)

                call s:RcJobExecute(l:offset, l:line, l:col)
                return -3
            elseif rtags#IsJobStateFinish() == 1
                call rtags#SetJobStateReady()
            endif
        endif
        return l:start
    else

        let wordstart = getpos('.')[0]
        if a:async == 0
            let l:completeopts = rtags#CompleteAtCursor(wordstart, a:base)
        else
            let l:completeopts = rtags#GetJobStdOutput()
        endif

        let a = []
        for line in l:completeopts
            let option = split(line)
            if a:base != "" && stridx(option[0], a:base) != 0
                continue
            endif
            let match = {}
            let match.word = option[0]
            let match.kind = option[len(option) - 1]
            if match.kind == "CXXMethod"
                let match.word = match.word.'('
            endif
            let match.menu = join(option[1:len(option) - 1], ' ')
            call add(a, match)
            "call rtags#Log(match)
        endfor
        return a
    endif
endfunction

"""
" Temporarily the way this function works is:
"     - completeion invoked on
"         object.meth*
"       , where * is cursor position
"     - find the position of a dot/arrow
"     - invoke completion through rc
"     - filter out options that start with meth (in this case).
"     - show completion options
" 
"     Reason: rtags returns all options regardless of already type method name
"     portion
"""
function rtags#RtagsCompleteFunc(findstart, base)
    if s:rtagsAsync == 1 && !has('nvim')
        return s:RtagsCompleteFunc(a:findstart, a:base, 1)
    else
        return s:RtagsCompleteFunc(a:findstart, a:base, 0)
    endif
endfunction

function s:RcExecuteJobCompletion()
    call rtags#SetJobStateFinish()
    if ! empty(b:rtags_state['stdout']) && mode() == 'i'
        call feedkeys("\<C-x>\<C-o>", "t")
    else
        call rtags#RtagsCompleteFunc(0, rtags#RtagsCompleteFunc(1, 0))
    endif
endfunction

"Handles stdout/stderr/exit events, and stores the stdout/stderr received from the shells.
function rtags#RcExecuteJobHandler(job_id, data, event)
    if a:event == 'exit'
        call s:RcExecuteJobCompletion()
    else
        call rtags#AddJobStandard(a:event, a:data)
    endif
endf

" Execute clang binary to generate completions and diagnostics.
" Global variable:
" Buffer vars:
"     b:rtags_state => {
"       'state' :  // updated to 'ready' in sync mode
"       'stdout':  // updated in sync mode
"       'stderr':  // updated in sync mode
"     }
"
"     b:clang_execute_job_id  // used to stop previous job
"
" @root Clang root, project directory
" @line Line to complete
" @col Column to complete
" @return [completion, diagnostics]
function s:RcJobExecute(offset, line, col)

    let file = expand("%:p")
    let l:cmd = printf("rc --absolute-path --synchronous-completions -l %s:%s:%s --unsaved-file=%s:%s", file, a:line, a:col, file, a:offset)

    if exists('b:rc_execute_job_id') && job_status(b:rc_execute_job_id) == 'run'
      try
        call job_stop(b:rc_execute_job_id, 'term')
        unlet b:rc_execute_job_id
      catch
        " Ignore
      endtry
    endif

    call rtags#SetStartJobState()

    let l:argv = l:cmd
    let l:opts = {}
    let l:opts.mode = 'nl'
    let l:opts.in_io = 'buffer'
    let l:opts.in_buf = bufnr('%')
    let l:opts.out_cb = {ch, data -> rtags#RcExecuteJobHandler(ch, data,  'stdout')}
    let l:opts.err_cb = {ch, data -> rtags#RcExecuteJobHandler(ch, data,  'stderr')}
    let l:opts.exit_cb = {ch, data -> rtags#RcExecuteJobHandler(ch, data, 'exit')}
    let l:opts.stoponexit = 'kill'

    let l:jobid = job_start(l:argv, l:opts)
    let b:rc_execute_job_id = l:jobid

    if job_status(l:jobid) != 'run'
        unlet b:rc_execute_job_id
    endif

endf
" }}}

" }}}

" Helpers to access script locals for unit testing {{{
function s:get_SID()
    return matchstr(expand('<sfile>'), '<SNR>\d\+_')
endfunction
let s:SID = s:get_SID()
delfunction s:get_SID

function rtags#__context__()
    return { 'sid': s:SID, 'scope': s: }
endfunction
"}}}
