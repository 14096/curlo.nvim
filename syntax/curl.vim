if exists("b:current_syntax")
  finish
endif

syntax match curlComment /^#.*/

syntax match curlVarDef /^\s*@[a-zA-Z_][a-zA-Z0-9_\-.]*\s*=.*$/ contains=curlVarDefName,curlVarDefEq,curlVarDefValue
syntax match curlVarDefName /^\s*@[a-zA-Z_][a-zA-Z0-9_\-.]*/ contained
syntax match curlVarDefEq /\s*=\s*/                             contained
syntax match curlVarDefValue /=\s*\zs.*$/                       contained

syntax match curlCapture    /^\s*@[a-zA-Z_][a-zA-Z0-9_\-.]*\s*<-.*$/ contains=curlCaptureVar,curlCaptureOp,curlCapturePath
syntax match curlCaptureVar /^\s*@[a-zA-Z_][a-zA-Z0-9_\-.]*/          contained
syntax match curlCaptureOp  /<-/                                        contained
syntax match curlCapturePath /<-\s*\zs.*/                               contained

syntax keyword curlCommand curl

syntax keyword curlMethod GET POST PUT PATCH DELETE HEAD OPTIONS

syntax match curlFlag /\v\-\-[a-zA-Z][a-zA-Z0-9\-]*/
syntax match curlFlagShort /\v(^|\s)\-[a-zA-Z]/

syntax match curlURL /\vhttps?:\/\/[^ \t'"\)]+/

syntax match curlHeaderKey /\v(-H|--header)\s+['"]\zs[^:'"]+\ze:/
syntax match curlHeaderValue /\v(-H|--header)\s+'"[^:'"]+:\s*\zs[^'"]+/

syntax region curlString       start=/"/ end=/"/ skip=/\\"/  contains=curlURL,curlHeaderKey,curlHeaderValue,curlVariable
syntax region curlStringSingle start=/'/ end=/'/              contains=curlURL,curlVariable

syntax match curlContinuation /\\$/

syntax match curlDataFlag /\v(--data(-raw|-binary|-urlencode)?|-d)\ze(\s|$)/

syntax match curlRedirect     /^\s*>>.*$/ contains=curlRedirectOp,curlRedirectPath
syntax match curlRedirectOp   /^\s*>>/                     contained
syntax match curlRedirectPath />>\s*\zs.*/                 contained

highlight default link curlComment      Comment
highlight default link curlVarDefName   Define
highlight default link curlVarDefEq     Operator
highlight default link curlVarDefValue  String
highlight default link curlCaptureVar   Define
highlight default link curlCaptureOp    Operator
highlight default link curlCapturePath  String
highlight default link curlCommand      Statement
highlight default link curlMethod       Type
highlight default link curlFlag         Identifier
highlight default link curlFlagShort    Identifier
highlight default link curlURL          Underlined
highlight default link curlString       String
highlight default link curlStringSingle String
highlight default link curlHeaderKey    Special
highlight default link curlHeaderValue  Constant
highlight default link curlContinuation NonText
highlight default link curlDataFlag     Keyword
highlight default link curlRedirectOp   Operator
highlight default link curlRedirectPath String
highlight default link curlVariable     PreProc

let b:current_syntax = "curl"
