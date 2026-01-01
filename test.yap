file be "test.txt"
mode be file
num be 4.3

yap 4.1
yap "test"
yap mode
yap file
yap num

equals be mode reckons "test.txt"
yap equals
yap num reckons 4.1

peek yeah pls
  yap "This is true"
thx

peek nope pls
  yap "This should not be printed..."
thx

peek nope pls
  yap "This should not be printed either..."
nah
  yap "This is the else branch"
thx
