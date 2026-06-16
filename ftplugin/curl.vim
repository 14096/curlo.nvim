if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring=#\ %s
setlocal comments=:#
setlocal nowrap

let b:undo_ftplugin = "setl commentstring< comments< wrap<"
