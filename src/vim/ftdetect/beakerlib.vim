
"" temporary disable auto-load
"au BufNewFile,BufRead *.sh call s:FTbeakerlib()

function! s:FTbeakerlib()
  let s:lnum = 1
    while s:lnum < 100 && s:lnum < line("$")
      if getline(s:lnum) =~ '^.*\(rlJournalStart\|rlPhaseStart\|rlRun\|rlLog\)'
         set filetype=beakerlib
         break
      endif
      let s:lnum += 1
    endwhile
  unlet s:lnum
endfunction
