peek event reckons "entry" pls
  i be 0
  throw loop
thx

peek event reckons "loop" pls
  i be i add 1

  yap "Running loop with i = "
  yap i
  yap "\n"

  peek i reckons 5 pls
    throw done
  nah
    throw loop
  thx
thx

peek event reckons "done" pls
  yap "Loop finished after "
  yap i
  yap " iterations.\n"
thx
