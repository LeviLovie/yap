peek event reckons "entry" pls
  elements be 10
  write_i be 0
  read_i be 0

  throw write
thx

peek event reckons "write" pls
  peek write_i reckons elements pls
    throw read
  thx

  value be write_i mul 10

  ptr be "array"
  offset be write_i
  action be "set"
  write_i be write_i add 1
  mem write
thx

peek event reckons "read" pls
  peek read_i reckons elements pls
    throw done
  thx

  ptr be "array"
  offset be read_i
  action be "get"
  mem print
thx

peek event reckons "print" pls
  yap "Element "
  yap read_i
  yap ": "
  yap value
  yap "\n"

  read_i be read_i add 1
  throw read
thx

peek event reckons "done" pls
  yap "All done!\n"
thx
