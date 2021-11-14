# Welcome to Ban Land

A repo of my utility libraries that aren't worth much; however, I find myself constantly requiring to use them so here they are.

## Nuclear

An emulation of volatile pointers using atomic operations with relaxed memory ordering. This is mostly for use in lock free algorithms.

```nim
block asgn:
  let y = createShared(int)

  var x: nuclear int
  x = nuclear y
  x[] = 5

  doAssert x[] == 5
  doAssert y[] == 5
```

### UPDATE

Now enforces volatile access of object fields. ie: you can create a nuclear pointer to an object, and directly access the fields of that object with the same guarantees.

```nim
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
```

Better ergonomics to follow with time.

## Atomics

Have made small changes. Can do arithmetic without the atomic having to be an Integer type. Can access raw values. Aliases for memory orders that are shorter.

## CacheLine

Yet to be completed (?linux?). Just a simple procedure to determine the L1 cacheline size of the cpu.

## Futex

Futexes; cheap bois

## Memalloc

The aligned allocation procedures that were not exported from the nim library. Have been adjusted to suit my own needs.

## Tagptr

I pretty consistently use algorithms that have aligned pointers which have flags/tags/indexes superimposed on them. This is a library just to make that easier for me to work with.

## DumbPtrs

You'd think theyre smart. But they're not. I've only fixed the sharedptrs atm.