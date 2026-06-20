if exists('g:loaded_d2preview')
  finish
endif
" add it back after we done.
" let g:loaded_d2preview = 1

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

function! s:get_current_block_text() abort
  let l:block = s:current_d2_block()
  if l:block is v:null
    return ''
  endif
  return join(getline(l:block.line_start, l:block.line_end), "\n")
endfunction

function! s:on_d2_stdout(jobid, data, event) dict abort
  let self.output = a:data
endfunction

function! s:on_d2_exit(jobid, code, event) dict abort
  if a:code != 0
    return
  endif

  let l:bufnr = bufnr(self.preview_bufname)
  if l:bufnr == -1
    return
  endif

  call setbufvar(l:bufnr, '&modifiable', 1)
  silent! call deletebufline(l:bufnr, 1, '$')
  call setbufline(l:bufnr, 1, self.output)
  call setbufvar(l:bufnr, '&modifiable', 0)
endfunction

function! s:run_d2_on(text, preview_bufname) abort
  let l:job = jobstart(
  \ ['d2', '--stdout-format', 'txt', '-'],
  \ {
  \ 'stdin': 'pipe',
  \ 'stdout_buffered': v:true,
  \ 'output': [],
  \ 'preview_bufname': a:preview_bufname,
  \ 'on_stdout': function('s:on_d2_stdout'),
  \ 'on_exit': function('s:on_d2_exit'),
  \ })

  call chansend(l:job, a:text)
  call chanclose(l:job, 'stdin')
endfunction

function! s:on_save() abort
  if !(exists('b:d2p') && has_key(b:d2p, 'preview_bufname') && bufexists(b:d2p.preview_bufname))
    return
  endif

  if b:d2p.mode ==# 'file'
    call s:run_d2_on(s:all_d2_blocks_text(), b:d2p.preview_bufname)
  elseif s:cursor_inside_d2p()
    call s:run_d2_on(s:get_current_block_text(), b:d2p.preview_bufname)
  endif
endfunction

function! s:d2_preview(mode) abort
  if !exists('b:d2p')
    let b:d2p = {}
  endif

  let b:d2p.mode = a:mode

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

  if a:mode ==# 'file'
    call s:run_d2_on(s:all_d2_blocks_text(), b:d2p.preview_bufname)
  elseif s:cursor_inside_d2p()
    call s:run_d2_on(s:get_current_block_text(), b:d2p.preview_bufname)
  endif
endfunction

function! Temp_current_d2_block() abort
  return s:current_d2_block()
endfunction

function! Temp_all_d2_blocks() abort
  return s:all_d2_blocks()
endfunction

function! Temp_all_d2_blocks_text() abort
  return s:all_d2_blocks_text()
endfunction

function! Temp_cursor_inside_d2p() abort
  return s:cursor_inside_d2p()
endfunction

function! Temp_get_current_block_text() abort
  return s:get_current_block_text()
endfunction

function! Temp_run_d2_on(text, preview_bufname) abort
  call s:run_d2_on(a:text, a:preview_bufname)
endfunction

function! Temp_d2_preview(mode) abort
  call s:d2_preview(a:mode)
endfunction
