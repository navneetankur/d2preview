if exists('g:loaded_d2preview')
  finish
endif
" add it back after we done.
" let g:loaded_d2preview = 1

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

function! s:get_current_block_text() abort
  let l:block = s:current_d2_block()

  if l:block is v:null
    return ''
  endif

  return join(
  \ getline(l:block.line_start, l:block.line_end),
  \ "\n")
endfunction

function! s:on_d2_stdout(jobid, data, event) dict abort
  let self.output = a:data
endfunction

function! s:on_d2_exit(jobid, code, event) dict abort
  if a:code != 0
    return
  endif

  call setbufvar(self.preview_bufnr, '&modifiable', 1)
  silent! call deletebufline(self.preview_bufnr, 1, '$')
  call setbufline(self.preview_bufnr, 1, self.output)
  call setbufvar(self.preview_bufnr, '&modifiable', 0)
endfunction

function! s:run_d2_on(text, preview_bufnr) abort
  let l:job = jobstart(
  \ ['d2', '--stdout-format', 'txt', '-'],
  \ {
  \ 'stdin': 'pipe',
  \ 'stdout_buffered': v:true,
  \ 'output': [],
  \ 'preview_bufnr': a:preview_bufnr,
  \ 'on_stdout': function('s:on_d2_stdout'),
  \ 'on_exit': function('s:on_d2_exit'),
  \ })

  call chansend(l:job, a:text)
  call chanclose(l:job, 'stdin')
endfunction

function! s:d2_preview() abort
  if !exists('b:d2p')
    let b:d2p = {}
  endif

  if !has_key(b:d2p, 'preview_bufnr') || !bufexists(b:d2p.preview_bufnr)
    let l:name = bufname('%') . '.' . rand() . '.d2p'

    let l:preview_bufnr = bufadd(l:name)
    call bufload(l:preview_bufnr)

    call setbufvar(l:preview_bufnr, '&buftype', 'nofile')
    call setbufvar(l:preview_bufnr, '&bufhidden', 'wipe')
    call setbufvar(l:preview_bufnr, '&swapfile', 0)
    call setbufvar(l:preview_bufnr, '&modifiable', 0)

    let b:d2p.preview_bufnr = l:preview_bufnr

    vsplit
    execute 'buffer ' . l:preview_bufnr
    wincmd p
  endif

  call s:run_d2_on(
  \ s:get_current_block_text(),
  \ b:d2p.preview_bufnr)
endfunction

" temporary functions for test. to be deleted in final.
function! Temp_current_d2_block() abort
  return s:current_d2_block()
endfunction

function! Temp_get_current_block_text() abort
  return s:get_current_block_text()
endfunction

function! Temp_run_d2_on(text, preview_bufnr) abort
  call s:run_d2_on(a:text, a:preview_bufnr)
endfunction

function! Temp_d2_preview() abort
  call s:d2_preview()
endfunction
