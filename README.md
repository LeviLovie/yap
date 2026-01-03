# Yap
An esoteric event driven programming language.

## Running
Compile:
```
$ zig build --release=fast
```

Run:
```
$ ./zig-out/bin/yap examples/00-hello-world.yap
Hello, world!
```

Compile and run:
```
$ ./zig-out/bin/yap build examples/00-hello-world.yap

$ ./zig-out/bin/yap examples/00-hello-world.yapc
Hello, world!
```

Check out [examples](https://github.com/LeviLovie/yap/tree/main/examples).

Have fun!

## Backstory
I wanted to make a gimmicky language but was too lazy to implement loops. So I made an event queue and throw pushes event to the queue and terminates current event. When the runtime reaches the end of the file, it runs the next thing off of the queue.

## Syntax

### Expressions
* `VAR be VALUE` - Assign
* `yap VALUE|VAR` - Print
* `VALUE|VAR reckons VALUE|VAR` - Compare
* `peek VALUE|VAR pls CODE thx` - If statement
* `peek VALUE|VAR pls CODE nah CODE thx` - If statement with an else branch.
* `throw VALUE` - Push an event to the event queue.

### Values
* `Yeah` - True 
* `Nope` - False or None

### Logic
* `flip VALUE|VAR` - Not
* `y VALUE|VAR` - And
* `either VALUE|VAR` - Or
* `neither VALUE|VAR` - Xor
* `VALUE|VAR add VALUE|VAR` - Addition
* `VALUE|VAR sub VALUE|VAR` - Subtraction
* `VALUE|VAR mul VALUE|VAR` - Multiplication
* `VALUE|VAR dib VALUE|VAR` - Division
* `VALUE|VAR pow VALUE|VAR` - Power
* `VALUE|VAR smaller VALUE|VAR` - Less than
* `VALUE|VAR bigger VALUE|VAR` - More than

### Magic Vars
* `e` | `event` - Current event
