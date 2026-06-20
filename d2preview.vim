if has('nvim')
  let s:d2p_ns = nvim_create_namespace('d2preview')
endif

augroup d2preview
  autocmd!
  autocmd BufWritePost * call <SID>on_save()
augroup END

function! s:current_d2_block() abort
  let l:save = getpos('.')
  let l:cursor = line('.')

  let l:start = search('^```d2\s*$', 'bnW')
  let l:end = search('^```\s*$', 'nW')

  call setpos('.', l:save)

  if l:start == 0 || l:end == 0
    return v:null
  endif

  if l:cursor <= l:start || l:cursor >= l:end
    return v:null
  endif

  return {
  \ 'line_start': l:start + 1,
  \ 'line_end': l:end - 1,
  \ }
endfunction

function! s:all_d2_blocks() abort
  let l:save = getpos('.')
  let l:blocks = []
  call cursor(1, 1)

  while 1
    let l:start = search('^```d2\s*$', 'W')
    if l:start == 0
      break
    endif

    let l:end = search('^```\s*$', 'W')
    if l:end == 0
      break
    endif

    call add(l:blocks, {
    \ 'line_start': l:start + 1,
    \ 'line_end': l:end - 1,
    \ })
  endwhile

  call setpos('.', l:save)
  return l:blocks
endfunction

function! s:all_d2_blocks_text() abort
  let l:parts = []

  for l:block in s:all_d2_blocks()
    call add(
    \ l:parts,
    \ join(getline(l:block.line_start, l:block.line_end), "\n"))
  endfor

  return join(l:parts, "\n\n")
endfunction

function! s:cursor_inside_d2p() abort
  let l:save = getpos('.')
  let l:d2p = search('^```d2\s*$', 'bnW')
  let l:fence = search('^```\s*$', 'bnW')
  call setpos('.', l:save)

  if l:d2p == 0
    return v:false
  endif

  if l:fence > l:d2p
    return v:false
  endif

  return v:true
endfunction

function! s:sel_start() abort
  if has('nvim')
    return nvim_buf_get_extmark_by_id(bufnr('%'), s:d2p_ns, b:d2p.sel_mark_start, {})[0] + 1
  endif
  return b:d2p.sel_start
endfunction

function! s:sel_end() abort
  if has('nvim')
    return nvim_buf_get_extmark_by_id(bufnr('%'), s:d2p_ns, b:d2p.sel_mark_end, {})[0] + 1
  endif
  return b:d2p.sel_end
endfunction

function! s:cursor_inside_selection() abort
  let l:line = line('.')
  return l:line >= s:sel_start()
      \ && l:line <= s:sel_end()
endfunction

function! s:get_current_block_text() abort
  let l:block = s:current_d2_block()
  if l:block is v:null
    return ''
  endif
  return join(getline(l:block.line_start, l:block.line_end), "\n")
endfunction

function! s:get_selection_text() abort
  return join(
  \ getline(s:sel_start(), s:sel_end()),
  \ "\n")
endfunction

function! s:job_stop(job) abort
  if has('nvim')
    call jobstop(a:job)
  else
    call job_stop(a:job)
  endif
endfunction

" --- Neovim callbacks ---

function! s:on_d2_stdout(jobid, data, event) dict abort
  if !has_key(self.d2p, 'job_id') || a:jobid != self.d2p.job_id
    return
  endif
  call extend(self.d2p.job_output, a:data)
endfunction

function! s:on_d2_exit(jobid, code, event) dict abort
  if has_key(self.d2p, 'job_id') && a:jobid ==# self.d2p.job_id
	  unlet self.d2p.job_id
  else
	  return
  endif
  call setbufvar(self.d2p.preview_bufname, '&modifiable', 1)
  if a:code != 0
    call appendbufline(a:d2p.preview_bufname, 0, ["[Rendering failed: ]",""])
    call setbufvar(self.d2p.preview_bufname, '&modifiable', 0)
    return
  endif

  silent! call deletebufline(self.d2p.preview_bufname, 1, '$')
  call setbufline(self.d2p.preview_bufname, 1, self.d2p.job_output)
  call setbufvar(self.d2p.preview_bufname, '&modifiable', 0)
endfunction

" --- Vim callbacks (out_cb fires per line; exit_cb fires on completion) ---

function! s:vim_on_d2_stdout(d2p, channel, msg) abort
  if !has_key(a:d2p, 'job_id') || job_getchannel(a:d2p.job_id) isnot a:channel
    return
  endif
  call add(a:d2p.job_output, a:msg)
endfunction

function! s:vim_on_d2_exit(d2p, job, status) abort
  if has_key(a:d2p, 'job_id') && a:job is a:d2p.job_id
    unlet a:d2p.job_id
  else
    return
  endif
  call setbufvar(a:d2p.preview_bufname, '&modifiable', 1)
  if a:status != 0
    call appendbufline(a:d2p.preview_bufname, 0, ["[Rendering failed: ]",""])
    call setbufvar(a:d2p.preview_bufname, '&modifiable', 0)
    return
  endif

  silent! call deletebufline(a:d2p.preview_bufname, 1, '$')
  call setbufline(a:d2p.preview_bufname, 1, a:d2p.job_output)
  call setbufvar(a:d2p.preview_bufname, '&modifiable', 0)
endfunction

function! s:run_d2_on(d2p, text) abort
  if has_key(a:d2p, 'job_id')
    call s:job_stop(a:d2p.job_id)
  endif
  " call setbufvar(a:d2p.preview_bufname, '&modifiable', 1)
  " call appendbufline(a:d2p.preview_bufname, 0, ["[Rendering...]",""])
  " call setbufvar(a:d2p.preview_bufname, '&modifiable', 0)

  let a:d2p.job_output = []

  if has('nvim')
    let l:job = jobstart(
    \ ['d2', '--stdout-format', 'txt', '-'],
    \ {
    \ 'stdin': 'pipe',
    \ 'stdout_buffered': v:true,
    \ 'd2p': a:d2p,
    \ 'on_stdout': function('s:on_d2_stdout'),
    \ 'on_exit': function('s:on_d2_exit'),
    \ })
    let a:d2p.job_id = l:job
    call chansend(l:job, a:text)
    call chanclose(l:job, 'stdin')
  else
    let l:job = job_start(
    \ ['d2', '--stdout-format', 'txt', '-'],
    \ {
    \ 'in_io': 'pipe',
    \ 'out_io': 'pipe',
    \ 'err_io': 'null',
    \ 'out_cb': function('s:vim_on_d2_stdout', [a:d2p]),
    \ 'exit_cb': function('s:vim_on_d2_exit', [a:d2p]),
    \ })
    let a:d2p.job_id = l:job
    call ch_sendraw(job_getchannel(l:job), a:text)
    call ch_close_in(job_getchannel(l:job))
  endif

  return l:job
endfunction

function! s:on_save() abort
  if !(exists('b:d2p') && has_key(b:d2p, 'preview_bufname') && bufexists(b:d2p.preview_bufname))
    return
  endif

  if b:d2p.mode ==# 'selection' 
	  if s:cursor_inside_selection()
		call s:run_d2_on(b:d2p, s:get_selection_text())
	  else
		return
	  endif
  elseif s:cursor_inside_d2p()
	  if b:d2p.mode ==# 'file'
		call s:run_d2_on(b:d2p, s:all_d2_blocks_text())
	  else
		call s:run_d2_on(b:d2p, s:get_current_block_text())
	  endif
  endif
endfunction

function! s:d2_preview(mode = v:null) range abort
  if !exists('b:d2p')
    let b:d2p = {}
  endif
  let b:d2p.mode = a:mode
  if b:d2p.mode ==# v:null
	  if a:firstline ==# a:lastline
		  let b:d2p.mode = 'block'
	  else
		  let b:d2p.mode = 'selection'
	  endif
  endif

  if b:d2p.mode ==# 'selection'
    if has('nvim')
      if has_key(b:d2p, 'sel_mark_start')
        call nvim_buf_del_extmark(bufnr('%'), s:d2p_ns, b:d2p.sel_mark_start)
        call nvim_buf_del_extmark(bufnr('%'), s:d2p_ns, b:d2p.sel_mark_end)
      endif
      let b:d2p.sel_mark_start = nvim_buf_set_extmark(bufnr('%'), s:d2p_ns, a:firstline - 1, 0, {})
      let b:d2p.sel_mark_end   = nvim_buf_set_extmark(bufnr('%'), s:d2p_ns, a:lastline - 1, 0, {})
    else
      let b:d2p.sel_start = a:firstline
      let b:d2p.sel_end = a:lastline
    endif
  endif

  if !has_key(b:d2p, 'preview_bufname') || !bufexists(b:d2p.preview_bufname)
    let l:name = bufname('%') . '.' . rand() . '.d2p'
    let l:preview_bufnr = bufadd(l:name)
    call bufload(l:preview_bufnr)

    call setbufvar(l:preview_bufnr, '&buftype', 'nofile')
    call setbufvar(l:preview_bufnr, '&bufhidden', 'wipe')
    call setbufvar(l:preview_bufnr, '&swapfile', 0)
    call setbufvar(l:preview_bufnr, '&modifiable', 0)

    let b:d2p.preview_bufname = l:name

    vsplit
    execute 'buffer ' . l:preview_bufnr
    wincmd p
  endif

  if b:d2p.mode ==# 'selection' "no cursor check needed. it's selection
		call s:run_d2_on(b:d2p, s:get_selection_text())
  elseif s:cursor_inside_d2p()
	  if b:d2p.mode ==# 'file'
		call s:run_d2_on(b:d2p, s:all_d2_blocks_text())
	  else
		call s:run_d2_on(b:d2p, s:get_current_block_text())
	  endif
  endif
endfunction

command! -range D2Preview <line1>,<line2>call s:d2_preview()
command! D2PreviewFile call s:d2_preview('file')
