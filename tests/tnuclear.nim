import wtbanland/nuclear

block asgn:
  let y = createShared(int)

  var x: nuclear int
  x = nuclear y
  x[] = 5

  doAssert x[] == 5
  doAssert y[] == 5

block no_mem_copy:
  let x = createShared(int)
  let y = createShared(int)

  var z, w: nuclear int
  z = nucleate x
  w = nucleate y

  z[] = 1
  w[] = 2

  doAssert z[] == 1
  doAssert w[] == 2

  x[] = 6
  y[] = 3

  doAssert z[] == 6
  doAssert w[] == 3

  z = w

  doAssert z[] == 3

  z[] = 5

  doAssert w[] == 5
  doAssert z[] == 5

  w = nucleate x

  doAssert z[] == 5
  doAssert w[] == 6

  z <- w

  doAssert z[] == 6
  doAssert w[] == 6

  w[] = 1

  doAssert w[] == 1
  doAssert z[] == 6

  doAssert x[] == 1
  doAssert y[] == 6

block volatile_shit:
  type
    TickTack = object
      field1: int
      field2: int
  
  let x = createShared(TickTack)
  x[] = TickTack(field1: 1, field2: 2)
  var y: nuclear TickTack
  y = nuclear x
  doAssert y[].field1 == 1
  doAssert y[].field2 == 2

  # y[].field1 = 5  # the volatile access is not mutable
  
  y[] = TickTack(field1: 5, field2: 2)

  doAssert y[].field1 == 5

block dot_operator:
  type
    TickTack = object
      field1: int
      field2: int
  
  let x = createShared(TickTack)
  x[] = TickTack(field1: 1, field2: 2)
  var y = nuclear x
  doAssert y[].field1 == 1
  doAssert y[].field2 == 2

  y.field2[] = 5

  doAssert y[].field2 == 5
