yap "Event is: "
yap event
yap "\n"

peek event reckons "second_action" pls
  yap "Finished!\n"
  throw done
thx

peek event reckons "entry" pls
  throw first_action
thx

peek event reckons "first_action" pls
  throw second_action
thx
